#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Step 1 of 2: build the RKE2 cluster on the nodes in rke2/cluster.env.
# Replaces terraform-aws-k8s-ha's EKS/VPC/node-group layer. Run from this
# machine (WSL is fine); needs ssh/scp to every node and passwordless sudo
# there. Idempotent — safe to re-run (e.g. after adding an agent).
#
#   1. prep every node        (swap, sysctls, modules, firewall, dirs, LVM VG)
#   2. first server           (cluster-init: etcd + control plane)
#   3. other servers, one by one (join etcd), then agents
#   4. kubeconfig -> $KUBECONFIG_OUT, pointed at server 1
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

log "server 1: $(node_name "${SERVERS[0]}") ($FIRST_IP) — cluster-init"
run_on_node "${SERVERS[0]}" install-rke2.sh server-init
for _ in $(seq 1 60); do
  RKE2_TOKEN=$(node_ssh "$FIRST_IP" "sudo cat /var/lib/rancher/rke2/server/node-token 2>/dev/null" || true)
  [ -n "$RKE2_TOKEN" ] && break
  sleep 5
done
[ -n "${RKE2_TOKEN:-}" ] || die "no node-token on $FIRST_IP after 5 min — check journalctl -u rke2-server"
wait_server_ready "${SERVERS[0]}"

# One at a time: concurrent etcd member joins can fail the learner promotion.
for spec in "${SERVERS[@]:1}"; do
  log "server: $(node_name "$spec") ($(node_ip "$spec")) — join"
  run_on_node "$spec" install-rke2.sh server
  wait_server_ready "$spec"
done
for spec in "${AGENTS[@]}"; do
  [ -n "$spec" ] || continue
  log "agent: $(node_name "$spec") ($(node_ip "$spec")) — join"
  run_on_node "$spec" install-rke2.sh agent
  wait_server_ready "$spec"
done

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
