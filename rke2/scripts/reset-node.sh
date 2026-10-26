#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Wipes THIS node's cluster state but keeps everything that was downloaded, so
# install-cluster.sh can rebuild the cluster (e.g. after the node IPs changed)
# without pulling RKE2 or a single image again. Run as root (uninstall.sh reset
# runs it over SSH with sudo).
#
#   kept     RKE2 binary + systemd units (/usr/local), extracted runtime
#            (/var/lib/rancher/rke2/data), container images
#            (/var/lib/rancher/rke2/agent/containerd, agent/images)
#   removed  etcd, cluster CA/certs, tokens, kubeconfigs, node password, pods
#            and their containers, CNI state, local-storage volumes
#
# Env: HOSTPATH_BASE   OpenEBS hostpath base whose volumes belong to the old cluster
# -----------------------------------------------------------------------------
set -euo pipefail

log() { echo "[reset-node $(hostname)] $*"; }
die() { echo "[reset-node $(hostname)] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"

R=/var/lib/rancher/rke2
CRICTL="$R/bin/crictl"
SOCK=/run/k3s/containerd/containerd.sock

log "stopping rke2 (disabled until install-cluster.sh re-enables it)"
for u in rke2-server rke2-agent; do
  systemctl disable --now "$u" 2>/dev/null || true
done

# KillMode=process: containerd and the pods outlive the service. Remove pods
# through containerd while it still runs, so their containers go but the
# images stay; killall then stops containerd, unmounts and drops CNI links,
# flannel/calico interfaces and kube-proxy/CNI iptables rules.
if [ -S "$SOCK" ] && [ -x "$CRICTL" ]; then
  log "removing pods and containers (images kept)"
  "$CRICTL" --runtime-endpoint "unix://$SOCK" rmp -af >/dev/null 2>&1 || true
fi
KILLALL=$(command -v rke2-killall.sh || true)
for p in /usr/local/bin/rke2-killall.sh /opt/rke2/bin/rke2-killall.sh; do
  [ -n "$KILLALL" ] || { [ -x "$p" ] && KILLALL="$p"; }
done
if [ -n "$KILLALL" ]; then
  log "rke2-killall.sh"
  "$KILLALL" >/dev/null 2>&1 || true
fi

log "removing cluster state"
rm -rf "$R/server"
# agent/: certs, kubeconfigs, kubelet drop-ins, static pod manifests, logs go;
# containerd/ (images + snapshots) and images/ stay.
if [ -d "$R/agent" ]; then
  find "$R/agent" -mindepth 1 -maxdepth 1 ! -name containerd ! -name images -exec rm -rf {} +
fi
rm -f /etc/rancher/rke2/rke2.yaml /etc/rancher/node/password
rm -rf --one-file-system /var/lib/kubelet
rm -rf /var/lib/cni /etc/cni/net.d /run/flannel

# Volumes of the old cluster's PVCs: nothing in the new cluster can bind them.
log "removing local-storage volumes under ${HOSTPATH_BASE:-/var/openebs/local}"
rm -rf --one-file-system "${HOSTPATH_BASE:-/var/openebs/local}" /var/lib/alloy

log "done — kept $(du -sh "$R/agent/containerd" 2>/dev/null | cut -f1) of images"
