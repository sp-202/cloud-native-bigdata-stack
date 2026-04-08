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
║  │  │Git-Sync  │ │   │  │   pods, auto-  │  │   │  (Unified AI & Data Lake)     │            ║
║  │  │DAG sync  │ │   │  │   scaled)      │  │   │                               │            ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  ns: default                  │            ║
║  │               │   │                      │   │  ┌─────────────────────────┐  │            ║
║  │  ┌──────────┐ │   │  ┌────────────────┐  │   │  │ Apache Gravitino 1.2.0  │  │            ║
║  │  │ Superset │ │   │  │  Spark History │  │   │  │                         │  │            ║
║  │  │  (BI/Viz)│ │   │  │    Server      │  │   │  │ Main API (:8090)        │  │            ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  │ Iceberg REST (:9001)    │  │            ║
║  └───────────────┘   └──────────────────────┘   │  │                         │  │            ║
║                                                 │  │ Catalogs:               │  │            ║
║                                                 │  │  - lakehouse-iceberg    │  │            ║
║                                                 │  │  - sales_catalog        │  │            ║
║                                                 │  │                         │  │            ║
║                                                 │  │ Drivers (in image):     │  │            ║
║                                                 │  │  - postgresql-42.6.0    │  │            ║
║                                                 │  │  - hadoop-aws-3.4.1     │  │            ║
║                                                 │  │  - aws-sdk-bundle-2.29  │  │            ║
║                                                 │  │  - iceberg-aws-1.10.1   │  │            ║
║                                                 │  └──────────┬──────────────┘  │            ║
║                                                 │             │ catalog lookup  │            ║
║                                                 │             ▼                 │            ║
║                                                 │  ┌─────────────────────────┐  │            ║
║                                                 │  │   StarRocks (OLAP)      │  │            ║
║                                                 │  │  Native Iceberg Catalog │  │            ║
║                                                 │  │  via Gravitino IRC      │  │            ║
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
║  │  │  ├── warehouse/          │   │  ├── gravitino         │    provisioner on each     │   ║
║  │  │  └── checkpoints/        │   │  └── iceberg_catalog   │    node)                   │   ║
║  │  └──────────────────────────┘   └────────────────────────┘                            │   ║
║  └───────────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — End-to-End Spark Job with Gravitino (submitted from JupyterHub)

  User (browser)
      │
      │  HTTPS via Cloudflare Tunnel
      ▼
  Traefik  ──►  JupyterHub (ns: default)
                    │
                    │  PySpark / SparkSession.remote() + GravitinoSparkPlugin
                    ▼
             Spark Connect Server  (shared gateway, ns: default)
                    │
                    │  resolves sales_catalog via Gravitino API
                    ▼
             Spark Operator  ──spawns──►  Driver Pod (with Gravitino plugin)
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
                                    Delta/Iceberg tables
                                              │
                                              │  table metadata via Gravitino IRC
                                              ▼
                              Apache Gravitino 1.2.0 (port 9001)
                              Iceberg REST Catalog (IRC)
                                              │
                                              │  metadata stored in
                                              ▼
                                    PostgreSQL (iceberg_catalog db)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — StarRocks querying Iceberg tables via Gravitino

  Superset / BI Client
      │
      │  SQL Query
      ▼
  StarRocks (OLAP Database)
      │
      │  native Iceberg catalog via Gravitino IRC endpoint
      ▼
  Apache Gravitino 1.2.0 (:9001 Iceberg REST)
      │
      │  resolves Iceberg table metadata
      ▼
  MinIO (S3-compatible) + PostgreSQL (table metadata)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DATA FLOW — Airflow DAG triggering a Spark job with Gravitino

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
                    Spark Operator → Driver (Gravitino plugin) → Executors → MinIO


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
| **0** | `apps` | User workloads (JupyterHub, Airflow Webserver/Scheduler), Gravitino, Ingress, and Monitoring. |

## 🛠 Local Sub-charts

Each major component is isolated into a local sub-chart within `big-data-platform/charts/`:
- **airflow**: The core workflow orchestrator.
- **minio**: S3-compatible object storage.
- **postgres**: Relational database for metadata.
- **gravitino**: Unified metadata lake with Iceberg REST Catalog (replaces Hive Metastore as primary).
- **monitoring**: Prometheus, Grafana, and Loki.
- **ingress**: Centralized Traefik routing rules.
- **persistence**: Static and dynamic storage definitions.
- **cloudflared**: Zero-Trust secure tunnel.

---

# 🌐 Networking (Cilium & Cloudflare)

The platform leverages **Cilium CNI** in **AWS ENI IPAM mode**. This gives every pod a native VPC IP, allowing for seamless integration with AWS Security Groups and VPC routing.

External access is secured by **Cloudflare Tunnel**, which provides a zero-trust encrypted path to the internal **Traefik** ingress controller. No inbound ports (80/443) are open on the EC2 instances.

---

# 🗂️ Metadata Catalog Architecture

## Gravitino: Unified Metadata Lake (Primary)

**Apache Gravitino 1.2.0** serves as the primary unified metadata catalog for the entire platform:

- **Main API** (port 8090): Used by GravitinoSparkPlugin for catalog discovery and table listing
- **Iceberg REST Catalog** (port 9001): Serves Iceberg table metadata to StarRocks and native Iceberg clients
- **Catalogs**:
  - `lakehouse-iceberg`: Iceberg tables on MinIO (S3-compatible)
  - `sales_catalog`: Example catalog for demo/testing
- **Backend Storage**: PostgreSQL (iceberg_catalog database) stores Iceberg table metadata

### Spark Integration with GravitinoSparkPlugin

Spark applications automatically resolve catalogs through Gravitino:

```
spark-defaults.conf:
  spark.plugins                    org.apache.gravitino.spark.connector.plugin.GravitinoSparkPlugin
  spark.sql.gravitino.metalake     enterprise_metalake
  spark.sql.gravitino.uri          http://gravitino.default.svc.cluster.local:8090
```

This allows Spark to use Gravitino as the primary catalog, enabling seamless table discovery and queries across different Iceberg tables.

### StarRocks Integration with Iceberg REST

StarRocks accesses Iceberg tables directly through Gravitino's Iceberg REST Catalog:

```sql
CREATE EXTERNAL CATALOG iceberg_gravitino PROPERTIES (
  'iceberg.catalog.uri' = 'http://gravitino.default.svc.cluster.local:9001/iceberg/',
  'type' = 'iceberg'
);

USE iceberg_gravitino.lakehouse_iceberg;
SELECT * FROM your_table;
```

This enables sub-second OLAP queries on Iceberg-formatted data stored in MinIO.

---

# 🔄 Migration from Hive Metastore to Gravitino (v1.0.1+)

The platform has fully transitioned to **Apache Gravitino** as the primary metadata catalog. Hive Metastore has been retained for backward compatibility only and is no longer the default catalog for new tables.

### Key Changes in v1.0.1

- **Primary Catalog**: Gravitino replaces Hive Metastore (HMS) as the default metadata source
- **Spark Integration**: All Spark applications use GravitinoSparkPlugin by default
- **StarRocks**: Accesses tables through Gravitino IRC instead of HMS
- **Backward Compatibility**: HMS remains available for legacy systems that require it
- **Benefits**:
  - Unified metadata across multiple catalog types (Iceberg, Delta, Hive)
  - Better governance and discoverability through Gravitino Web UI
  - Native Iceberg REST support for downstream systems
  - Support for dynamic catalog configuration

```
