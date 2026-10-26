#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Runs bootstrap-platform.sh ON a server node, retrying until it succeeds, so
# the platform install needs no workstation online. Started by
# rke2/bootstrap-on-node.sh as the transient systemd unit platform-bootstrap
# (survives SSH logout; not a reboot). Run as root.
#
# Layout: $BASE/rke2 = copy of this repo's rke2/ (incl. cluster.env).
# Env: ATTEMPTS (default 8), PAUSE seconds between attempts (default 300).
# Result in $BASE/STATUS: running <n>/<max> | success | failed. Log: journal
# of the unit and /var/log/platform-bootstrap.log.
# -----------------------------------------------------------------------------
set -uo pipefail

BASE="${BASE:-/opt/bigdata-bootstrap}"
ATTEMPTS="${ATTEMPTS:-8}"
PAUSE="${PAUSE:-300}"
export PATH="/var/lib/rancher/rke2/bin:/usr/local/bin:$PATH"
export HOME="${HOME:-/root}"

# bootstrap-platform.sh reads $KUBECONFIG_OUT (cluster.env: rke2/kubeconfig,
# i.e. $BASE/rke2/kubeconfig). The node's admin kubeconfig talks to the local API.
install -m 0600 /etc/rancher/rke2/rke2.yaml "$BASE/rke2/kubeconfig"

for i in $(seq 1 "$ATTEMPTS"); do
  echo "running $i/$ATTEMPTS" > "$BASE/STATUS"
  echo "=== attempt $i/$ATTEMPTS — $(date -Is)"
  if bash "$BASE/rke2/bootstrap-platform.sh"; then
    echo success > "$BASE/STATUS"
    echo "=== SUCCESS — $(date -Is)"
    exit 0
  fi
  echo "=== attempt $i failed — $(date -Is)"
  [ "$i" -lt "$ATTEMPTS" ] && { echo "=== next attempt in ${PAUSE}s"; sleep "$PAUSE"; }
done
echo failed > "$BASE/STATUS"
echo "=== FAILED after $ATTEMPTS attempts — $(date -Is)"
exit 1
