#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Tear down. Counterpart to install-cluster.sh + bootstrap-platform.sh.
#
#   uninstall.sh platform   delete the Argo CD Applications (cascade: every
#                           PVC and its data goes too), keep RKE2 running
#   uninstall.sh cluster    run rke2-uninstall.sh / rke2-agent-uninstall.sh on
#                           every node — removes RKE2, etcd, all container data
#                           and every local-storage volume under the hostpath
#                           base. LVM VGs and their LVs are left in place.
#   uninstall.sh reset      like cluster, but keeps RKE2 and every downloaded
#                           image (scripts/reset-node.sh): re-running
#                           install-cluster.sh then rebuilds the cluster with
#                           no downloads. Use after the node IPs change.
#
# All are destructive and ask for the cluster name to be typed back.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
load_env

MODE="${1:-}"
case "$MODE" in platform|cluster|reset) ;; *) die "usage: uninstall.sh <platform|cluster|reset>" ;; esac

read -r -a SERVERS <<<"$SERVER_NODES"
read -r -a AGENTS <<<"${AGENT_NODES:-}"
FIRST="$(node_name "${SERVERS[0]}")"

echo "This will DESTROY the $MODE on: ${SERVER_NODES} ${AGENT_NODES:-}"
[ "$MODE" != platform ] && echo "All data on the nodes (Postgres, SeaweedFS objects, Prometheus, Loki) is deleted."
[ "$MODE" = reset ] && echo "RKE2 and the downloaded images are kept; re-run install-cluster.sh afterwards."
read -r -p "Type the first server's name ($FIRST) to continue: " answer
[ "$answer" = "$FIRST" ] || die "aborted — nothing changed"

if [ "$MODE" = platform ]; then
  use_kubeconfig
  log "deleting Application big-data-platform (cascade)"
  kubectl -n argocd delete application big-data-platform --ignore-not-found --wait=true --timeout=20m
  log "deleting Application seaweedfs (cascade)"
  kubectl -n argocd delete application seaweedfs --ignore-not-found --wait=true --timeout=10m
  log "platform removed; Argo CD, Traefik, OpenEBS and the Secrets remain (re-run bootstrap-platform.sh to redeploy)"
  exit 0
fi

if [ "$MODE" = reset ]; then
  # Every node, agents first. Talks only to the IPs in cluster.env — a node
  # unreachable there (e.g. still on its old IP) is reported, not skipped silently.
  failed=""
  for spec in "${AGENTS[@]}" "${SERVERS[@]}"; do
    [ -n "$spec" ] || continue
    ip=$(node_ip "$spec")
    if node_scp "$ip" "$RKE2_DIR/scripts/reset-node.sh" /tmp/reset-node.sh &&
       node_ssh "$ip" "sudo env HOSTPATH_BASE=$(printf %q "${HOSTPATH_BASE:-/var/openebs/local}") bash /tmp/reset-node.sh"; then :
    else
      warn "reset failed on $(node_name "$spec") ($ip)"; failed+=" $(node_name "$spec")"
    fi
  done
  rm -f "$KUBECONFIG_OUT"
  [ -z "$failed" ] || die "not reset:$failed — fix and re-run uninstall.sh reset"
  log "cluster state wiped, downloads kept. Next:  rke2/install-cluster.sh"
  exit 0
fi

for spec in "${AGENTS[@]}"; do
  [ -n "$spec" ] || continue
  log "agent $(node_name "$spec"): rke2-agent-uninstall.sh"
  node_ssh "$(node_ip "$spec")" "sudo sh -c 'command -v rke2-agent-uninstall.sh >/dev/null && rke2-agent-uninstall.sh || { [ -x /usr/local/bin/rke2-uninstall.sh ] && /usr/local/bin/rke2-uninstall.sh; } || true'"
done
for spec in "${SERVERS[@]}"; do
  log "server $(node_name "$spec"): rke2-uninstall.sh"
  node_ssh "$(node_ip "$spec")" "sudo sh -c 'command -v rke2-uninstall.sh >/dev/null && rke2-uninstall.sh || true'"
done
for spec in "${SERVERS[@]}" "${AGENTS[@]}"; do
  [ -n "$spec" ] || continue
  node_ssh "$(node_ip "$spec")" "sudo rm -rf '${HOSTPATH_BASE:-/var/openebs/local}' /var/lib/alloy" || true
done
rm -f "$KUBECONFIG_OUT"
log "cluster removed"
