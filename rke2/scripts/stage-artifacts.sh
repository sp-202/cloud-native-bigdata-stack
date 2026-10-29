#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Stages the files to install one RKE2 version offline, so only ONE node pulls
# them from the internet and the others copy them over the LAN (install-cluster.sh
# drives this; install-rke2.sh then installs from the staged copy). Run as root.
#
#   stage-artifacts.sh fetch <version>          from GitHub
#   stage-artifacts.sh pull  <version> <url>    from another node's share,
#                                               e.g. http://192.168.1.11:8899
#
# Staged in /opt/rke2-artifacts/<version>/ (outside /var/lib/rancher, so
# uninstall.sh cluster/reset keep it and a reinstall downloads nothing):
#   install.sh  sha256sum-amd64.txt  rke2.linux-amd64.tar.gz
#   rke2-images-core.linux-amd64.tar.zst  rke2-images-canal.linux-amd64.tar.zst
#   .complete   (written once every file matches its sha256)
# Downloads resume after a dropped connection (curl -C -) and are retried.
# -----------------------------------------------------------------------------
set -euo pipefail

log() { echo "[stage-artifacts $(hostname)] $*"; }
die() { echo "[stage-artifacts $(hostname)] ERROR: $*" >&2; exit 1; }

MODE="${1:?usage: stage-artifacts.sh <fetch|pull> <version> [url]}"
VER="${2:?version required, e.g. v1.36.5+rke2r1}"
[ "$(id -u)" -eq 0 ] || die "run as root"

DIR="/opt/rke2-artifacts/$VER"
FILES=(rke2.linux-amd64.tar.gz rke2-images-core.linux-amd64.tar.zst rke2-images-canal.linux-amd64.tar.zst)
VER_URL="${VER//+/%2B}"
case "$MODE" in
  fetch) BASE="https://github.com/rancher/rke2/releases/download/$VER_URL"
         INSTALLER="https://raw.githubusercontent.com/rancher/rke2/$VER_URL/install.sh" ;;
  pull)  : "${3:?pull needs the share URL}"
         BASE="${3%/}/$VER_URL"; INSTALLER="$BASE/install.sh" ;;
  *) die "unknown mode $MODE" ;;
esac

if [ -f "$DIR/.complete" ]; then log "$VER already staged in $DIR"; exit 0; fi
mkdir -p "$DIR"; cd "$DIR"

get() {  # get <url> <file>: resumable, retried; a slow uplink drops long transfers
  local i
  for i in $(seq 1 40); do
    curl -fL --connect-timeout 20 --speed-limit 1024 --speed-time 120 -C - -o "$2" "$1" && return 0
    # Resuming a file that is already whole fails (HTTP 416): checksum decides.
    sha_ok "$2" && return 0
    log "  $2: attempt $i failed, retrying in 15s"; sleep 15
  done
  die "could not download $1"
}
sha_ok() { grep -E " $1\$" sha256sum-amd64.txt | sha256sum -c --status - 2>/dev/null; }

log "staging $VER ($MODE) into $DIR"
rm -f sha256sum-amd64.txt install.sh
curl -fsSL --retry 10 --retry-delay 10 -o sha256sum-amd64.txt "$BASE/sha256sum-amd64.txt" || die "no sha256sum-amd64.txt at $BASE"
curl -fsSL --retry 10 --retry-delay 10 -o install.sh "$INSTALLER" || die "no install.sh at $INSTALLER"
for f in "${FILES[@]}"; do
  grep -qE " $f\$" sha256sum-amd64.txt || die "$f is not listed in sha256sum-amd64.txt for $VER"
  if [ -s "$f" ] && sha_ok "$f"; then log "  $f: ok (already here)"; continue; fi
  log "  $f: downloading"
  get "$BASE/$f" "$f"
  if ! sha_ok "$f"; then
    log "  $f: checksum mismatch, downloading again from scratch"
    rm -f "$f"; get "$BASE/$f" "$f"
    sha_ok "$f" || die "$f: checksum mismatch twice"
  fi
  log "  $f: ok ($(du -h "$f" | cut -f1))"
done
chmod 0644 ./*; touch .complete
log "$VER staged ($(du -sh . | cut -f1))"
