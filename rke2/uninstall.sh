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
#
# Both are destructive and ask for the cluster name to be typed back.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
load_env

MODE="${1:-}"
case "$MODE" in platform|cluster) ;; *) die "usage: uninstall.sh <platform|cluster>" ;; esac

read -r -a SERVERS <<<"$SERVER_NODES"
read -r -a AGENTS <<<"${AGENT_NODES:-}"
FIRST="$(node_name "${SERVERS[0]}")"

echo "This will DESTROY the $MODE on: ${SERVER_NODES} ${AGENT_NODES:-}"
[ "$MODE" = cluster ] && echo "All data on the nodes (Postgres, SeaweedFS objects, Prometheus, Loki) is deleted."
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
