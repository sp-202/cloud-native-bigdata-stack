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

# --- IPv4 only ----------------------------------------------------------------
# The cluster is single-stack IPv4 (pod/service CIDRs, node IPs). A network that
# hands out IPv6 without routing it (seen on office/guest WiFi) makes image
# pulls dial registries' AAAA addresses first and fail with "network is
# unreachable". IPv6 off on every interface; lo keeps ::1 for local listeners.
cat > /etc/sysctl.d/91-rke2-ipv4-only.conf <<'IPV4'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
IPV4
sysctl --system >/dev/null

# NetworkManager re-enables IPv6 on an interface when it (re)activates a
# connection with ipv6.method=auto. Disabled per connection; takes effect on
# its next activation (no reconnect now — that would drop this SSH session).
if systemctl is-active --quiet NetworkManager && command -v nmcli >/dev/null; then
  nmcli -t -f NAME,TYPE connection show 2>/dev/null \
    | awk -F: '$NF ~ /^802-(11-wireless|3-ethernet)$/ {NF--; print}' OFS=: \
    | while IFS= read -r con; do
        [ "$(nmcli -g ipv6.method connection show "$con" 2>/dev/null)" = disabled ] && continue
        log "NetworkManager: ipv6.method=disabled for '$con'"
        nmcli connection modify "$con" ipv6.method disabled || log "WARNING: could not modify '$con'"
      done
fi

# --- host DNS: public resolvers next to the network's own ----------------------
# Image pulls resolve registries through systemd-resolved (127.0.0.53). A
# hotspot/guest DNS that drops the odd query stalls a pull for 20s and fails
# it ("lookup auth.docker.io ... i/o timeout"). Global servers are queried
# alongside the link's, first answer wins; works on any network.
mkdir -p /etc/systemd/resolved.conf.d
NEW_RESOLVED=$(mktemp)
cat > "$NEW_RESOLVED" <<'RESOLVED'
# Managed by rke2/scripts/prep-node.sh
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9 1.0.0.1
RESOLVED
if ! cmp -s "$NEW_RESOLVED" /etc/systemd/resolved.conf.d/90-rke2-dns.conf; then
  install -m 0644 "$NEW_RESOLVED" /etc/systemd/resolved.conf.d/90-rke2-dns.conf
  systemctl restart systemd-resolved
  log "systemd-resolved: global DNS 1.1.1.1 8.8.8.8 next to the network's"
fi
rm -f "$NEW_RESOLVED"

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
