# Platform Architecture — Text Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    EXTERNAL WORLD                                           │
│                         Browser / API Client / BI Tool                                      │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │  HTTPS (443)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                              CLOUDFLARE EDGE (Zero-Trust Tunnel)                            │
│                    No inbound firewall ports — outbound-only tunnel                         │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │  encrypted tunnel
                                       ▼
┌══════════════════════════════════════════════════════════════════════════════════════════════╗
║                        AWS EC2 — Self-Managed Kubernetes (kubeadm)                           ║
║                        ARM64 Graviton Nodes  |  Cilium CNI (ENI IPAM)                        ║
║                                                                                              ║
║  namespace: cloudflare                                                                       ║
║  ┌────────────────────────────────────────────┐                                              ║
║  │  cloudflared  (3 replicas, HA)             │                                              ║
║  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │                                              ║
║  │  │  pod-1   │ │  pod-2   │ │  pod-3   │    │  topology spread across nodes                ║
║  │  └────┬─────┘ └────┬─────┘ └────┬─────┘    │  PodDisruptionBudget enforced                ║
║  └───────┼────────────┼────────────┼──────────┘                                              ║
║          └────────────┴────────────┘                                                         ║
║                          │ routes to Traefik ClusterIP                                       ║
║                          ▼                                                                   ║
║  namespace: kube-system                                                                      ║
║  ┌─────────────────────────────────────────────────────────────────┐                         ║
║  │  Traefik Ingress Controller  (ClusterIP — no LoadBalancer)      │                         ║
║  │                                                                 │                         ║
║  │  Managed via `big-data-platform/charts/ingress`                 │                         ║
║  │  Sync Wave: 0  (Deploys concurrently with apps)                 │                         ║
║  └──────────────────────────────┬──────────────────────────────────┘                         ║
║                                 │                                                            ║
║          ┌──────────────────────┼────────────────────────────────┐                           ║
║          │                      │                                │                           ║
║          ▼                      ▼                                ▼                           ║
║  ┌───────────────┐   ┌──────────────────────┐   ┌───────────────────────────────┐            ║
║  │  NOTEBOOK &   │   │  COMPUTE LAYER       │   │  OBSERVABILITY STACK          │            ║
║  │  WORKFLOW     │   │                      │   │                               │            ║
║  │               │   │  ns: default         │   │  ns: monitoring               │            ║
║  │  ns: default  │   │  ┌────────────────┐  │   │  ┌───────────┐ ┌──────────┐   │            ║
║  │  ┌──────────┐ │   │  │ Spark Connect  │  │   │  │Prometheus │ │  Loki    │   │            ║
║  │  │JupyterHub│ │   │  │    Server      │  │   │  │ Operator  │ │  Stack   │   │            ║
║  │  │          │◄├───┤  │  (gateway for  │  │   │  └─────┬─────┘ └─────┬────┘   │            ║
║  │  │PySpark   │ │   │  │   all clients) │  │   │        │             │        │            ║
║  │  │Scala     │ │   │  └───────┬────────┘  │   │  ┌─────▼─────────────▼────┐   │            ║
║  │  │SQL magic │ │   │          │           │   │  │      Grafana           │   │            ║
║  │  └──────────┘ │   │          │ submits   │   │  │  Dashboards / Alerts   │   │            ║
║  │               │   │          ▼           │   │  └────────────────────────┘   │            ║
║  │  ┌──────────┐ │   │  ┌────────────────┐  │   │                               │            ║
║  │  │  Marimo  │ │   │  │ Spark Operator │  │   │  ServiceMonitors watching:    │            ║
║  │  │(reactive │◄├───┤  │                │  │   │   - Spark driver/executors    │            ║
║  │  │ Python)  │ │   │  │  SparkApp CRDs │  │   │   - Airflow scheduler         │            ║
║  │  └──────────┘ │   │  └───────┬────────┘  │   │   - cloudflared metrics       │            ║
║  │               │   │          │ spawns    │   │   - Node metrics              │            ║
║  │  ┌──────────┐ │   │          ▼           │   └───────────────────────────────┘            ║
║  │  │ Airflow  │ │   │  ┌────────────────┐  │                                                ║
║  │  │          │ │   │  │Spark Executors │  │   ┌───────────────────────────────┐            ║
║  │  │K8s Exec  │─┼───►  │  (ephemeral    │  │   │  METADATA & CATALOG           │            ║
║  │  │Git-Sync  │ │   │  │   pods, auto-  │  │   │                               │            ║
║  │  │DAG sync  │ │   │  │   scaled)      │  │   │  ns: default                  │            ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  ┌─────────────────────────┐  │            ║
║  │               │   │                      │   │  │   Hive Metastore 4.1.0  │  │            ║
║  │  ┌──────────┐ │   │  ┌────────────────┐  │   │  │                         │  │            ║
║  │  │ Superset │ │   │  │  Spark History │  │   │  │  HMS (Thrift :9083)     │  │            ║
║  │  │  (BI/Viz)│ │   │  │    Server      │  │   │  │  HiveServer2 (:10000)   │  │            ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  │                         │  │            ║
║  └───────────────┘   └──────────────────────┘   │  │  Drivers (in image):    │  │            ║
║                                                 │  │   postgresql-42.6.0.jar │  │            ║
║                                                 │  │   hadoop-aws-3.4.1.jar  │  │            ║
║                                                 │  │   bundle-2.29.52.jar    |  |            ║
║                                                 |  |  url-client-2.29.52.jar |  │            ║
║                                                 │  └──────────┬──────────────┘  │            ║
║                                                 │             │ reads/writes    │            ║
║                                                 │             ▼                 │            ║
║                                                 │  ┌─────────────────────────┐  │            ║
║                                                 │  │   StarRocks (OLAP)      │  │            ║
║                                                 │  │   Delta Native Catalog  │  │            ║
║                                                 │  │   reads MinIO directly  │  │            ║
║                                                 │  └─────────────────────────┘  │            ║
║                                                 └───────────────────────────────┘            ║
║                                                                                              ║
║  ┌───────────────────────────────────────────────────────────────────────────────────────┐   ║
║  │                        DATA & PERSISTENCE LAYER                                       │   ║
║  │                                                                                       │   ║
║  │  ns: default                                                                          │   ║
║  │                                                                                       │   ║
║  │  ┌──────────────────────────┐   ┌────────────────────────┐   ┌──────────────────┐     │   ║
║  │  │        MinIO             │   │      PostgreSQL        │   │      Redis       │     │   ║
║  │  │  (S3-compatible)         │   │  (metadata backbone)   │   │  (Superset cache)│     │   ║
║  │  │                          │   │                        │   └──────────────────┘     │   ║
║  │  │  Buckets:                │   │  Databases:            │                            │   ║
║  │  │  ├── spark-data/         │   │  ├── airflow_db        │   Storage: OpenEBS         │   ║
║  │  │  ├── delta-lake/         │   │  ├── superset_db       │   (hostpath dynamic        │   ║
║  │  │  ├── warehouse/          │   │  └── hive_metastore    │    provisioner on each     │   ║
║  │  │  └── checkpoints/        │   │                        │    node)                   │   ║
║  │  └──────────────────────────┘   └────────────────────────┘                            │   ║
║  └───────────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — End-to-End Spark Job (submitted from JupyterHub)

  User (browser)
      │
      │  HTTPS via Cloudflare Tunnel
      ▼
  Traefik  ──►  JupyterHub (ns: default)
                    │
                    │  PySpark / SparkSession.remote()
                    ▼
             Spark Connect Server  (shared gateway, ns: default)
                    │
                    │  submits SparkApplication CRD
                    ▼
             Spark Operator  ──spawns──►  Driver Pod
                                              │
                                    ┌─────────┴──────────┐
                                    │                    │
                                    ▼                    ▼
                              Executor Pod-1      Executor Pod-N
                                    │                    │
                                    └─────────┬──────────┘
                                              │  s3a://
                                              ▼
                                    MinIO (S3-compatible)
                                    Delta Lake tables
                                              │
                                              │  catalog lookup
                                              ▼
                                    Hive Metastore (Thrift :9083)
                                              │
                                              │  metadata stored in
                                              ▼
                                          PostgreSQL
                                        (hive_metastore db)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — Airflow DAG triggering a Spark job

  Git Repository (DAGs)
      │
      │  git pull (every 60s)
      ▼
  airflow-git-sync pod  ──writes──►  shared DAGs volume
                                          │
                                          ▼
                                   Airflow Scheduler
                                          │
                                          │  KubernetesExecutor
                                          ▼
                                   Task Pod (ephemeral)
                                          │
                                          │  submits SparkApplication CRD
                                          ▼
                                   Spark Operator → Driver → Executors → MinIO


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 📂 Helm Umbrella Chart Architecture

The platform is now managed as a single **Umbrella Chart** located in `big-data-platform/`. This architecture allows for centralized configuration, simplified dependency management, and robust sync-wave orchestration.

## 🌊 Sync Wave Strategy (ArgoCD)

To ensure a stable and predictable deployment, the project uses ArgoCD Sync Waves to enforce resource ordering:

| Wave | Component | Responsibility |
| :--- | :--- | :--- |
| **-3** | `persistence` | Namespaces, PersistentVolumes, and PVCs (Storage Foundation). |
| **-2** | `infra` | Core databases (Postgres, Redis), MinIO, and Airflow Secrets. |
| **-1** | `init-jobs` | DB migrations (`airflow-db-migrate`) and bucket creation (`minio-jobs`). |
| **0** | `apps` | User workloads (JupyterHub, Airflow Webserver/Scheduler), Ingress, and Monitoring. |

## 🛠 Local Sub-charts

Each major component is isolated into a local sub-chart within `big-data-platform/charts/`:
- **airflow**: The core workflow orchestrator.
- **minio**: S3-compatible object storage.
- **postgres**: Relational database for metadata.
- **monitoring**: Prometheus, Grafana, and Loki.
- **ingress**: Centralized Traefik routing rules.
- **persistence**: Static and dynamic storage definitions.
- **cloudflared**: Zero-Trust secure tunnel.

---

# 🌐 Networking (Cilium & Cloudflare)

The platform leverages **Cilium CNI** in **AWS ENI IPAM mode**. This gives every pod a native VPC IP, allowing for seamless integration with AWS Security Groups and VPC routing.

External access is secured by **Cloudflare Tunnel**, which provides a zero-trust encrypted path to the internal **Traefik** ingress controller. No inbound ports (80/443) are open on the EC2 instances.
```
