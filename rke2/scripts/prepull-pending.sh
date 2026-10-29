#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Pre-pulls, on each node, the images its not-yet-running pods are waiting for —
# ONE AT A TIME with retries — as the transient systemd unit image-prepull.
# On a slow shared uplink, kubelet starts a dozen pulls at once; they split the
# bandwidth, registry requests time out ("timeout awaiting response headers",
# DeadlineExceeded) and pods sit in ImagePullBackOff with growing back-off.
# Sequential pulls each get the whole link and finish; kubelet then finds the
# image present on its next retry.
#
#   rke2/scripts/prepull-pending.sh                    start (or restart) on every node
#   rke2/scripts/prepull-pending.sh node-02 node-04    only on these nodes
#   rke2/scripts/prepull-pending.sh status             per-node progress
#
# Runs from the workstation (kubectl + SSH via cluster.env). Log on each node:
# /var/log/image-prepull.log
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
need_cmd kubectl ssh
use_kubeconfig

UNIT=image-prepull
LOGF=/var/log/image-prepull.log
CRICTL="/var/lib/rancher/rke2/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock"

ip_of() {  # node name -> IP from cluster.env
  local spec
  for spec in $SERVER_NODES ${AGENT_NODES:-}; do
    [ "$(node_name "$spec")" = "$1" ] && { node_ip "$spec"; return; }
  done
}

if [ "${1:-}" = status ]; then
  for spec in $SERVER_NODES ${AGENT_NODES:-}; do
    printf '%-8s ' "$(node_name "$spec")"
    node_ssh "$(node_ip "$spec")" "printf 'unit=%s  ' \"\$(systemctl is-active $UNIT 2>/dev/null)\"; sudo tail -n 1 $LOGF 2>/dev/null || echo '(never ran)'"
  done
  exit 0
fi

# node<TAB>image for every init/regular container of every pod that is not Running/Succeeded.
pairs=$(kubectl get pods -A -o json | jq -r '
  .items[]
  | select(.spec.nodeName != null)
  | select(.status.phase != "Running" and .status.phase != "Succeeded"
           or ([.status.containerStatuses[]?, .status.initContainerStatuses[]? | .state.waiting.reason // empty] | length > 0))
  | .spec.nodeName as $n
  | (.spec.initContainers[]?, .spec.containers[]) | "\($n)\t\(.image)"' | sort -u)
[ -n "$pairs" ] || { log "no waiting pods — nothing to pre-pull"; exit 0; }

ONLY=" $* "   # optional node-name filter
for node in $(cut -f1 <<<"$pairs" | sort -u); do
  [ "$ONLY" = "  " ] || [[ "$ONLY" == *" $node "* ]] || continue
  ip=$(ip_of "$node"); [ -n "$ip" ] || { warn "$node not in cluster.env — skipped"; continue; }
  imgs=$(awk -F'\t' -v n="$node" '$1==n {print $2}' <<<"$pairs" | tr '\n' ' ')
  log "$node: queue $(wc -w <<<"$imgs" | tr -d ' ') image(s)"
  # Skip images already present; pull the rest sequentially, retrying each until it lands.
  node_ssh "$ip" "sudo systemctl stop $UNIT 2>/dev/null; sudo systemctl reset-failed $UNIT 2>/dev/null; \
    sudo systemd-run --unit=$UNIT --description='sequential image pre-pull' \
      -p StandardOutput=append:$LOGF -p StandardError=append:$LOGF \
      bash -c 'for img in $imgs; do
        if $CRICTL inspecti \"\$img\" >/dev/null 2>&1; then echo \"\$(date +%T) present  \$img\"; continue; fi
        for try in \$(seq 1 30); do
          echo \"\$(date +%T) pulling  \$img (try \$try)\"
          out=\$($CRICTL pull \"\$img\" 2>&1) && { echo \"\$(date +%T) done     \$img\"; break; }
          echo \"\$(date +%T) failed   \$img: \$(echo \"\$out\" | grep -v crictl.yaml | tail -n1 | cut -c1-300)\"
          sleep 10
        done
      done; echo \"\$(date +%T) ALL DONE\"' >/dev/null"
done
log "started. Progress: $0 status"
