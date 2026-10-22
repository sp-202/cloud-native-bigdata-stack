# Node layout — which service runs where

Two cluster shapes from the same branch, chosen by `PLATFORM_PROFILE` in the cluster env file:

| Profile | Env file | Values | Nodes |
| --- | --- | --- | --- |
| `full` | `rke2/cluster.env` | `values.yaml` | node-01..04 |
| `2node` (test) | `rke2/cluster-2node.env` | `values.yaml` + `values-2node.yaml` | node-01, node-02 |

Every node: 16 GB RAM / 20 cores, with 2 GiB + 1.5 cores held back for the OS (kubelet
reserves), leaving ~13.5 GiB / 18.5 cores for pods.

## How placement is decided

Placement works in three tiers:

1. **Fixed:**
   - The control plane runs on the RKE2 servers.
   - DaemonSets run on every node they tolerate.
   - StarRocks is pinned to its dedicated node by label + taint.
2. **Spread by rule:** pods with *required* anti-affinity run one per node (Kafka brokers,
   SeaweedFS masters and volume servers).
3. **Scheduler's choice:** everything else lands on whichever allowed node has the most free
   requested capacity. The tables below say **"any"** for these. There's deliberately no
   pinning: on identical nodes it adds nothing, and it would stop pods moving off a failed node.

**Pods with a volume stay where they first land.** `local-storage` volumes live on one node's
disk, so once Postgres, Prometheus, Airflow scheduler/triggerer, Mosquitto, VictoriaMetrics,
SeaweedFS and Kafka are scheduled, they always return to that same node. Stateless pods
(Airflow api-server, Gravitino, Grafana, operators) can move anywhere.

To see the live picture:
```bash
kubectl get pods -A -o wide --sort-by=.spec.nodeName      # pod -> node
kubectl get pvc -A -o wide                                # which pods are tied to a node
kubectl top nodes; kubectl describe node node-01 | sed -n '/Allocated resources/,/Events/p'
```

---

## Profile `full` — 4 nodes

| | node-01 | node-02 | node-03 | node-04 |
| --- | --- | --- | --- | --- |
| RKE2 role | server | server | server | agent |
| Label / taint | — | — | — | `node-role.kubernetes.io/starrocks` / `dedicated=starrocks:NoSchedule` |
| **Fixed** | etcd, kube-apiserver, controller-manager, scheduler | same | same | — |
| **DaemonSets** | Canal, kube-proxy, Traefik (:80/:443/:1883), node-exporter | same | same | Canal, kube-proxy, node-exporter (no Traefik) |
| **One per node** | Kafka broker, SeaweedFS master, SeaweedFS volume | same | same | — |
| **Dedicated** | — | — | — | StarRocks FE (3 Gi) + BE (7 Gi) |
| **Any of node-01..03** | see list below | | | — |

Scheduler-placed on node-01..03 (**any**):

| Area | Pods |
| --- | --- |
| GitOps / infra | Argo CD (server, repo-server, controller, redis, applicationset), cert-manager x3, OpenEBS localpv provisioner, CoreDNS, metrics-server |
| Data platform | Postgres (CNPG) + CNPG operator, Gravitino (+ init jobs), Airflow api-server / scheduler / dag-processor / triggerer / statsd, Spark operator controller + webhook, Spark History Server, StarRocks operator, SeaweedFS filer (S3 endpoint) |
| IIoT | Mosquitto, telegraf-kafka, telegraf-vm, VictoriaMetrics, Strimzi operator, Kafka topic operator |
| Monitoring | Prometheus, Prometheus operator, Grafana, kube-state-metrics, Alertmanager |
| Spark jobs | drivers + executors (the taint keeps them off node-04) |

Memory (requests): about **2.2 GiB control plane + ~6 GiB platform per server** (≈18 GiB spread
over three), which leaves **~15 GiB across node-01..03 for Spark jobs**. node-04: ~10 GiB
StarRocks + ~0.3 GiB DaemonSets of ~13.5 GiB.

Off in this profile: Alloy, Loki, Tempo, Thanos, Redis, Superset, JupyterHub, Spark Connect.

---

## Profile `2node` — test

| | node-01 | node-02 |
| --- | --- | --- |
| RKE2 role | server (single etcd) | agent |
| **Fixed** | etcd, kube-apiserver, controller-manager, scheduler | — |
| **DaemonSets** | Canal, kube-proxy, Traefik (:80/:443), node-exporter | same |
| **One per node** | SeaweedFS volume | SeaweedFS volume |
| **Any of the two** | see list below | |

Why 1 server + 1 agent and not 2 servers: a 2-member etcd needs *both* members for quorum, so
either node failing would freeze the cluster. One server is simpler and no less available.

Scheduler-placed on node-01 or node-02 (**any**). node-01 already carries ~2.2 GiB of control
plane, so the scheduler tends to put more of these on node-02:

| Area | Pods | Memory request |
| --- | --- | --- |
| GitOps / infra | Argo CD, cert-manager x3, OpenEBS provisioner, CoreDNS, metrics-server | ~1.5 GiB |
| Storage | SeaweedFS master (x1) + filer | ~0.4 GiB (+ 2 x 0.25 volumes above) |
| Database | Postgres (CNPG, 1 instance) + CNPG operator | ~1.1 GiB |
| Gravitino | Gravitino (+ schema/init jobs) | 1.0 GiB |
| Airflow | api-server, scheduler (+ git-sync), dag-processor, triggerer, statsd | ~2.8 GiB |
| Monitoring | Prometheus, operator, Grafana, kube-state-metrics, Alertmanager | ~2.0 GiB |
| Spark | Spark operator controller + webhook (no SparkApplications submitted) | ~0.4 GiB |
| **Total** | | **~9.8 GiB** of ~24.5 GiB free after the control plane |

Off in this profile (`big-data-platform/values-2node.yaml`): StarRocks, IIoT (Mosquitto,
Telegraf, Kafka, VictoriaMetrics), Strimzi, Spark History Server — plus everything already off
in the full profile (Alloy, Loki, Tempo, Thanos, Redis, Superset, JupyterHub, Spark Connect).

URLs: `airflow.`, `gravitino.`, `grafana.`, `prometheus.`, `argocd.`, `traefik.` +
`<INGRESS_IP>.sslip.io`.

To try one more service on the test cluster, flip its flag in `values-2node.yaml`, for example
`spark-history-server.enabled: true` together with `ingress.spark-history-server.enabled: true`.
Then push.
