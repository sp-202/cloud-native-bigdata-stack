# 2-node test cluster: step-by-step setup

What you end up with: an RKE2 cluster on **node-01 (server) + node-02 (agent)** running Gravitino,
Airflow, Postgres, Prometheus + Grafana and the Spark Operator, all deployed by Argo CD from the
`rke2` branch. Each UI is reachable at `http://<name>.<node-01-ip>.sslip.io`.

Which service lands on which node: [`NODE-LAYOUT.md`](NODE-LAYOUT.md) (profile `2node`).

Total time: about 1 hour, mostly waiting for image downloads.

---

## Step 0: decide where you run the scripts (the "control machine")

The scripts run **on one machine** and drive both nodes over SSH. Pick one:

| Option | When |
| --- | --- |
| **A. node-01 itself** | simplest; you have the repo on node-01 |
| B. your laptop/WSL | the repo is on your laptop and it can SSH to both nodes |

All commands below marked **(control)** run on that machine, **from the repo root**
(`cd cloud-native-bigdata-stack`). Commands marked **(each node)** run on node-01 *and* node-02.

---

## Step 1: check both nodes

**(each node)**

```bash
uname -m                 # must print x86_64
hostnamectl              # note the hostname; it does not have to be node-01, the scripts set the k8s name
ip -4 addr               # note the node's LAN IP, e.g. 192.168.1.21 / 192.168.1.22
free -g; nproc; df -h /  # 16 GB RAM, 20 cores, 100+ GB free on / (or wherever /var lives)
timedatectl              # "System clock synchronized: yes"
curl -sI https://get.rke2.io | head -1   # internet works (HTTP/2 200)
```

Requirements:
- Ubuntu 22.04/24.04 (or Debian 12 / RHEL 9 family)
- **static IPs** (or DHCP reservations)
- the two nodes can reach each other on the LAN
- the clock is in sync

If the clock isn't synced:

```bash
sudo apt-get install -y chrony && sudo systemctl enable --now chrony
```

---

## Step 2: SSH key + passwordless sudo

**(each node)**: let your user run sudo without a password (the scripts call `sudo -n`):
```bash
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-$USER
sudo chmod 440 /etc/sudoers.d/90-$USER
```

**(control)**: create a key once and copy it to both nodes. With option A, also copy it to
node-01's own IP, because the scripts SSH to every node, including the one they run on:
```bash
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@192.168.1.21
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@192.168.1.22
```

**(control)**: verify. Both must print `ok` with **no password prompt**:
```bash
ssh <user>@192.168.1.21 'sudo -n true && echo ok'
ssh <user>@192.168.1.22 'sudo -n true && echo ok'
```

---

## Step 3: tools on the control machine

**(control)**: needs `git kubectl helm jq openssl ssh`. On Ubuntu:
```bash
sudo apt-get update && sudo apt-get install -y git jq openssl openssh-client curl

# kubectl (same minor as RKE2 v1.33)
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/v1.33.5/bin/linux/amd64/kubectl"
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# helm 3
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

kubectl version --client && helm version && jq --version
```

---

## Step 4: get the code

**(control)**
```bash
git clone -b rke2 https://github.com/sp-202/cloud-native-bigdata-stack.git   # first time
# or, if you already have it:
cd cloud-native-bigdata-stack && git checkout rke2 && git pull
git log --oneline -1          # should match the latest commit on GitHub's rke2 branch
```

Argo CD later pulls the platform **from GitHub's `rke2` branch**, not from this folder. Any
change to `big-data-platform/` must be pushed before it reaches the cluster.

---

## Step 5: configure

**(control)**
```bash
cp rke2/cluster-2node.env.example rke2/cluster-2node.env
nano rke2/cluster-2node.env
```

Set at least these:

| Setting | Value |
| --- | --- |
| `SERVER_NODES` | `"node-01:<node-01 IP>"` |
| `AGENT_NODES` | `"node-02:<node-02 IP>"` |
| `SSH_USER` | your login user on the nodes |
| `SSH_KEY` | `"$HOME/.ssh/id_ed25519"` |
| `INGRESS_IP` | node-01's IP (it goes into every URL) |
| `PLATFORM_PROFILE` | keep `"2node"` |
| `STORAGE_BACKEND` | keep `"hostpath"` (no disk prep) |
| `KUBECONFIG_OUT` | keep `"rke2/kubeconfig-2node"` |

Optional:
- `RKE2_VERSION="v1.33.5+rke2r1"`: pin an exact release, see github.com/rancher/rke2/releases.
- `CANAL_IFACE="ens18"`: only if a node has several NICs.
- `NODE_FIREWALL="keep"`: if you must keep ufw/firewalld. Then open the ports in `README.md`.

`cluster-2node.env` is gitignored. It never gets committed.

Point every script at this file for the rest of the session:
```bash
export CLUSTER_ENV=rke2/cluster-2node.env
```

---

## Step 6: build the cluster (≈10–15 min)

**(control)**
```bash
rke2/install-cluster.sh
```

What it does:
1. Checks SSH + sudo on both nodes.
2. Preps both nodes: swap off, kernel modules/sysctls, firewall off, dirs.
3. Installs the RKE2 server on node-01 and waits for it to be Ready.
4. Joins node-02 as an agent.
5. Writes `rke2/kubeconfig-2node`.

Check it:
```bash
export KUBECONFIG=$PWD/rke2/kubeconfig-2node
kubectl get nodes -o wide
# NAME      STATUS   ROLES                       VERSION
# node-01   Ready    control-plane,etcd,master   v1.33.x+rke2r1
# node-02   Ready    <none>                      v1.33.x+rke2r1
kubectl get nodes -o custom-columns='NODE:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
# ~18500m CPU and ~13.5-14Gi memory each (2 GiB held back for the OS)
kubectl get pods -n kube-system     # canal, coredns, kube-proxy, metrics-server... all Running
```

---

## Step 7: install the platform (≈20–40 min)

**(control)**, same shell (with `CLUSTER_ENV` still exported):
```bash
rke2/bootstrap-platform.sh
```

What it does, in order:
1. OpenEBS + StorageClass `local-storage`.
2. Traefik on ports 80/443 of both nodes.
3. Argo CD.
4. Generates all passwords/keys as Kubernetes Secrets (once only; re-runs keep them).
5. SeaweedFS (S3), then waits for it to be healthy.
6. Creates the S3 buckets.
7. Installs the CRDs.
8. Creates the `big-data-platform` Argo CD Application with the `2node` values.
9. Waits up to 45 min for it to be Synced/Healthy.

The script prints all URLs and password commands at the end. While it waits, you can watch
progress in another terminal:
```bash
export KUBECONFIG=$PWD/rke2/kubeconfig-2node
kubectl -n argocd get applications -w
kubectl get pods -A -o wide --sort-by=.spec.nodeName
```

If the final wait times out, that's often just slow image pulls. Check
`kubectl -n argocd get applications`: once both show **Synced / Healthy**, you're done.

---

## Step 8: open the UIs

With `INGRESS_IP=192.168.1.21`:

| Service | URL | Login |
| --- | --- | --- |
| Argo CD | http://argocd.192.168.1.21.sslip.io | `admin` / see below |
| Airflow | http://airflow.192.168.1.21.sslip.io | `admin` / see below |
| Grafana | http://grafana.192.168.1.21.sslip.io | `admin` / see below |
| Gravitino | http://gravitino.192.168.1.21.sslip.io | — |
| Prometheus | http://prometheus.192.168.1.21.sslip.io | — |
| Traefik | http://traefik.192.168.1.21.sslip.io/dashboard/ | — |

Passwords:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl get secret airflow-credentials -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl get secret grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

---

## Step 9: smoke checks

```bash
# all platform pods Running/Completed
kubectl get pods -o wide

# Postgres (CNPG) healthy, 1 instance
kubectl get cluster postgres            # STATUS "Cluster in healthy state"

# Gravitino: metalake + Iceberg catalog registered by gravitino-init
kubectl run -it --rm gcheck --image=curlimages/curl:8.5.0 --restart=Never -- \
  curl -s http://gravitino:8090/api/metalakes/enterprise_metalake/catalogs

# S3 (SeaweedFS): buckets exist
kubectl run -it --rm s3check --image=amazon/aws-cli:2.37.4 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"s3check","image":"amazon/aws-cli:2.37.4","args":["s3","ls"],"envFrom":[{"secretRef":{"name":"lakehouse-s3"}}],"env":[{"name":"HOME","value":"/tmp"}]}]}}'

# Airflow: DAGs synced from github.com/sp-202/airflow-dags (git-sync), visible in the UI
# Grafana: Dashboards -> Kubernetes / node dashboards show both nodes
```

---

## Troubleshooting

| Symptom | Check / fix |
| --- | --- |
| `ssh/sudo ... failed` in step 6 | redo Step 2; `ssh <user>@<ip> 'sudo -n true'` must not prompt |
| node stays NotReady | on that node: `sudo journalctl -u rke2-server -u rke2-agent -n 100 --no-pager`; check the firewall is off and the nodes can reach each other on 9345/6443/8472 (udp) |
| `*.sslip.io` doesn't open | `nslookup grafana.192.168.1.21.sslip.io` should return 192.168.1.21. Some routers block DNS answers pointing at private IPs ("DNS rebind protection"). Allow `sslip.io` on the router, or add `/etc/hosts` lines like `192.168.1.21 grafana.192.168.1.21.sslip.io` |
| app OutOfSync / Degraded | `kubectl -n argocd describe application big-data-platform` (shows the failing resource); the Argo CD UI shows the same per resource |
| pod Pending | `kubectl describe pod <pod>`: "Insufficient memory" means too much is switched on; "unbound PVC" means `kubectl get pvc` and `kubectl -n openebs get pods` |
| pod ImagePullBackOff | the node has no internet or Docker Hub is rate-limiting: `kubectl describe pod <pod>` |
| bootstrap failed halfway | fix the cause and re-run `rke2/bootstrap-platform.sh`. It is idempotent and never regenerates existing passwords |

---

## Day-2

- **Change config**: edit `big-data-platform/values.yaml` (both clusters) or
  `big-data-platform/values-2node.yaml` (test cluster only), commit, push to `rke2`. Argo CD
  syncs within ~3 minutes.
- **Turn on one more service** in the test cluster: set it to `enabled: true` in
  `values-2node.yaml` (plus its `ingress.<name>.enabled` if it has a UI), then push. Example:
  `spark-history-server`.
- **Start over (platform only)**: `rke2/uninstall.sh platform`, then
  `rke2/bootstrap-platform.sh`.
- **Wipe the nodes completely**: `rke2/uninstall.sh cluster`. This deletes all data on both nodes.

Keep `export CLUSTER_ENV=rke2/cluster-2node.env` set in any shell where you run these. Without
it the scripts read `rke2/cluster.env` (the 4-node cluster).
