#!/usr/bin/env bash
# Shared helpers for the rke2/*.sh entry points. Sourced, not executed.

RKE2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$RKE2_DIR/.." && pwd)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

load_env() {
  local env_file="${CLUSTER_ENV:-$RKE2_DIR/cluster.env}"
  [ -f "$env_file" ] || die "$env_file not found — cp rke2/cluster.env.example rke2/cluster.env and edit it"
  # shellcheck disable=SC1090
  set -a; source "$env_file"; set +a
  : "${SERVER_NODES:?set SERVER_NODES in cluster.env}"
  : "${INGRESS_IP:?set INGRESS_IP in cluster.env}"
  SSH_PORT="${SSH_PORT:-22}"
  STORAGE_BACKEND="${STORAGE_BACKEND:-hostpath}"
  case "$STORAGE_BACKEND" in hostpath|lvm) ;; *) die "STORAGE_BACKEND must be hostpath or lvm" ;; esac
  KUBECONFIG_OUT="${KUBECONFIG_OUT:-rke2/kubeconfig}"
  case "$KUBECONFIG_OUT" in /*) ;; *) KUBECONFIG_OUT="$REPO_ROOT/$KUBECONFIG_OUT" ;; esac
  DOMAIN="${INGRESS_IP}.sslip.io"
}

node_name() { echo "${1%%:*}"; }
node_ip()   { echo "${1##*:}"; }

ssh_common_opts() {  # options shared by ssh and scp (they differ only in the port flag)
  local o=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
  [ -n "${SSH_KEY:-}" ] && o+=(-i "$SSH_KEY")
  printf '%s\n' "${o[@]}"
}
node_ssh() {  # node_ssh <ip> <command...>
  local ip="$1"; shift
  local opts; mapfile -t opts < <(ssh_common_opts)
  ssh "${opts[@]}" -p "$SSH_PORT" "${SSH_USER}@${ip}" "$@"
}
node_scp() {  # node_scp <ip> <local> <remote>
  local opts; mapfile -t opts < <(ssh_common_opts)
  scp -q "${opts[@]}" -P "$SSH_PORT" "$2" "${SSH_USER}@${1}:$3"
}

need_cmd() { for c in "$@"; do command -v "$c" >/dev/null || die "'$c' is required on this machine"; done; }

use_kubeconfig() {
  [ -f "$KUBECONFIG_OUT" ] || die "$KUBECONFIG_OUT missing — run rke2/install-cluster.sh first (or set KUBECONFIG_OUT)"
  export KUBECONFIG="$KUBECONFIG_OUT"
}
