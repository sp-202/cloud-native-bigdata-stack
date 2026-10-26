#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Runs rke2/bootstrap-platform.sh ON the first server instead of on this
# machine, so it can run unattended (overnight, laptop closed or gone).
#
#   bootstrap-on-node.sh start    copy rke2/ (incl. cluster.env) to the node,
#                                 install helm there if missing, start the
#                                 systemd unit platform-bootstrap: retries the
#                                 bootstrap (it is idempotent) until it succeeds
#   bootstrap-on-node.sh status   result so far + Argo CD apps + unhealthy pods
#   bootstrap-on-node.sh logs     follow the log (Ctrl-C only stops following)
#   bootstrap-on-node.sh stop     stop the run
#
# Env: ATTEMPTS (default 8), PAUSE seconds between attempts (default 300).
# The node keeps the run going after SSH disconnects; a node reboot ends it
# (re-run start). Node side: scripts/bootstrap-runner.sh.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
load_env
need_cmd ssh tar

HELM_VERSION="v4.0.4"   # same major as the workstation's helm (server-side apply)
HELM_SHA256="29454bc351f4433e66c00f5d37841627cbbcc02e4c70a6d796529d355237671c"
BASE=/opt/bigdata-bootstrap
UNIT=platform-bootstrap
LOGF=/var/log/platform-bootstrap.log

read -r -a SERVERS <<<"$SERVER_NODES"
IP=$(node_ip "${SERVERS[0]}"); NAME=$(node_name "${SERVERS[0]}")
K="sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml"

case "${1:-}" in
start)
  if node_ssh "$IP" "systemctl is-active --quiet $UNIT"; then
    die "$UNIT already running on $NAME — see: $0 status / $0 logs"
  fi
  node_ssh "$IP" "sudo -n true" || die "ssh/sudo to $SSH_USER@$IP failed"

  log "$NAME: helm $HELM_VERSION"
  node_ssh "$IP" "set -e
    if command -v helm >/dev/null && helm version --short 2>/dev/null | grep -q '^$HELM_VERSION'; then echo '  already installed'; exit 0; fi
    t=\$(mktemp -d); cd \"\$t\"
    curl -fsSLo helm.tgz https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz
    echo '$HELM_SHA256  helm.tgz' | sha256sum -c --quiet
    tar -xzf helm.tgz linux-amd64/helm
    sudo install -m 0755 linux-amd64/helm /usr/local/bin/helm
    cd /; rm -rf \"\$t\"; helm version --short"

  log "$NAME: copying rke2/ to $BASE/rke2"
  # No macOS resource forks / xattrs in the archive; never ship the local kubeconfig.
  COPYFILE_DISABLE=1 tar -C "$REPO_ROOT" --no-xattrs --exclude 'rke2/kubeconfig*' -czf - rke2 \
    | node_ssh "$IP" "sudo rm -rf $BASE/rke2 && sudo mkdir -p $BASE && sudo tar -C $BASE -xzf - --warning=no-unknown-keyword && sudo chmod -R go-rwx $BASE"

  log "$NAME: starting $UNIT (attempts ${ATTEMPTS:-8}, ${PAUSE:-300}s apart)"
  node_ssh "$IP" "sudo systemctl reset-failed $UNIT 2>/dev/null; sudo truncate -s 0 $LOGF 2>/dev/null; \
    sudo systemd-run --unit=$UNIT --description='bootstrap-platform.sh (unattended)' \
      -p StandardOutput=append:$LOGF -p StandardError=append:$LOGF \
      --setenv=BASE=$BASE --setenv=ATTEMPTS=${ATTEMPTS:-8} --setenv=PAUSE=${PAUSE:-300} \
      bash $BASE/rke2/scripts/bootstrap-runner.sh"
  log "running on $NAME — safe to disconnect. Check later:  $0 status   (or: $0 logs)"
  ;;
status)
  node_ssh "$IP" "echo \"result: \$(sudo cat $BASE/STATUS 2>/dev/null || echo 'never started')   unit: \$(systemctl is-active $UNIT)\"
    echo '--- last log lines'; sudo tail -n 15 $LOGF 2>/dev/null
    echo '--- Argo CD applications'; $K -n argocd get applications 2>/dev/null || echo '  (Argo CD not installed yet)'
    echo '--- pods not Running/Completed'; $K get pods -A --no-headers 2>/dev/null | awk '\$4!=\"Running\" && \$4!=\"Completed\"' | head -30"
  ;;
logs)
  node_ssh "$IP" "sudo tail -n 50 -F $LOGF"
  ;;
stop)
  node_ssh "$IP" "sudo systemctl stop $UNIT; echo \"unit: \$(systemctl is-active $UNIT)\""
  ;;
*)
  die "usage: $0 <start|status|logs|stop>"
  ;;
esac
