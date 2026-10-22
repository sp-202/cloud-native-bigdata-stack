#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Node preparation for RKE2 + the platform. Runs ON a node, as root
# (install-cluster.sh copies it over and runs it with sudo). Idempotent.
#
# Env (from cluster.env, passed by install-cluster.sh):
#   NODE_FIREWALL     disable|keep
#   STORAGE_BACKEND   hostpath|lvm
#   HOSTPATH_BASE     OpenEBS hostpath base dir
#   LVM_VG, LVM_DEVICES
#   SPARK_LOCAL_DIR
# -----------------------------------------------------------------------------
set -euo pipefail

log() { echo "[prep-node $(hostname)] $*"; }
die() { echo "[prep-node $(hostname)] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"
[ "$(uname -m)" = "x86_64" ] || die "this branch targets x86_64 nodes, got $(uname -m)"

NODE_FIREWALL="${NODE_FIREWALL:-disable}"
STORAGE_BACKEND="${STORAGE_BACKEND:-hostpath}"
HOSTPATH_BASE="${HOSTPATH_BASE:-/var/openebs/local}"
LVM_VG="${LVM_VG:-openebs-vg}"
LVM_DEVICES="${LVM_DEVICES:-}"
SPARK_LOCAL_DIR="${SPARK_LOCAL_DIR:-/mnt/spark-nvme/spark-shuffle}"

pkg_install() {
  if command -v apt-get >/dev/null; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
  elif command -v dnf >/dev/null; then
    dnf install -y -q "$@"
  elif command -v zypper >/dev/null; then
    zypper --non-interactive install "$@"
  else
    die "no supported package manager (apt/dnf/zypper) to install: $*"
  fi
}

# --- swap off (kubelet refuses to start with swap on by default) ------------
if swapon --show | grep -q .; then
  log "disabling swap"
  swapoff -a
fi
sed -ri '/\sswap\s/ s/^([^#])/#\1/' /etc/fstab

# --- kernel modules + sysctls ------------------------------------------------
cat > /etc/modules-load.d/rke2.conf <<'MODS'
overlay
br_netfilter
MODS
modprobe overlay
modprobe br_netfilter

# inotify: Alloy tails every pod log, Loki/Prometheus/Spark open many files;
# distro defaults (128 instances) run out on a busy node ("too many open
# files" from fsnotify).
cat > /etc/sysctl.d/90-rke2-platform.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576
vm.max_map_count = 262144
SYSCTL
sysctl --system >/dev/null

# --- NetworkManager must not manage Canal's interfaces ----------------------
# Otherwise NM can strip routes from cali*/flannel* links (RKE2 known issue).
if systemctl is-active --quiet NetworkManager; then
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/rke2-canal.conf <<'NM'
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
NM
  systemctl reload NetworkManager || true
fi

# --- firewall ----------------------------------------------------------------
if [ "$NODE_FIREWALL" = "disable" ]; then
  for svc in firewalld ufw; do
    if systemctl is-active --quiet "$svc"; then
      log "stopping $svc (NODE_FIREWALL=disable)"
      systemctl disable --now "$svc"
    fi
  done
else
  log "NODE_FIREWALL=keep: make sure the ports in rke2/README.md are open between nodes"
fi

# --- time sync (etcd and TLS hate clock skew) --------------------------------
if ! timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
  log "WARNING: clock not NTP-synchronised — enable chrony or systemd-timesyncd"
fi

# --- base packages -----------------------------------------------------------
need=()
command -v curl >/dev/null || need+=(curl)
if [ "$STORAGE_BACKEND" = "lvm" ]; then
  command -v lvm >/dev/null || need+=(lvm2)
fi
[ ${#need[@]} -eq 0 ] || { log "installing ${need[*]}"; pkg_install "${need[@]}"; }

# --- storage -----------------------------------------------------------------
mkdir -p "$HOSTPATH_BASE"

if [ "$STORAGE_BACKEND" = "lvm" ]; then
  if vgs "$LVM_VG" >/dev/null 2>&1; then
    log "LVM volume group $LVM_VG already present"
  else
    [ -n "$LVM_DEVICES" ] || die "STORAGE_BACKEND=lvm but VG $LVM_VG is missing and LVM_DEVICES is empty"
    for dev in $LVM_DEVICES; do
      [ -b "$dev" ] || die "$dev is not a block device"
      # Refuse anything that already holds data: partition tables, filesystems,
      # RAID/LVM signatures. wipefs -n only lists, never writes.
      if [ -n "$(wipefs -n "$dev" 2>/dev/null | tail -n +2)" ]; then
        die "$dev has existing signatures (partition table/filesystem/LVM) — wipe it yourself if it is really free"
      fi
      if lsblk -nro MOUNTPOINT "$dev" | grep -q .; then
        die "$dev (or a partition on it) is mounted"
      fi
    done
    log "creating VG $LVM_VG on $LVM_DEVICES"
    # shellcheck disable=SC2086
    pvcreate $LVM_DEVICES
    # shellcheck disable=SC2086
    vgcreate "$LVM_VG" $LVM_DEVICES
  fi
  modprobe dm_snapshot 2>/dev/null || true
  modprobe dm_thin_pool 2>/dev/null || true
fi

# Spark shuffle/spill: executors run as uid 185, Alloy reads it. Sticky
# world-writable like /tmp, so kubelet's DirectoryOrCreate (root 0755)
# never leaves it unwritable for Spark.
mkdir -p "$SPARK_LOCAL_DIR"
chmod 1777 "$SPARK_LOCAL_DIR"

# Alloy's positions + remote-write WAL (hostPath in values.yaml).
mkdir -p /var/lib/alloy

log "done"
