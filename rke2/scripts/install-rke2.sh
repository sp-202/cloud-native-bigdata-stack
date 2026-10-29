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
#
# With RKE2_VERSION set and /opt/rke2-artifacts/<version>/ staged by
# stage-artifacts.sh, installs offline from there (binary + core/canal image
# bundles); otherwise downloads from get.rke2.io as usual. An installed RKE2
# of another version is replaced (upgrade/downgrade in place).
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

# Pod DNS: kubelet hands every pod (and CoreDNS, as its upstream) the node's
# resolv.conf — including the DHCP search domain of whatever network the node
# is on (e.g. "g.group" on an office guest WiFi). With ndots:5 every cluster
# name is first tried with that suffix; the upstream answers it with an empty
# NOERROR or not at all, and musl (Alpine images) then fails the whole lookup.
# So kubelet gets no search line, and as nameservers: the network's first IPv4
# resolver + 1.1.1.1 + 8.8.8.8 (resolv.conf takes 3). IPv4 only: the cluster
# is single-stack and a network's IPv6 resolver is unreachable here ("dial udp
# [2401:...]:53: network is unreachable" from CoreDNS). The public pair covers
# a hotspot/guest DNS that drops queries; CoreDNS health-checks its upstreams.
# Regenerated on every run: re-run install-cluster.sh after a network change.
RESOLV="$CFG_DIR/resolv.conf"
NEW_RESOLV=$(mktemp)
NS=$( { awk '$1=="nameserver" && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && $2 !~ /^127\./ {print $2}' \
          /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null | grep -vxE '1\.1\.1\.1|8\.8\.8\.8' | head -1
        echo 1.1.1.1; echo 8.8.8.8; } | awk '!seen[$0]++' | head -3)
{
  echo "# Managed by rke2/scripts/install-rke2.sh — kubelet resolvConf, no search domains."
  for n in $NS; do echo "nameserver $n"; done
} > "$NEW_RESOLV"

{
  echo "# Managed by rke2/scripts/install-rke2.sh — edits are overwritten."
  echo "node-name: \"$NODE_NAME\""
  echo "node-ip: \"$NODE_IP\""
  echo "resolv-conf: \"$RESOLV\""
  if [ "$ROLE" != "server-init" ]; then
    echo "server: \"$SERVER_URL\""
    echo "token: \"$RKE2_TOKEN\""
  fi
  # Kubelet reservations and graceful shutdown live in the kubelet.conf.d
  # drop-in below (config file, not deprecated kubelet-arg flags).
  cat <<'PROXY'
# kube-proxy metrics for Prometheus (values.yaml kubeProxy).
kube-proxy-arg:
  - "metrics-bind-address=0.0.0.0:10249"
PROXY
  if [ "$TYPE" = "server" ]; then
    cat <<'SERVER'
# Canal = Flannel VXLAN + Calico NetworkPolicy. RKE2's default CNI: no extra
# components, standard NetworkPolicy support, no eBPF tuning to own.
cni: canal
# Traefik (installed by bootstrap-platform.sh) owns hostPorts 80/443, so no
# bundled ingress: since v1.36 RKE2 deploys its own rke2-traefik by default.
ingress-controller: none
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
if ! cmp -s "$NEW_RESOLV" "$RESOLV"; then CHANGED=1; fi
install -m 0644 "$NEW_RESOLV" "$RESOLV"
rm -f "$NEW_RESOLV"

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

# Kubelet settings that only belong in its config file. RKE2 runs kubelet with
# --config-dir=<this dir> and only writes its own 00-rke2-defaults.conf there,
# so this drop-in survives restarts.
#   reservations  what kubelet keeps away from pods for the OS and itself
#                 (allocatable = capacity - system - kube - eviction)
#   shutdown      workloads get 30s, then system-node-critical pods the last 60s
#   image pulls   RKE2 sets serializeImagePulls: false with no cap, so a node
#                 starting 20 pods pulls everything at once; on a slow shared
#                 uplink each pull starves and registry requests time out
#                 (ImagePullBackOff). Two at a time queue instead and finish.
kv_yaml() {  # kv_yaml <separator> <k<sep>v,k<sep>v,...>  ->  indented YAML map lines
  local IFS=, p
  for p in $2; do printf '  %s: "%s"\n' "${p%%"$1"*}" "${p#*"$1"}"; done
}
KUBELET_DROPIN_DIR=/var/lib/rancher/rke2/agent/etc/kubelet.conf.d
mkdir -p "$KUBELET_DROPIN_DIR"
NEW_DROPIN=$(mktemp)
{
  echo "# Managed by rke2/scripts/install-rke2.sh — edits are overwritten."
  echo "apiVersion: kubelet.config.k8s.io/v1beta1"
  echo "kind: KubeletConfiguration"
  echo "systemReserved:"; kv_yaml = "${SYSTEM_RESERVED:-cpu=1,memory=1Gi}"
  echo "kubeReserved:";   kv_yaml = "${KUBE_RESERVED:-cpu=500m,memory=768Mi}"
  echo "evictionHard:";   kv_yaml '<' "${EVICTION_HARD:-memory.available<256Mi,nodefs.available<10%,imagefs.available<15%}"
  echo "shutdownGracePeriod: 90s"
  echo "shutdownGracePeriodCriticalPods: 60s"
  echo "serializeImagePulls: false"
  echo "maxParallelImagePulls: 2"
} > "$NEW_DROPIN"
rm -f "$KUBELET_DROPIN_DIR/50-graceful-shutdown.conf"   # pre-1.36 name of this drop-in
if ! cmp -s "$NEW_DROPIN" "$KUBELET_DROPIN_DIR/50-rke2-tooling.conf"; then CHANGED=1; fi
install -m 0600 "$NEW_DROPIN" "$KUBELET_DROPIN_DIR/50-rke2-tooling.conf"
rm -f "$NEW_DROPIN"

UNIT="rke2-$TYPE"
RKE2_BIN=$(command -v rke2 || ls /usr/local/bin/rke2 /opt/rke2/bin/rke2 2>/dev/null | head -1 || true)
HAVE_VERSION=$([ -n "$RKE2_BIN" ] && "$RKE2_BIN" --version 2>/dev/null | awk 'NR==1{print $3}' || true)
ARTIFACTS="/opt/rke2-artifacts/${RKE2_VERSION:-none}"
if [ -z "$RKE2_BIN" ] || { [ -n "${RKE2_VERSION:-}" ] && [ "$HAVE_VERSION" != "$RKE2_VERSION" ]; }; then
  [ -n "$RKE2_BIN" ] && log "replacing RKE2 $HAVE_VERSION with $RKE2_VERSION"
  if [ -n "${RKE2_VERSION:-}" ] && [ -f "$ARTIFACTS/.complete" ]; then
    # Offline: the image bundles go where RKE2 imports them on start, so the
    # node pulls no system image (hardlinks — same filesystem, no extra space).
    log "installing RKE2 $RKE2_VERSION ($TYPE) from $ARTIFACTS (no download)"
    mkdir -p /var/lib/rancher/rke2/agent/images
    for f in "$ARTIFACTS"/rke2-images-*.tar.zst; do
      ln -f "$f" /var/lib/rancher/rke2/agent/images/ 2>/dev/null || cp -f "$f" /var/lib/rancher/rke2/agent/images/
    done
    INSTALL_RKE2_TYPE="$TYPE" INSTALL_RKE2_ARTIFACT_PATH="$ARTIFACTS" sh "$ARTIFACTS/install.sh"
  elif [ -n "${RKE2_VERSION:-}" ]; then
    log "installing RKE2 $RKE2_VERSION ($TYPE) from GitHub"
    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="$TYPE" INSTALL_RKE2_VERSION="$RKE2_VERSION" sh -
  else
    log "installing RKE2 ($TYPE, channel ${RKE2_CHANNEL:-stable})"
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
