#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Step 1 of 2: build the RKE2 cluster on the nodes in rke2/cluster.env.
# Replaces terraform-aws-k8s-ha's EKS/VPC/node-group layer. Run from this
# machine (WSL is fine); needs ssh/scp to every node and passwordless sudo
# there. Idempotent — safe to re-run (e.g. after adding an agent).
#
#   1. prep every node        (swap, sysctls, modules, firewall, dirs, LVM VG)
#   2. RKE2_VERSION's binary + system images: downloaded ONCE, on server 1
#      (resumable; keeps running if this machine disconnects), then copied
#      to every other node over the LAN in parallel  (scripts/stage-artifacts.sh)
#   3. first server           (cluster-init: etcd + control plane)
#   4. agents join in parallel; other servers one by one (concurrent etcd
#      joins can fail the learner promotion) — fast, nothing to download
#   5. kubeconfig -> $KUBECONFIG_OUT, pointed at server 1
#
# Env: ARTIFACT_PORT (default 8899) — server 1 shares the staged files on it
# during the install only.
#
# Next: rke2/bootstrap-platform.sh
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
load_env
need_cmd ssh scp kubectl

read -r -a SERVERS <<<"$SERVER_NODES"
read -r -a AGENTS <<<"${AGENT_NODES:-}"
FIRST_IP=$(node_ip "${SERVERS[0]}")
SERVER_URL="https://${FIRST_IP}:9345"
ALL_SERVER_IPS=""; for n in "${SERVERS[@]}"; do ALL_SERVER_IPS+=" $(node_ip "$n")"; done
TLS_SANS="$ALL_SERVER_IPS $INGRESS_IP $DOMAIN"

[ $(( ${#SERVERS[@]} % 2 )) -eq 1 ] || warn "${#SERVERS[@]} servers: etcd wants an odd count (3 recommended)"

# Variables the node-side scripts read. Values are shell-quoted for the remote side.
remote_env() {
  local name="$1" ip="$2"
  printf 'NODE_NAME=%q NODE_IP=%q SERVER_URL=%q RKE2_TOKEN=%q TLS_SANS=%q RKE2_CHANNEL=%q RKE2_VERSION=%q CANAL_IFACE=%q NODE_FIREWALL=%q STORAGE_BACKEND=%q HOSTPATH_BASE=%q LVM_VG=%q LVM_DEVICES=%q SPARK_LOCAL_DIR=%q SYSTEM_RESERVED=%q KUBE_RESERVED=%q EVICTION_HARD=%q' \
    "$name" "$ip" "$SERVER_URL" "${RKE2_TOKEN:-}" "$TLS_SANS" "${RKE2_CHANNEL:-stable}" "${RKE2_VERSION:-}" \
    "${CANAL_IFACE:-}" "${NODE_FIREWALL:-disable}" "$STORAGE_BACKEND" "${HOSTPATH_BASE:-/var/openebs/local}" \
    "${LVM_VG:-openebs-vg}" "${LVM_DEVICES:-}" "${SPARK_LOCAL_DIR:-/mnt/spark-nvme/spark-shuffle}" \
    "${SYSTEM_RESERVED:-}" "${KUBE_RESERVED:-}" "${EVICTION_HARD:-}"
}

run_on_node() {  # run_on_node <name:ip> <script> [args...]
  local spec="$1" script="$2"; shift 2
  local name ip; name=$(node_name "$spec"); ip=$(node_ip "$spec")
  node_scp "$ip" "$RKE2_DIR/scripts/$script" "/tmp/$script"
  node_ssh "$ip" "sudo env $(remote_env "$name" "$ip") bash /tmp/$script $*"
}

wait_server_ready() {  # the node's own API answers and it is Ready
  local spec="$1" name ip; name=$(node_name "$spec"); ip=$(node_ip "$spec")
  log "waiting for $name to become Ready"
  for _ in $(seq 1 90); do
    if node_ssh "$FIRST_IP" "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get node $name --no-headers 2>/dev/null" | grep -qw Ready; then
      return 0
    fi
    sleep 10
  done
  die "$name not Ready after 15 min — check: ssh $SSH_USER@$ip sudo journalctl -u rke2-server -u rke2-agent -n 100"
}

log "checking SSH + sudo on all nodes"
for spec in "${SERVERS[@]}" "${AGENTS[@]}"; do
  ip=$(node_ip "$spec")
  node_ssh "$ip" "sudo -n true" || die "ssh/sudo to $SSH_USER@$ip failed (key: ${SSH_KEY:-default}, passwordless sudo required)"
done

log "preparing nodes"
for spec in "${SERVERS[@]}" "${AGENTS[@]}"; do
  run_on_node "$spec" prep-node.sh
done

# ---------------------------------------------------------------- artifacts
# Pinned versions only: a channel resolves to whatever is newest at install
# time, so the nodes could end up on different builds.
if [ -n "${RKE2_VERSION:-}" ]; then
  ART=/opt/rke2-artifacts
  PORT="${ARTIFACT_PORT:-8899}"
  FIRST_NAME=$(node_name "${SERVERS[0]}")
  install_stager() {  # copy stage-artifacts.sh to a stable path on the node
    node_scp "$1" "$RKE2_DIR/scripts/stage-artifacts.sh" /tmp/stage-artifacts.sh
    node_ssh "$1" "sudo install -D -m 0755 /tmp/stage-artifacts.sh $ART/stage-artifacts.sh && rm -f /tmp/stage-artifacts.sh"
  }
  staged() { node_ssh "$1" "test -f '$ART/$RKE2_VERSION/.complete'"; }

  install_stager "$FIRST_IP"
  if staged "$FIRST_IP"; then
    log "RKE2 $RKE2_VERSION already staged on $FIRST_NAME — nothing to download"
  else
    # A transient systemd unit, not this SSH session: the download (~800 MB)
    # takes long on a slow uplink and survives this machine sleeping or
    # leaving. Re-running install-cluster.sh just waits for it again.
    log "downloading RKE2 $RKE2_VERSION once, on $FIRST_NAME (log: /var/log/rke2-artifacts.log there)"
    node_ssh "$FIRST_IP" "systemctl is-active --quiet rke2-artifacts-fetch || { sudo systemctl reset-failed rke2-artifacts-fetch 2>/dev/null; \
      sudo systemd-run --unit=rke2-artifacts-fetch --description='stage RKE2 $RKE2_VERSION' \
        -p StandardOutput=append:/var/log/rke2-artifacts.log -p StandardError=append:/var/log/rke2-artifacts.log \
        bash $ART/stage-artifacts.sh fetch '$RKE2_VERSION' >/dev/null; }"
    until staged "$FIRST_IP"; do
      if ! node_ssh "$FIRST_IP" "systemctl is-active --quiet rke2-artifacts-fetch"; then
        staged "$FIRST_IP" && break
        node_ssh "$FIRST_IP" "sudo tail -n 15 /var/log/rke2-artifacts.log" >&2 || true
        die "download on $FIRST_NAME failed — fix and re-run (finished files are kept, partial ones resume)"
      fi
      echo "  $(node_ssh "$FIRST_IP" "sudo du -sh $ART/$RKE2_VERSION 2>/dev/null | cut -f1") of ~810 MB on $FIRST_NAME"
      sleep 60
    done
    log "staged on $FIRST_NAME"
  fi

  # Share server 1's copy over the LAN while the others pull it (in parallel).
  OTHERS=("${SERVERS[@]:1}" "${AGENTS[@]}")
  need=()
  for spec in "${OTHERS[@]}"; do
    [ -n "$spec" ] || continue
    install_stager "$(node_ip "$spec")"
    staged "$(node_ip "$spec")" || need+=("$spec")
  done
  if [ "${#need[@]}" -gt 0 ]; then
    log "copying RKE2 $RKE2_VERSION from $FIRST_NAME to:$(for s in "${need[@]}"; do printf ' %s' "$(node_name "$s")"; done) (parallel)"
    node_ssh "$FIRST_IP" "sudo systemctl stop rke2-artifacts-http 2>/dev/null; sudo systemctl reset-failed rke2-artifacts-http 2>/dev/null; \
      sudo systemd-run --unit=rke2-artifacts-http -p RuntimeMaxSec=3h \
        python3 -m http.server $PORT --bind $FIRST_IP --directory $ART >/dev/null"
    trap 'node_ssh "$FIRST_IP" "sudo systemctl stop rke2-artifacts-http" 2>/dev/null || true' EXIT
    pids=()
    for spec in "${need[@]}"; do
      node_ssh "$(node_ip "$spec")" "sudo bash $ART/stage-artifacts.sh pull '$RKE2_VERSION' http://$FIRST_IP:$PORT" &
      pids+=($!)
    done
    failed=""
    for i in "${!pids[@]}"; do wait "${pids[$i]}" || failed+=" $(node_name "${need[$i]}")"; done
    node_ssh "$FIRST_IP" "sudo systemctl stop rke2-artifacts-http" || true
    trap - EXIT
    [ -z "$failed" ] || die "copy failed on:$failed — re-run (finished files are kept)"
  fi
fi

log "server 1: $(node_name "${SERVERS[0]}") ($FIRST_IP) — cluster-init"
run_on_node "${SERVERS[0]}" install-rke2.sh server-init
for _ in $(seq 1 60); do
  RKE2_TOKEN=$(node_ssh "$FIRST_IP" "sudo cat /var/lib/rancher/rke2/server/node-token 2>/dev/null" || true)
  [ -n "$RKE2_TOKEN" ] && break
  sleep 5
done
[ -n "${RKE2_TOKEN:-}" ] || die "no node-token on $FIRST_IP after 5 min — check journalctl -u rke2-server"
wait_server_ready "${SERVERS[0]}"

# Agents don't touch etcd: all of them join in the background right away.
agent_pids=(); agent_specs=()
for spec in "${AGENTS[@]}"; do
  [ -n "$spec" ] || continue
  log "agent: $(node_name "$spec") ($(node_ip "$spec")) — join (background)"
  run_on_node "$spec" install-rke2.sh agent &
  agent_pids+=($!); agent_specs+=("$spec")
done
# Servers one at a time: concurrent etcd member joins can fail the learner promotion.
for spec in "${SERVERS[@]:1}"; do
  log "server: $(node_name "$spec") ($(node_ip "$spec")) — join"
  run_on_node "$spec" install-rke2.sh server
  wait_server_ready "$spec"
done
if [ "${#agent_pids[@]}" -gt 0 ]; then  # bash 3.2 (macOS): empty "${arr[@]}" trips set -u
  for i in "${!agent_pids[@]}"; do
    wait "${agent_pids[$i]}" || die "install on agent $(node_name "${agent_specs[$i]}") failed"
    wait_server_ready "${agent_specs[$i]}"
  done
fi

log "writing kubeconfig to $KUBECONFIG_OUT"
mkdir -p "$(dirname "$KUBECONFIG_OUT")"
umask 077
node_ssh "$FIRST_IP" "sudo cat /etc/rancher/rke2/rke2.yaml" \
  | sed "s#https://127.0.0.1:6443#https://${FIRST_IP}:6443#" > "$KUBECONFIG_OUT"
export KUBECONFIG="$KUBECONFIG_OUT"

# Dedicated StarRocks node: label (pods select it) + taint (everything else
# stays off). Applied with kubectl, not kubelet --node-labels: kubelets may not
# self-assign node-role.kubernetes.io/* labels (NodeRestriction).
if [ -n "${STARROCKS_NODE:-}" ]; then
  log "dedicating $STARROCKS_NODE to StarRocks"
  kubectl label node "$STARROCKS_NODE" node-role.kubernetes.io/starrocks= --overwrite
  kubectl taint node "$STARROCKS_NODE" dedicated=starrocks:NoSchedule --overwrite
fi

kubectl get nodes -o wide
kubectl get nodes -o custom-columns='NODE:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,TAINTS:.spec.taints[*].key'

log "cluster is up. Next:  rke2/bootstrap-platform.sh"
log "kubectl:              export KUBECONFIG=$KUBECONFIG_OUT"
