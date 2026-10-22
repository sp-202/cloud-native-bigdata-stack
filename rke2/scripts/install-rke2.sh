#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Installs and starts RKE2 on THIS node, as root (install-cluster.sh runs it
# over SSH with sudo). Idempotent: re-running rewrites the config and restarts
# only if it changed.
#
# Usage: install-rke2.sh <server-init|server|agent>
# Env:
#   NODE_NAME, NODE_IP          this node
#   SERVER_URL                  https://<server1>:9345   (server/agent join)
#   RKE2_TOKEN                  cluster join token        (server/agent join)
#   TLS_SANS                    space-separated extra API cert SANs (servers)
#   RKE2_CHANNEL / RKE2_VERSION
#   CANAL_IFACE                 optional flannel interface
#   SYSTEM_RESERVED, KUBE_RESERVED, EVICTION_HARD   kubelet reservations
# -----------------------------------------------------------------------------
set -euo pipefail

ROLE="${1:?usage: install-rke2.sh <server-init|server|agent>}"
log() { echo "[install-rke2 ${NODE_NAME:-$(hostname)}] $*"; }
die() { echo "[install-rke2 ${NODE_NAME:-$(hostname)}] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"
: "${NODE_NAME:?}" "${NODE_IP:?}"
case "$ROLE" in
  server-init) TYPE=server ;;
  server)      TYPE=server; : "${SERVER_URL:?}" "${RKE2_TOKEN:?}" ;;
  agent)       TYPE=agent;  : "${SERVER_URL:?}" "${RKE2_TOKEN:?}" ;;
  *) die "unknown role $ROLE" ;;
esac

CFG_DIR=/etc/rancher/rke2
CFG="$CFG_DIR/config.yaml"
mkdir -p "$CFG_DIR"
NEW_CFG=$(mktemp)

{
  echo "# Managed by rke2/scripts/install-rke2.sh — edits are overwritten."
  echo "node-name: \"$NODE_NAME\""
  echo "node-ip: \"$NODE_IP\""
  if [ "$ROLE" != "server-init" ]; then
    echo "server: \"$SERVER_URL\""
    echo "token: \"$RKE2_TOKEN\""
  fi
  # Reservations: what kubelet keeps away from pods for the OS and itself
  # (allocatable = capacity - system - kube - eviction). Graceful node
  # shutdown: workloads get 30s, then system-node-critical pods the last 60s.
  cat <<KUBELET
kubelet-arg:
  - "system-reserved=${SYSTEM_RESERVED:-cpu=1,memory=1Gi}"
  - "kube-reserved=${KUBE_RESERVED:-cpu=500m,memory=768Mi}"
  - "eviction-hard=${EVICTION_HARD:-memory.available<256Mi,nodefs.available<10%,imagefs.available<15%}"
  - "shutdown-grace-period=90s"
  - "shutdown-grace-period-critical-pods=60s"
# kube-proxy metrics for Prometheus (values.yaml kubeProxy).
kube-proxy-arg:
  - "metrics-bind-address=0.0.0.0:10249"
KUBELET
  if [ "$TYPE" = "server" ]; then
    cat <<'SERVER'
# Canal = Flannel VXLAN + Calico NetworkPolicy. RKE2's default CNI: no extra
# components, standard NetworkPolicy support, no eBPF tuning to own.
cni: canal
# Traefik (installed by bootstrap-platform.sh) owns hostPorts 80/443.
disable:
  - rke2-ingress-nginx
write-kubeconfig-mode: "0600"
# Control-plane metrics off localhost so kube-prometheus-stack can scrape them
# (values.yaml kubeEtcd/kubeScheduler/kubeControllerManager).
etcd-expose-metrics: true
kube-controller-manager-arg:
  - "bind-address=0.0.0.0"
kube-scheduler-arg:
  - "bind-address=0.0.0.0"
SERVER
    echo "tls-san:"
    for san in $NODE_IP ${TLS_SANS:-}; do echo "  - \"$san\""; done
  fi
} > "$NEW_CFG"

CHANGED=1
if [ -f "$CFG" ] && cmp -s "$NEW_CFG" "$CFG"; then CHANGED=0; fi
install -m 0600 "$NEW_CFG" "$CFG"
rm -f "$NEW_CFG"

# Canal on a specific NIC (multi-NIC nodes). Servers only — RKE2 deploys
# manifests from the server's manifests dir.
if [ "$TYPE" = "server" ] && [ -n "${CANAL_IFACE:-}" ]; then
  mkdir -p /var/lib/rancher/rke2/server/manifests
  cat > /var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml <<CANAL
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      iface: "${CANAL_IFACE}"
CANAL
fi

UNIT="rke2-$TYPE"
if ! command -v rke2 >/dev/null && [ ! -x /usr/local/bin/rke2 ] && [ ! -x /opt/rke2/bin/rke2 ]; then
  log "installing RKE2 ($TYPE, ${RKE2_VERSION:-channel ${RKE2_CHANNEL:-stable}})"
  if [ -n "${RKE2_VERSION:-}" ]; then
    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="$TYPE" INSTALL_RKE2_VERSION="$RKE2_VERSION" sh -
  else
    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="$TYPE" INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL:-stable}" sh -
  fi
  CHANGED=1
fi

systemctl enable "$UNIT" >/dev/null
if [ "$CHANGED" -eq 1 ] || ! systemctl is-active --quiet "$UNIT"; then
  log "starting $UNIT (first start of a server can take a few minutes)"
  systemctl restart "$UNIT"
fi

# kubectl/crictl on PATH for interactive debugging on the node.
if [ "$TYPE" = "server" ]; then
  cat > /etc/profile.d/rke2.sh <<'PROFILE'
export PATH=$PATH:/var/lib/rancher/rke2/bin
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
PROFILE
fi

log "done"
