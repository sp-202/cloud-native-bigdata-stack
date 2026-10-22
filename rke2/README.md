# Big Data Platform on RKE2 (on-prem, x86_64)

Branch `rke2`: the platform from `main` (EKS, Graviton, Terraform) ported to a bare
4-node RKE2 cluster. `main` stays the source of truth for the EKS build; nothing here
needs AWS.

Two scripts replace `terraform-aws-k8s-ha`:

| Step | Script | Replaces (terraform-aws-k8s-ha) |
| --- | --- | --- |
| 1. Build the cluster | `rke2/install-cluster.sh` | VPC, EKS, node groups, Karpenter, Cilium, CSI add-ons |
| 2. Install the platform | `rke2/bootstrap-platform.sh` | `helm-addons.tf`, `argocd.tf`, `k8s-secrets.tf`, `scripts/post-apply-crds.sh` |

**Two profiles:** `full` (4 nodes, `rke2/cluster.env`) and `2node` (test subset,
`rke2/cluster-2node.env` + `big-data-platform/values-2node.yaml`). Which service runs on which
node: [`NODE-LAYOUT.md`](NODE-LAYOUT.md). Step-by-step for the 2-node test cluster: [`SETUP-2NODE.md`](SETUP-2NODE.md). SSH + passwordless sudo on the nodes: [`NODE-ACCESS.md`](NODE-ACCESS.md). Nodes on WiFi: `rke2/WIFI-SETUP.md`, a local file that's not in git because it holds the WiFi password.

After step 2, **Argo CD deploys everything from git**, as on `main`. To change the
platform, edit `big-data-platform/values.yaml`, push to `rke2`, and Argo CD syncs it.

---

## What changed vs. `main`

| Concern | `main` (EKS) | `rke2` |
| --- | --- | --- |
| Nodes | core/data tiers + Karpenter spark pool, arm64 | 4 identical x86_64 nodes (16 GB / 20 cores): `node-01..03` servers + platform, `node-04` agent **dedicated to StarRocks** |
| CNI | Cilium (ENI IPAM) + Hubble | **Canal** (RKE2 default: Flannel VXLAN + Calico NetworkPolicy) |
| Block storage | EBS gp3, EFS (RWX), OpenEBS hostpath | **OpenEBS local PV** behind one StorageClass, `local-storage`: hostpath or LVM CSI |
| Object storage | AWS S3 + IRSA/IMDS | **SeaweedFS** S3 in-cluster, static keys in the `lakehouse-s3` Secret |
| Exposure | Cloudflare tunnel → Traefik | **Traefik DaemonSet on hostPorts 80/443 (+1883 MQTT)**, `*.<node-ip>.sslip.io` |
| IIoT ingest | — | **Mosquitto → Telegraf → Kafka (Strimzi, KRaft) + VictoriaMetrics (7 d)** |
| Observability | Prometheus x2 + Thanos, Loki, Tempo, Alloy | **Prometheus x1, 7 d local** + Grafana; Alloy/Loki/Tempo/Thanos off (one flag each to restore) |
| Postgres | CNPG, 3 instances | CNPG, **1 instance** (raise `postgres.replicas` for HA) |
| Spark image | Spark + Comet, arm64 | stock Apache Spark 3.5.8 + Iceberg/Gravitino, amd64, **no Comet** |
| Removed / off | — | cloudflared, Headlamp, Superset (dependency dropped) + Redis, Hubble flow/packet-capture shippers, EKS control-plane RBAC, Karpenter/node-local-dns monitors, the separate metrics-server (RKE2 ships one). JupyterHub and Spark Connect: code kept, `enabled: false` — flip `<chart>.enabled` + `ingress.<chart>.enabled` to run them |

### Why these choices

- **Canal, not Cilium/Calico-standalone.** It is RKE2's default, so there's nothing to install
  or tune: plain kube-proxy (iptables), VXLAN overlay that works on any L2/L3 LAN, and it
  enforces standard `NetworkPolicy`. On 4 nodes, Cilium's eBPF features cost more operational
  complexity than they return.
- **3 servers + 1 agent.** etcd needs an odd member count; 3 tolerates losing one server.
  A 4th etcd member adds load without adding tolerance. RKE2 servers are schedulable, so all
  four nodes carry workloads.
- **OpenEBS local PV.** This is the CSI layer that replaces EBS. `hostpath` needs no disk prep.
  `lvm` gives real CSI volumes (`local.csi.openebs.io`) with enforced sizes, snapshots and
  expansion, if every node has a spare disk for a volume group. The platform only ever names
  `local-storage`, so the backend is a bootstrap-time choice.
- **No RWX needed.** `main` used EFS for Airflow DAGs and logs. Here DAGs come from the Airflow
  chart's own git-sync sidecar, task logs go to a per-StatefulSet RWO volume, and finished task
  logs go to SeaweedFS (remote logging).
- **SeaweedFS.** It's a light S3 server with replication. 3 masters (raft) + 3 volume servers
  with replication `001` (every chunk on 2 nodes) + 1 filer that hosts the S3 gateway.
- **sslip.io.** `grafana.192.168.1.11.sslip.io` resolves to `192.168.1.11` with no DNS server.
  Traefik runs on every node, so any node IP works.

---

## IIoT data path

```
DCS ──MQTT bridge──▶ Mosquitto ──▶ telegraf-kafka ──▶ Kafka topic dcs.raw (3 d) ──▶ Spark jobs (next)
   mqtt://<INGRESS_IP>:1883      └─▶ telegraf-vm ────▶ VictoriaMetrics (7 d)   ──▶ Grafana
```

- **Mosquitto**: users `dcs` (publishes `dcs/#`) and `telegraf` (read-only); passwords in the
  `mosquitto-credentials` Secret. Two ways to connect the DCS:
  - the DCS-side broker/gateway **bridges into** `mqtt://<INGRESS_IP>:1883` as `dcs`;
  - or this broker **dials out** to the DCS broker: `iiot.mosquitto.bridge.enabled: true` +
    address/topics, with the remote password in a Secret you create:
    `kubectl create secret generic mosquitto-bridge --from-literal=remote-password=...`.
  Messages queue per Telegraf session (QoS 1, persistent) while a consumer is down.
- **Telegraf**: two independent Deployments, so Kafka being down never delays the live
  VictoriaMetrics feed. The payload parser is `iiot.telegraf.parser`: the default is one number
  per topic, and the values.yaml comment shows a JSON (`json_v2`) example. Kafka message key is
  the MQTT topic, so each tag keeps its order within a partition.
- **Kafka**: Strimzi, KRaft, 3 brokers on node-01..03, RF 3 / min ISR 2, plaintext in-cluster
  listener `iiot-kafka-bootstrap.default.svc:9092`. Topic `dcs.raw`: 6 partitions, 3 days.
  The Spark image ships `spark-sql-kafka`, so a job reads it with
  `spark.readStream.format("kafka").option("kafka.bootstrap.servers", "iiot-kafka-bootstrap:9092").option("subscribe", "dcs.raw")`.
- **VictoriaMetrics**: `-retentionPeriod=7d`, Grafana datasource `VictoriaMetrics`
  (PromQL/MetricsQL, e.g. `dcs_value{topic="dcs/unit1/TI101"}`), UI at
  `victoriametrics.<domain>/vmui`.

## Node layout and resource plan

Each node: **16 GB RAM, 20 cores**. kubelet holds back **2 GiB + 1.5 cores** for the OS
(`system-reserved` 1 GiB/1 CPU, `kube-reserved` 768 MiB/0.5 CPU, hard eviction at 256 MiB free,
set in `cluster.env`). That leaves ~13.5 GiB / 18.5 cores allocatable per node.

| Node | Role | Runs |
| --- | --- | --- |
| node-01..03 | RKE2 server (etcd + control plane) + workloads | everything except StarRocks |
| node-04 | RKE2 agent, label `node-role.kubernetes.io/starrocks`, taint `dedicated=starrocks:NoSchedule` | StarRocks FE + BE (plus node DaemonSets) |

**Memory requests** (guaranteed share; limits allow bursting above it):

| Group | Requests | Limits | Where |
| --- | --- | --- | --- |
| RKE2 control plane + Canal/kube-proxy/CoreDNS | ~2.2 Gi per server | — | node-01..03 |
| Kafka (3 brokers x 1.5 Gi, heap 1 GiB) + Strimzi + topic operator | 5.0 Gi | 6.9 Gi | node-01..03, one broker each |
| Airflow (api-server, scheduler, dag-processor, triggerer, statsd) | 2.9 Gi | 6.1 Gi | node-01..03 |
| Postgres (CNPG, 1 instance) + operator | 1.1 Gi | 4.3 Gi | node-01..03 |
| Gravitino | 1.0 Gi | 2.5 Gi | node-01..03 |
| Spark History Server + Spark operator | 1.9 Gi | 2.8 Gi | node-01..03 |
| Prometheus (1 replica, 7 d) + operator + Grafana + KSM + Alertmanager + node-exporter | 2.1 Gi | 4.6 Gi | node-01..03 (+node-exporter on all 4) |
| SeaweedFS (3 masters, 3 volume servers, filer) | 1.4 Gi | 9.5 Gi | node-01..03 |
| IIoT: Mosquitto, 2x Telegraf, VictoriaMetrics | 0.8 Gi | 3.3 Gi | node-01..03 |
| Argo CD, Traefik (x3), OpenEBS, cert-manager, StarRocks operator | 1.8 Gi | 5 Gi | node-01..03 |
| **Total on node-01..03** | **~18 Gi + 6.6 Gi control plane** | | of ~40.5 Gi allocatable |
| **Left for Spark jobs** | **~15 Gi** | | e.g. driver 2 GiB + 4 executors x 3 GiB |
| StarRocks FE (heap 3 GiB) / BE (`mem_limit` 7G) | 3 Gi / 7 Gi | 4 Gi / 8.5 Gi | node-04 (~3 Gi spare) |

CPU is not the constraint: the platform requests ~7 cores of ~55 on node-01..03, and StarRocks
requests 10 of 18.5 on node-04 (limits let BE burst to 16).

Rules of thumb on this cluster:
- Keep requests close to real usage and limits for bursts. The scheduler only guarantees
  requests, and the kubelet reserve protects the OS.
- Spark jobs: size `spark.executor.memory` + overhead to fit the ~15 GiB left. The StarRocks
  node stays out of reach because of its taint.
- To see real usage: `kubectl top nodes` / `kubectl top pods -A` (RKE2's metrics-server).

## Best practice notes (RKE2)

What this layout already does:
- 3 etcd servers (odd quorum) and workers as agents.
- Declarative `/etc/rancher/rke2/config.yaml`.
- Joins use the cluster's own node-token, and servers join one at a time.
- kubelet resource reserves and graceful node shutdown.
- RKE2's default CNI.
- Control-plane metrics exposed for Prometheus.
- The workload node is tainted for its one tenant.

What's still worth adding as the cluster becomes important:
1. **Pin the RKE2 version** (`RKE2_VERSION` in cluster.env) instead of a channel, so a node
   added later matches; upgrade deliberately (system-upgrade-controller, or re-run with a new pin).
2. **A fixed registration address**. Joins and the kubeconfig point at node-01. If node-01 is
   down, the cluster keeps running, but new nodes can't join and kubectl needs another
   server's IP. Fix it with a VIP (kube-vip) or a DNS name over the 3 servers, added to `tls-san`.
3. **Off-node etcd snapshots**: RKE2 snapshots every 12 h locally. Copy
   `/var/lib/rancher/rke2/server/db/snapshots` off the nodes, or set `etcd-s3-*` to an
   S3 target outside this cluster.
4. **CIS hardening** (`profile: cis`) if the plant network requires it. It needs extra
   PodSecurity/NetworkPolicy work for this platform.

## Prerequisites

- **4 x86_64 Linux nodes** (Ubuntu 22.04/24.04, Debian 12, RHEL/Rocky 9, SLES 15) on one LAN,
  static IPs, unique hostnames, NTP synced. Suggested minimum: 8 vCPU / 32 GB RAM / 200 GB
  disk each.
- SSH from this machine to every node with key auth, as a user with **passwordless sudo**.
- Internet egress from the nodes (images, `get.rke2.io`, GitHub for Argo CD).
- On this machine: `kubectl`, `helm` ≥ 3.12, `jq`, `openssl`, `ssh`/`scp`.
- The Spark image `subhodeep2022/spark-bigdata:spark-3.5.8-v14-iceberg-gravitino-kafka-oss` built and
  pushed (`docker/spark/build.sh`, or CI on push to `rke2`).

### Ports between nodes

`prep-node.sh` disables firewalld/ufw by default (`NODE_FIREWALL=disable`, as RKE2 recommends with
Canal). If you keep a firewall, open:

| Port | Proto | Purpose |
| --- | --- | --- |
| 6443 | TCP | Kubernetes API (also from your workstation) |
| 9345 | TCP | RKE2 supervisor (node join) |
| 2379-2381 | TCP | etcd client/peer/metrics (servers) |
| 10250 | TCP | kubelet |
| 10257, 10259, 10249 | TCP | controller-manager, scheduler, kube-proxy metrics |
| 8472 | UDP | Canal/Flannel VXLAN |
| 9099 | TCP | Canal health |
| 9100 | TCP | node-exporter |
| 80, 443 | TCP | Traefik (also from your clients) |
| 1883 | TCP | MQTT via Traefik (from the DCS network) |
| 30000-32767 | TCP | NodePorts (StarRocks query port 30930, from SQL clients) |

---

## Install

```bash
# 0. configure
cp rke2/cluster.env.example rke2/cluster.env
$EDITOR rke2/cluster.env        # node names/IPs, SSH, INGRESS_IP, STORAGE_BACKEND

# 1. cluster (≈10-15 min): preps nodes, installs RKE2, writes rke2/kubeconfig
rke2/install-cluster.sh
export KUBECONFIG=$PWD/rke2/kubeconfig
kubectl get nodes -o wide

# 2. platform (≈20-40 min, mostly image pulls)
rke2/bootstrap-platform.sh
```

`bootstrap-platform.sh` prints every URL and the command to read each password. Both scripts
are idempotent, so re-run them after any failure or config change.

### What bootstrap-platform.sh does, in order

1. **OpenEBS** (helm) and StorageClass **`local-storage`** (default). OpenEBS is installed with
   Helm rather than Argo CD because its pre-upgrade hook deletes its own provisioner and Argo CD
   would run that hook on every sync.
2. **Traefik** (helm) as a DaemonSet with hostPorts 80/443. RKE2's ingress-nginx is disabled in
   `install-rke2.sh`.
3. **Argo CD** (helm, chart 7.8.23, same config as `main`'s `argocd.tf`: CNPG health checks,
   CRD exclusion, git timeouts).
4. **Secrets**, generated once and never rotated on re-run. This is the only place credentials
   exist: `postgres-superuser`, `{airflow,superset,gravitino}-db-role`,
   `airflow-credentials`, `airflow-api-secrets`, `superset-credentials`, `grafana-credentials`, `lakehouse-s3`
   (default + kube-system), `airflow-s3-connection`, `mosquitto-credentials`,
   `storage/seaweedfs-s3-config`.
5. **AppProject + SeaweedFS Application**, then waits for Healthy.
6. **Buckets** `lakehouse` and `loki`, plus the `spark-events/` marker (Job).
7. **CRDs** via `scripts/apply-crds.sh`: Spark Operator, CNPG (+ webhook configs),
   cert-manager, StarRocks, Prometheus Operator, Strimzi (Kafka), plus the prometheus-operator admission Secret.
8. **big-data-platform Application** (`GIT_REPO`@`GIT_REVISION`) with two Helm parameters:
   `global.domain` and Gravitino's entity-store JDBC password. The Gravitino chart can only
   render that password into a ConfigMap. Every other credential is read from Secrets at runtime.

### S3 credentials

Every S3 client reads the `lakehouse-s3` Secret, whose keys are the AWS SDK's standard env names:
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ENDPOINT_URL`, `S3_ENDPOINT`,
`bucket`. A pod with `envFrom: [{secretRef: {name: lakehouse-s3}}]` therefore works unchanged
with aws-cli, boto3, Hadoop S3A, Loki, Thanos and Tempo. Endpoint:
`http://seaweedfs-filer.storage.svc.cluster.local:8333` (path-style, plain HTTP).

---

## URLs

With `INGRESS_IP=192.168.1.11`:

| Service | URL |
| --- | --- |
| Argo CD | http://argocd.192.168.1.11.sslip.io |
| Airflow | http://airflow.192.168.1.11.sslip.io |
| Grafana | http://grafana.192.168.1.11.sslip.io |
| Prometheus | http://prometheus.192.168.1.11.sslip.io |
| Spark History | http://spark-history.192.168.1.11.sslip.io |
| Gravitino | http://gravitino.192.168.1.11.sslip.io |
| Traefik dashboard | http://traefik.192.168.1.11.sslip.io/dashboard/ |
| VictoriaMetrics UI | http://victoriametrics.192.168.1.11.sslip.io/vmui |
| StarRocks FE UI | http://starrocks.192.168.1.11.sslip.io (SQL: `mysql -h 192.168.1.11 -P 30930 -uroot`) |
| MQTT (DCS) | `mqtt://192.168.1.11:1883`, user `dcs` |

No Headlamp. Point Lens, k9s or Freelens at `rke2/kubeconfig` instead.

## Smoke test

```bash
kubectl apply -f examples/spark-jobs/rke2-iceberg-smoke-test.yaml
kubectl get sparkapplication rke2-iceberg-smoke-test -w
kubectl logs rke2-iceberg-smoke-test-driver | grep SMOKE     # 4 regions + "SMOKE OK"
```

It runs Spark Operator → Gravitino → Iceberg on SeaweedFS end to end, and the run then
appears in Spark History.

---

## Operations

**Node loss.** Volumes are node-local:

- **SeaweedFS** keeps serving: objects have 2 copies, and 2 of 3 masters keep quorum. The
  filer is a single replica, so the S3 endpoint is down until its node returns.
- **Prometheus**: the second replica keeps scraping, and history older than 2h is in
  SeaweedFS via Thanos.
- **Postgres** (single instance) is down until its node returns. Airflow and Gravitino
  depend on it.
- **Node gone for good:** delete the dead node's PVCs (`kubectl get pvc -A -o wide`) so their
  pods reschedule with fresh volumes, then restore Postgres from backup.

**Backups** (none are automated yet):
- Postgres: `kubectl exec postgres-1 -- pg_dumpall -U postgres > backup.sql`. For scheduled
  backups, CNPG's `ScheduledBackup` can write to SeaweedFS using the `lakehouse-s3` keys
  (barman-cloud).
- etcd: RKE2 snapshots every 12 h to `/var/lib/rancher/rke2/server/db/snapshots` on each
  server; take one on demand with `rke2 etcd-snapshot save`.

**Postgres HA later:** set `postgres.replicas: 3` and push. CNPG adds streaming replicas and
failover.

**Storage backend:** choose before the first bootstrap. The StorageClass is immutable, and
the script refuses to switch while it exists.

**NetworkPolicy:** off by default. To enable the `default` namespace boundary, set
`networking-extras.networkPolicy.enabled: true` and `nodeCIDRs: ["<LAN subnet>"]`. It must
admit node IPs, because the API server reaches webhooks from the host network.

**Teardown:** `rke2/uninstall.sh platform` (Argo CD apps and their data) or
`rke2/uninstall.sh cluster` (wipes RKE2 from every node). Both ask for confirmation.

---

## Known gaps / follow-ups

- **Single points**: Mosquitto, VictoriaMetrics, the SeaweedFS filer and Postgres are one
  replica each on node-local storage. If a node dies, they stay down until it returns.
  Kafka (3 brokers) keeps buffering, and Telegraf/Mosquitto queue while they're down.
- **Kafka has no auth/TLS.** The listener is cluster-internal only. Add a SCRAM listener +
  KafkaUser if anything outside the cluster ever needs access.
- **No log aggregation** (Alloy/Loki off by your choice): use `kubectl logs`. Re-enable with the
  flags noted in values.yaml.
- **StarRocks node loss** = StarRocks down (1 FE, 1 BE, local volumes). It's a query/serving
  layer; the source data stays in the lakehouse/Kafka.

- **Gravitino Web UI S3 browsing:** `main`'s open issue still applies. The `lakehouse-iceberg`
  catalog classloader lacks the AWS SDK bundle (`NoClassDefFoundError: .../S3Exception`).
  Spark and the Iceberg REST endpoint are unaffected. Fix: an init container copying
  `iceberg-rest-server/libs/gravitino-iceberg-aws-bundle-*.jar` into
  `catalogs/lakehouse-iceberg/libs/`.
- **Benchmark jobs:** `examples/spark-jobs/tpch-*` and `tpcds-*` are `main`'s EKS manifests
  (AWS buckets, Karpenter instance families, Comet) and are not runnable here.
- **TLS:** HTTP only. Traefik serves its default self-signed cert on :443. sslip.io names work
  with cert-manager HTTP-01 only if the IP is publicly reachable.
