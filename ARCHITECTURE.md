# Platform Architecture

> Current state of `big-data-platform/` (the ArgoCD-managed umbrella chart). The AWS side
> (VPC, EKS, node groups, Karpenter, Cilium, IAM/IRSA, S3 buckets, EFS) lives in the
> separate Terraform repo **`terraform-aws-k8s-ha`** and is referenced by file name below.
> The cluster is **ephemeral**: it's built for a Spark benchmark run and torn down shortly
> after, so anything that has to outlive the cluster is written to S3.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    EXTERNAL WORLD                                           │
│                         Browser / API Client / BI Tool                                      │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │  HTTPS (443)  *.dailyblogstudio.com
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                              CLOUDFLARE EDGE (Zero-Trust Tunnel)                            │
│                    No inbound firewall ports — outbound-only tunnel                         │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │  encrypted tunnel
                                       ▼
╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║            AWS EKS  (ap-south-1)  —  ARM64 Graviton  |  Cilium CNI (ENI IPAM, no kube-proxy) ║
║                                                                                              ║
║   Node tiers (node-role.kubernetes.io/<role>):                                               ║
║     core-node   always-on  ArgoCD, Traefik, CoreDNS, cert-manager, cloudflared, Loki,        ║
║                            Spark Operator, Karpenter controller, metrics-server, Headlamp    ║
║     data-node   always-on  Postgres (CNPG), Airflow, Gravitino, Redis, Prometheus, Grafana,  ║
║                 (x2)       Thanos, Spark History Server                                      ║
║     spark-node  Karpenter  r7gd / m7gd / c7gd, spot + on-demand, NVMe at /mnt/spark-nvme,    ║
║                 NodePool   taint spark-only=true:NoSchedule, removed ~180 s after last pod   ║
║                                                                                              ║
║  ns: cloudflare                                                                              ║
║  ┌────────────────────────────────────────────┐                                              ║
║  │  cloudflared  (3 replicas, HA)             │  topology spread + PodDisruptionBudget       ║
║  └──────────────────────┬─────────────────────┘                                              ║
║                         │ routes to Traefik ClusterIP                                        ║
║                         ▼                                                                    ║
║  ┌─────────────────────────────────────────────────────────────────┐                         ║
║  │  Traefik  (ClusterIP — no LoadBalancer)                         │                         ║
║  │  Ingress  centralized-ingress   (charts/ingress)                │                         ║
║  │    airflow.  grafana.  prometheus.  spark-history.  gravitino.  │                         ║
║  │    superset. / jupyterhub. / spark.   (only when enabled)       │                         ║
║  │  IngressRoutes (charts/networking-extras):                      │                         ║
║  │    argocd.  traefik.  hubble.        + headlamp. (charts/headlamp)                        ║
║  └──────────────────────────────┬──────────────────────────────────┘                         ║
║                                 │                                                            ║
║          ┌──────────────────────┼────────────────────────────────┐                           ║
║          ▼                      ▼                                ▼                           ║
║  ┌───────────────┐   ┌──────────────────────┐   ┌───────────────────────────────┐            ║
║  │ ORCHESTRATION │   │  COMPUTE (ns:default)│   │  METADATA & CATALOG           │            ║
║  │ (ns: default) │   │                      │   │  (ns: default)                │            ║
║  │               │   │  ┌────────────────┐  │   │  ┌─────────────────────────┐  │            ║
║  │  ┌──────────┐ │   │  │ Spark Operator │  │   │  │ Apache Gravitino 1.3.0  │  │            ║
║  │  │ Airflow  │ │   │  │ 2.4.0          │  │   │  │ (chart gravitino-helm   │  │            ║
║  │  │ 3.2.0    │─┼───►  │ SparkApp CRDs  │  │   │  │  1.3.11)                │  │            ║
║  │  │ Local    │ │   │  └───────┬────────┘  │   │  │                         │  │            ║
║  │  │ Executor │ │   │          │ spawns    │   │  │ :8090 API + Web UI      │  │            ║
║  │  │ + dag-   │ │   │          ▼           │   │  │ :9001 Iceberg REST      │  │            ║
║  │  │ processor│ │   │  ┌────────────────┐  │   │  │   (dynamic-config-      │  │            ║
║  │  └──────────┘ │   │  │ Driver +       │  │   │  │    provider → :8090)    │  │            ║
║  │               │   │  │ Executor pods  │  │   │  │                         │  │            ║
║  │  ┌──────────┐ │   │  │ on spark-node  │  │   │  │ metalake:               │  │            ║
║  │  │ git-sync │ │   │  │ (Karpenter)    │  │   │  │  enterprise_metalake    │  │            ║
║  │  │ + s3-sync│ │   │  │ Comet native   │  │   │  │ catalogs:               │  │            ║
║  │  │ sidecar  │ │   │  │ IRSA → S3      │  │   │  │  sales_catalog          │  │            ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  │  raw_catalog            │  │            ║
║  │               │   │                      │   │  │ S3FileIO, JDBC backend  │  │            ║
║  │               │   │  ┌────────────────┐  │   │  └─────────────────────────┘  │            ║
║  │               │   │  │ Spark History  │  │   │                               │            ║
║  │               │   │  │ Server (reads  │  │   │                               │            ║
║  │               │   │  │ S3 event logs) │  │   │                               │            ║
║  │               │   │  └────────────────┘  │   │                               │            ║
║  └───────────────┘   └──────────────────────┘   └───────────────────────────────┘            ║
║                                                                                              ║
║  ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐  ║
║  ┆ DISABLED FOR BENCHMARK RUNS  (enabled: false, not needed for TPC-H)                    ┆  ║
║  ┆ Charts, values and ingress rules are kept; flip enabled: true (and the matching        ┆  ║
║  ┆ ingress.<name>.enabled flag) to bring them back.                                       ┆  ║
║  ┆                                                                                        ┆  ║
║  ┆ ┌────────────────────┐   sc://…:15002   ┌──────────────────────┐                       ┆  ║
║  ┆ │ JupyterHub         │ ───────────────► │ Spark Connect Server │ ──► executors         ┆  ║
║  ┆ │ PySpark/Scala/SQL  │                  │ shared gateway,      │     on spark-node     ┆  ║
║  ┆ │ jupyterhub.<domain>│                  │ dyn. alloc 2-8 execs │                       ┆  ║
║  ┆ └────────────────────┘                  │ spark.<domain> (UI)  │                       ┆  ║
║  ┆                                         └──────────────────────┘                       ┆  ║
║  ┆ ┌────────────────────┐   SQL (MySQL     ┌──────────────────────┐   Iceberg REST        ┆  ║
║  ┆ │ Superset 3.1.0     │   protocol)      │ StarRocks 3.3 FE/BE  │   :9001               ┆  ║
║  ┆ │ BI / dashboards    │ ───────────────► │ OLAP on Iceberg      │ ──► Gravitino         ┆  ║
║  ┆ │ Redis cache,       │                  │ FE query NodePort    │                       ┆  ║
║  ┆ │ Postgres superset  │                  │ 30930                │                       ┆  ║
║  ┆ └────────────────────┘                  └──────────────────────┘                       ┆  ║
║  └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘  ║
║                                                                                              ║
║  ┌───────────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  OBSERVABILITY                                                                        │   ║
║  │                                                                                       │   ║
║  │  every node ─ Grafana Alloy DaemonSet (ns: kube-system, hostNetwork,                  │   ║
║  │               system-node-critical)                                                   │   ║
║  │    pod logs · journal · Spark GC/diag files · Hubble flows ──────────►  Loki 2.9.3    │   ║
║  │    node-exporter · cilium-agent · Hubble metrics · Comet OTLP ──────►  Prometheus x2  │   ║
║  │                                                  (remote-write to both replicas)      │   ║
║  │                                                                                       │   ║
║  │  Prometheus x2 (HA, hard anti-affinity) ── Thanos sidecar ──► S3  thanos/             │   ║
║  │      + tsdb-head-backup container (head snapshot to S3 every 15 min)                  │   ║
║  │  Thanos Query ◄── Store Gateway ◄── S3        Compactor (30d raw/90d 5m/365d 1h)      │   ║
║  │  Loki ──────────────────────────────────────► S3  loki-logs bucket                    │   ║
║  │  Grafana ── datasources: Prometheus, Thanos, Loki; provisioned dashboards             │   ║
║  │                                                                                       │   ║
║  │  S3 archivers (charts/monitoring):  hubble-flow-shipper · packet-capture-shipper ·    │   ║
║  │                                     spark-node-log-shipper · k8s-event-exporter       │   ║
║  │  EKS control-plane metrics scraped via metrics.eks.amazonaws.com                      │   ║
║  └───────────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                              ║
║  ┌───────────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  DATA & PERSISTENCE                                                                   │   ║
║  │                                                                                       │   ║
║  │  ┌──────────────────────────┐   ┌────────────────────────┐   ┌──────────────────┐     │   ║
║  │  │   PostgreSQL 16 (CNPG)   │   │  Redis 7.2             │   │  Storage classes │     │   ║
║  │  │   3 instances, ebs-gp3   │   │  (Superset cache)      │   │  ebs-gp3   (EBS) │     │   ║
║  │  │   svc: postgres-rw       │   └────────────────────────┘   │  openebs-hostpath│     │   ║
║  │  │   DBs:                   │                                │  efs-airflow-dags│     │   ║
║  │  │   ├── airflow            │                                │   (EFS, RWX)     │     │   ║
║  │  │   ├── superset           │                                └──────────────────┘     │   ║
║  │  │   ├── gravitino          │                                                         │   ║
║  │  │   └── iceberg_catalog    │                                                         │   ║
║  │  └──────────────────────────┘                                                         │   ║
║  └───────────────────────────────────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝
                                       │
                                       │  S3 (virtual-hosted, TLS) — IAM node role / IRSA,
                                       │  no static keys anywhere
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  AMAZON S3  (ap-south-1)                                                                    │
│                                                                                             │
│  k8s-ha-cluster-lakehouse-ap-south-1-<acct>     Iceberg warehouse, dags/, spark-events/,    │
│                                                 thanos/, network-logs/, spark-node-logs/    │
│  k8s-ha-cluster-loki-logs-ap-south-1-<acct>     Loki chunks + TSDB index (own bucket)       │
│  tpch-sf100-<acct>, tpc-<acct>                  TPC-H data, results, benchmark event logs   │
└─────────────────────────────────────────────────────────────────────────────────────────────┘


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — SparkApplication (TPC-H / ad-hoc) on Karpenter nodes

  kubectl apply -f examples/spark-jobs/tpch-*.yaml   (or an Airflow task)
      │
      ▼
  Spark Operator (core-node)  ──spawns──►  Driver pod
                                              │  Karpenter provisions spark-node capacity
                                              │  (instance family/size/capacity-type pinned per job)
                                    ┌─────────┴──────────┐
                                    ▼                    ▼
                              Executor Pod-1   …   Executor Pod-N
                              Comet native exec + CometShuffleManager,
                              shuffle on local NVMe (/mnt/spark-nvme)
                                    │                    │
                                    └─────────┬──────────┘
                                              │  s3a:// (JVM)  +  Comet's Rust S3 reader
                                              │  credentials: IRSA (spark-operator-spark SA →
                                              │  role k8s-ha-cluster-spark-s3)
                                              ▼
                                    Amazon S3 (parquet / Iceberg tables)
                                              │
                         event logs ──────────┼──────────► Spark History Server
                         Comet OTLP ──► Alloy (same node) ──► Prometheus
                         stdout, GC, diag ──► Alloy ──► Loki   (+ raw copy to S3)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — Spark reading/writing Iceberg through Gravitino

  Spark session (spark-defaults.conf baked into the Spark image)
      │  spark.plugins = GravitinoSparkPlugin
      │  spark.sql.gravitino.uri = http://gravitino.default.svc.cluster.local:8090
      ▼
  Gravitino :8090  ──resolves──►  enterprise_metalake.sales_catalog  (lakehouse-iceberg)
      │
      ├─ table metadata ───►  PostgreSQL  iceberg_catalog  (JDBC catalog backend)
      └─ data files ───────►  S3 lakehouse bucket  (S3FileIO, IAM role auth)

  Iceberg REST clients (e.g. StarRocks when enabled) hit :9001, which delegates catalog
  lookup back to :8090 (dynamic-config-provider), so everything shares one catalog.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — Airflow DAGs

  github.com/sp-202/airflow-dags (main)
      │  git pull every 60s
      ▼
  airflow-git-sync pod ──writes──► airflow-dags-shared-pvc (EFS, RWX)  ──► dag-processor
      │                                                                    scheduler
      └─ s3-sync sidecar ──► s3://<lakehouse>/dags                         api-server
                                                                              │
                                                     LocalExecutor task ──────┘
                                                              │ submits SparkApplication
                                                              ▼
                                                     Spark Operator → Driver → Executors → S3


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

# 📂 Helm Umbrella Chart

Everything is deployed by one ArgoCD Application from the umbrella chart in
`big-data-platform/`, configured by a single [values.yaml](big-data-platform/values.yaml).
Secrets are never in git: `post-cluster-bootstrap.sh` (Terraform repo) pre-creates the
`*-credentials` / `postgres-superuser` Secrets and injects deploy-time values (Gravitino
JDBC password, Iceberg warehouse path) as ArgoCD `helm.parameters`.

## 🌊 Sync Waves (ArgoCD)

| Wave | Resources |
| :--- | :--- |
| **-10** | Spark Operator CRDs (`templates/crds/`) |
| **-3** | Namespaces, persistence PV/PVCs, CloudNativePG operator, cloudflared namespace |
| **-2** | Postgres `Cluster` CR (CNPG), Redis |
| **-1** | CNPG `Database` CRs (airflow, superset, gravitino, iceberg_catalog), `airflow-db-migrate`, `gravitino-schema-init` |
| **0** | Apps: Gravitino + `gravitino-init` (creates metalake/catalog), Airflow, Spark History Server, monitoring, Thanos, ingress, cloudflared, Headlamp, network policies |
| **3** | `airflow-git-sync` |

## 🧩 Dependencies

**Upstream charts** (from [Chart.yaml](big-data-platform/Chart.yaml))

| Chart | Version | Enabled | Role |
| :--- | :--- | :---: | :--- |
| cloudnative-pg | 0.29.0 | ✅ | Postgres operator (2 replicas for webhook HA) |
| cert-manager | v1.16.2 | ✅ | CA for the Prometheus Operator admission webhook |
| spark-operator | 2.4.0 | ✅ | `SparkApplication` controller; creates the IRSA-annotated `spark-operator-spark` SA |
| airflow | 1.21.0 | ✅ | Airflow 3.2.0, LocalExecutor, FAB auth manager |
| gravitino-helm (alias `gravitino`) | 1.3.11 | ✅ | Metadata lake + Iceberg REST |
| kube-prometheus-stack | 56.6.2 | ✅ | Prometheus (x2), Alertmanager, Grafana, node-exporter, kube-state-metrics |
| loki-stack | 2.10.2 | ✅ | Loki only (promtail disabled, replaced by Alloy) |
| alloy | 1.13.0 | ✅ | Node agent for logs and pushed metrics |
| metrics-server | 3.12.1 | ✅ | Resource metrics (Headlamp, `kubectl top`) |
| superset | 0.12.0 | ❌ | BI |
| kube-starrocks (alias `starrocks`) | 1.9.8 | ❌ | OLAP over Iceberg REST |

**Local sub-charts** (`big-data-platform/charts/`)

| Chart | Enabled | Purpose |
| :--- | :---: | :--- |
| postgres | ✅ | CNPG `Cluster` + `Database` CRs |
| redis | ✅ | Superset cache |
| persistence | ✅ | Static PVs (StarRocks, Redis) and the EFS DAGs PVC |
| airflow-git-sync | ✅ | DAG repo → EFS PVC, mirrored to S3 |
| spark-history-server | ✅ | Spark UI for finished apps, reads event logs from S3 |
| monitoring | ✅ | Alloy config, dashboards, ServiceMonitors, S3 shippers, event exporter, EKS control-plane RBAC |
| thanos | ✅ | Query, Store Gateway, Compactor (S3 long-term metrics) |
| ingress | ✅ | Central Traefik `Ingress` |
| networking-extras | ✅ | Cilium/K8s network policies, IngressRoutes for ArgoCD/Traefik/Hubble |
| cloudflared | ✅ | Cloudflare tunnel (3 replicas) |
| headlamp | ✅ | Kubernetes web UI |
| spark-connect-server | ❌ | Shared Spark Connect gateway (`sc://…:15002`) |
| jupyterhub | ❌ | Notebooks via Spark Connect |

## ⏸️ Disabled for Benchmark Runs

The cluster is currently used for TPC-H benchmarking. Those runs only need the Spark
Operator, S3, Gravitino and the observability stack. The interactive and BI layers aren't
used, so they're set to `enabled: false` to save node capacity and keep each fresh deploy
fast and quiet. They haven't been removed: the charts, values and ingress rules are all
still in the repo.

| Component | What it does when enabled | Why it's off for benchmarks |
| :--- | :--- | :--- |
| **StarRocks** (kube-starrocks 1.9.8, FE/BE 3.3) | OLAP engine that queries Iceberg tables through Gravitino's Iceberg REST endpoint (:9001); FE query port on NodePort 30930 | Benchmarks run Spark SQL, not StarRocks queries |
| **Superset** (3.1.0) | BI dashboards over StarRocks/Postgres; uses Redis for cache and the `superset` Postgres DB | No BI use during a benchmark |
| **JupyterHub** | Notebooks (PySpark / Scala / SQL) that connect to Spark Connect at `sc://spark-connect-server-driver-svc:15002` | Jobs are submitted as `SparkApplication`s, not from notebooks |
| **Spark Connect Server** | Shared, always-on Spark gateway with dynamic allocation (2-8 executors) and a Spark UI at `spark.<domain>` | Would hold spark-node capacity that the benchmark executors need |

**Re-enabling one:** set `<component>.enabled: true` in
[values.yaml](big-data-platform/values.yaml). Also set the matching flag under
`ingress:` (`ingress.superset.enabled`, `ingress.jupyterhub.enabled`,
`ingress.spark-connect-server.enabled`), because the ingress chart can't read sibling
charts' flags. For StarRocks, keep `starrocks.*.nodeSelector` and
`persistence.starrocksFe/Be.nodeSelector` pointing at the same node, or the PVCs won't
bind. Redis and the `superset` database stay deployed, so Superset needs nothing else.

---

# 🌐 Networking

- **EKS + Cilium in AWS ENI IPAM mode** with kube-proxy replacement: every pod gets a
  native VPC IP. Pod IPs come from secondary ENIs only (`firstInterfaceIndex=1`), so pod
  traffic rides `ens6`. node-exporter collects ethtool counters on `ens5|ens6` to spot ENA
  bandwidth/pps allowance exhaustion during Spark runs.
- **Hubble** flow export is on; flows go to Loki (via Alloy) and are archived to S3.
- **Cloudflare Tunnel → Traefik** (ClusterIP) is the only way in. No inbound 80/443 on
  any node.
- **Network policies** (`networking-extras`) default-deny the `default` namespace, then
  allow the API server (webhooks) and node agents back in.

---

# 🔐 S3 Access (MinIO removed)

MinIO is gone. Everything uses **Amazon S3** directly (`global.s3`: virtual-hosted style,
TLS), and no workload holds static keys:

| Consumer | Credentials | Scope |
| :--- | :--- | :--- |
| Gravitino, Airflow, History Server, shippers | Node instance-profile role (IMDS) | Lakehouse bucket |
| Spark driver/executors | IRSA `k8s-ha-cluster-spark-s3` | Avoids IMDS rate limits when Comet's Rust reader cold-starts on many executors |
| Prometheus Thanos sidecar, Thanos | IRSA `k8s-ha-cluster-thanos-s3-writer` | `thanos/*` prefix |
| Loki | IRSA `k8s-ha-cluster-loki-s3-writer` | Dedicated Loki bucket |

---

# 🗂️ Metadata Catalog — Apache Gravitino

Gravitino is the **only** catalog. Hive Metastore and Unity Catalog have been removed.

- **:8090**: REST API and Web UI v2, used by `GravitinoSparkPlugin` (exposed as `gravitino.<domain>`).
- **:9001**: Iceberg REST Catalog, in-cluster only. Runs `dynamic-config-provider`, so it serves
  the same catalogs registered on :8090 and Spark-created tables show up in the UI.
- **Entity store**: Postgres `gravitino` DB. **Iceberg catalog backend**: Postgres `iceberg_catalog` DB (JDBC).
- **Bootstrap**: `gravitino-schema-init` (wave -1) loads the schema, then `gravitino-init` (wave 0)
  creates `enterprise_metalake` and registers `sales_catalog` (`lakehouse-iceberg`, S3FileIO).

Spark wiring (baked into the image's `spark-defaults.conf`):

```
spark.plugins                          org.apache.gravitino.spark.connector.plugin.GravitinoSparkPlugin
spark.sql.gravitino.metalake           enterprise_metalake
spark.sql.gravitino.uri                http://gravitino.default.svc.cluster.local:8090
spark.sql.gravitino.enableIcebergSupport true
```

StarRocks (when re-enabled) attaches as an external Iceberg catalog on
`http://gravitino.default.svc.cluster.local:9001/iceberg/`.

---

# ⚡ Spark Runtime

- **Image** `subhodeep2022/spark-bigdata:spark-3.5.8-v13-iceberg-gravitino`
  ([docker/spark](docker/spark)): Spark 3.5.8 (Scala 2.13, JDK 17), Iceberg Spark runtime +
  iceberg-aws-bundle, hadoop-aws, AWS SDK v1/v2, Gravitino Spark connector, Sedona/H3,
  Spark Connect, Postgres JDBC. `imagePullPolicy: Always`, because the tag is rebuilt in
  place and the golden AMI pre-pulls an older copy.
- **Execution**: the benchmark jobs in [examples/spark-jobs/](examples/spark-jobs/) (TPC-H
  SF100 / SF1000 and executor-shape variants) run with **Apache DataFusion Comet** (native
  exec, `CometShuffleManager`). They are submitted as `SparkApplication`s and land on
  Karpenter `spark-node` capacity with `karpenter.sh/do-not-disrupt`.
- **Event logs** go to S3 (zstd, rolling). The History Server reads
  `s3a://tpc-<acct>/spark-event-logs/` and keeps the same UI retention limits as the jobs.

---

# 📈 Observability

Two requirements drive the design. First, the cluster (and its EBS volumes) is destroyed
after each benchmark. Second, Karpenter removes a spark node about 180 s after its last
executor exits.

- **Alloy** (one DaemonSet, config in
  [config.alloy](big-data-platform/charts/monitoring/files/config.alloy)) handles pod logs,
  the node journal, Spark GC/diag files on NVMe and Hubble flows (all sent to Loki). It also
  scrapes node-exporter, cilium-agent and Hubble metrics and receives Comet OTLP, then
  pushes all of it to **both** Prometheus replicas. Because it ships continuously, a
  node's data is already stored before Karpenter removes the node.
- **Prometheus** runs 2 replicas on ebs-gp3 with 24 h retention and the remote-write
  receiver enabled. A Thanos sidecar uploads sealed 2 h blocks. The `tsdb-head-backup`
  container snapshots the head to `s3://<lakehouse>/thanos/periodic-snapshots/` every
  15 min, so short-lived clusters don't lose metrics.
- **Thanos**: Query (dedup on `prometheus_replica`), Store Gateway and Compactor
  (vertical compaction; retention 30 d raw / 90 d 5 m / 365 d 1 h). Grafana has it as the
  `Thanos` datasource.
- **Loki** stores TSDB index and chunks in S3 (schema v13). A 10 m flush,
  `flush_on_shutdown` and raised ingestion limits cover SF1000 log bursts.
- **S3 archives** (alongside Loki/Prometheus): Hubble flows, `:443` SYN/SYN-ACK/RST packet
  captures with pod names, raw Spark node log files, and Kubernetes events (via stdout to
  Loki).
- **Grafana** has provisioned cluster, logs and Spark dashboards
  ([charts/monitoring/dashboards](big-data-platform/charts/monitoring/dashboards)).
