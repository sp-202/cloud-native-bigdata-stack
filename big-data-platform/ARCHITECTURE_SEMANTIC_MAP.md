# Big Data Platform — Component Architecture & Semantic Relationships

**Graph Last Updated:** 2026-04-17
**Scan Depth:** Deep semantic analysis of 93+ files across 17 sub-charts

---

## Platform Overview

**Type:** Helm Umbrella Chart (v1.0.0) on AWS EC2 (ARM64/Graviton)  
**Root Namespace:** default  
**Storage Backend:** OpenEBS (openebs-hostpath)  
**Domain:** dailyblogstudio.com  
**Tunnel:** Cloudflare (91e5be1d-3b51-4cac-aebf-d330aafda394)

---

## Core Component Relationships

### 1. **Gravitino ↔ Spark ↔ Hive Metastore Triangle**

```
┌────────────────────────────────────────────────────────────┐
│                    DATA CATALOG LAYER                      │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Gravitino (Apache 1.2.0)                                 │
│  ├─ Role: Unified AI & Data Metadata Lake                │
│  ├─ Endpoint: :8090 (API) | :9001 (Iceberg REST Catalog) │
│  ├─ Metalake: enterprise_metalake                         │
│  ├─ Catalog Type: Iceberg REST Catalog (IRC)             │
│  └─ Internal: Iceberg 1.10.1                             │
│                                                             │
│  DEPENDS ON:                                              │
│  ├─ PostgreSQL (metadata + HMS compatibility)            │
│  ├─ S3/MinIO (storage backend)                           │
│  └─ Spark 3.5.8 (compute + query execution)             │
│                                                             │
│  SERVES:                                                  │
│  ├─ Spark Jobs (via GravitinoSparkPlugin)               │
│  ├─ StarRocks (direct IRC access via :9001)             │
│  ├─ JupyterHub (catalog discovery)                      │
│  └─ Hive (legacy HMS fallback)                          │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                    COMPUTE LAYER                           │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Spark 3.5.8 (sub.2022/spark-bigdata:v12-iceberg-gravitino)
│  ├─ Role: Distributed compute engine                      │
│  ├─ Pod Affinity: spark-node, spark-worker               │
│  ├─ Image Tag: iceberg + gravitino plugins pre-loaded    │
│  └─ History Server: spark-history-server chart            │
│                                                             │
│  DEPENDS ON:                                              │
│  ├─ Gravitino (catalog access via IRC @ :9001)          │
│  ├─ Hive Metastore (fallback HMS @ :9083)               │
│  ├─ PostgreSQL (job metadata)                            │
│  ├─ S3/MinIO (storage read/write)                        │
│  └─ Airflow (job orchestration)                          │
│                                                             │
│  PLUGINS:                                                 │
│  ├─ GravitinoSparkPlugin (catalog plugin)                │
│  ├─ Iceberg (1.10.1 - table format)                      │
│  └─ Spark Connect (remote execution)                     │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                   METADATA LAYER                           │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Hive Metastore (HMS 3.1.3)                              │
│  ├─ Role: Legacy metadata store + compatibility layer    │
│  ├─ Service: hive-metastore.default.svc                 │
│  ├─ Port: 9083 (Thrift)                                 │
│  └─ Image: subhodeep2022/spark-bigdata:hive-3.1.3-arm64 │
│                                                             │
│  DEPENDS ON:                                              │
│  ├─ PostgreSQL (metadata persistence)                    │
│  └─ S3/MinIO (table location storage)                    │
│                                                             │
│  CONSUMED BY:                                             │
│  ├─ Spark (fallback when Gravitino unavailable)         │
│  ├─ StarRocks (table discovery)                          │
│  └─ Airflow (metadata queries)                           │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

### 2. **Data Platform Access & Networking**

```
┌────────────────────────────────────────────────────────────┐
│                   EXTERNAL INGRESS                         │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Cloudflared Deployment                                   │
│  ├─ Role: Secure tunnel to dailyblogstudio.com           │
│  ├─ Tunnel ID: 91e5be1d-3b51-4cac-aebf-d330aafda394     │
│  ├─ Namespace: cloudflared (dedicated)                    │
│  ├─ NetworkPolicy: Restricted egress to tunnel only      │
│  └─ Replicas: HA across available nodes                  │
│                                                             │
│  ROUTES TO:                                               │
│  ├─ JupyterHub @ :8000 (notebook interface)              │
│  ├─ Superset @ :8088 (BI/dashboards)                     │
│  ├─ Headlamp @ :9000 (K8s dashboard)                     │
│  ├─ Grafana (from kube-prometheus-stack)                 │
│  ├─ Spark History Server @ :18080                        │
│  └─ Gravitino API @ :8090                                │
│                                                             │
│  Ingress Controller (ingress chart)                       │
│  ├─ TLS termination                                      │
│  ├─ Path-based routing                                   │
│  └─ Rate limiting (optional)                             │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                  ORCHESTRATION LAYER                       │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Airflow 2.7.1                                            │
│  ├─ Role: Workflow orchestration & DAG scheduling         │
│  ├─ Image: apache/airflow:2.7.1                           │
│  ├─ Database: PostgreSQL                                  │
│  ├─ Executor: KubernetesExecutor                          │
│  └─ Storage: 5Gi PVC (DAGs, logs)                         │
│                                                             │
│  TRIGGERS:                                                │
│  ├─ Spark jobs (via spark-operator)                       │
│  ├─ Data quality checks (via custom operators)            │
│  └─ Metadata sync tasks (to Gravitino)                    │
│                                                             │
│  DEPENDS ON:                                              │
│  ├─ PostgreSQL (DAG state, task logs)                     │
│  ├─ Redis (task queuing - optional)                       │
│  └─ Spark Operator (SparkApplication CRD)                │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

### 3. **Storage & State Management**

```
┌────────────────────────────────────────────────────────────┐
│                   STORAGE BACKEND                          │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  MinIO (S3-compatible object storage)                     │
│  ├─ Role: Distributed object storage + data lake root    │
│  ├─ Endpoint: minio.default.svc.cluster.local:9000      │
│  ├─ Access: minioadmin / minioadmin (global.s3.*)        │
│  ├─ Pod Affinity: minio-worker nodes                      │
│  ├─ Path Style: Enabled                                  │
│  ├─ Persistence: 10Gi @ /mnt/spark-nvme/minio            │
│  └─ Node Selector: node-role.kubernetes.io/minio-worker  │
│                                                             │
│  STORAGE BUCKETS (implicit):                              │
│  ├─ spark-logs (Spark event logs for history server)     │
│  ├─ gravitino-meta (Gravitino metadata + lineage)        │
│  ├─ hive-tables (Hive external table locations)          │
│  └─ user-data (JupyterHub + Superset artifacts)          │
│                                                             │
│  CONSUMED BY (all components):                            │
│  ├─ Spark (data reads/writes, shuffle)                   │
│  ├─ Gravitino (table files via IRC)                      │
│  ├─ Hive (external tables)                               │
│  ├─ StarRocks (iceberg table scans)                       │
│  └─ JupyterHub (notebook data)                            │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                  RELATIONAL METADATA STORE                 │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  PostgreSQL 15+                                           │
│  ├─ Role: ACID-compliant metadata persistence             │
│  ├─ Service: postgres.default.svc.cluster.local:5432     │
│  ├─ Credentials: postgres / password (security issue!)    │
│  ├─ Storage: 10Gi @ /var/openebs/local/postgres-data    │
│  ├─ Node Selector: node-role.kubernetes.io/k8s-gp-node  │
│  └─ Storage Class: openebs-hostpath                      │
│                                                             │
│  DATABASES CREATED BY:                                    │
│  ├─ airflow_db (Airflow DAGs, task history)              │
│  ├─ hive_metastore (Hive HMS tables + schemas)           │
│  ├─ superset_db (Superset dashboards, datasets)          │
│  └─ gravitino_db (Gravitino metadata + catalogs)         │
│                                                             │
│  INIT JOBS:                                               │
│  ├─ airflow-db-migrate (post-install)                     │
│  ├─ airflow-user-init (creates admin user)                │
│  └─ gravitino-init (creates catalogs + metastore DB)     │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                   CACHE LAYER (OPTIONAL)                   │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Redis                                                    │
│  ├─ Role: Task queuing (Airflow), session cache (apps)   │
│  ├─ Storage: 2Gi (chart default)                          │
│  └─ Status: Available if redis.enabled = true            │
│                                                             │
│  USED BY:                                                 │
│  ├─ Airflow (CeleryExecutor - if enabled)                │
│  ├─ JupyterHub (session storage)                         │
│  └─ Superset (caching layer)                              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

### 4. **Analytics & Visualization**

```
┌────────────────────────────────────────────────────────────┐
│                 ANALYTICS ENGINE                           │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  StarRocks (via kube-starrocks operator v1.9.8)          │
│  ├─ Role: OLAP query engine + vectorized MPP database    │
│  ├─ Operator: starrocks-kubernetes-operator              │
│  ├─ Version: Latest stable (v1.9.8)                       │
│  ├─ FE Replicas: Distributed across k8s-gp-node         │
│  ├─ BE Replicas: Distributed across k8s-gp-node         │
│  ├─ Persistence: 10Gi each @ /mnt/spark-nvme/starrocks-* │
│  └─ Catalog Integration: Direct Iceberg (via Gravitino)  │
│                                                             │
│  DATA INGESTION:                                          │
│  ├─ Iceberg tables → StarRocks (native Iceberg support) │
│  ├─ Spark → StarRocks (insert overwrite)                │
│  └─ External tables from MinIO / Hive                    │
│                                                             │
│  QUERY PATTERNS:                                          │
│  ├─ OLAP aggregations (via SQL)                          │
│  ├─ Real-time analytics dashboards (Superset)            │
│  └─ Ad-hoc JDBC queries (JupyterHub notebooks)           │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              DASHBOARDING & BI                             │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Superset (Apache 0.12.0)                                 │
│  ├─ Role: Visual analytics + dashboard creation           │
│  ├─ Chart: apache/superset                                │
│  ├─ Database: PostgreSQL (superset_db)                    │
│  └─ Connectors: StarRocks, Spark, Hive (JDBC)            │
│                                                             │
│  INIT JOB:                                                │
│  ├─ superset-init-job (creates admin user, DB)           │
│  ├─ Setup default connections to analytics engines       │
│  └─ Status: Pending fix (deployment issue noted)         │
│                                                             │
│  VISUALIZATION SOURCES:                                   │
│  ├─ StarRocks (default OLAP backend)                     │
│  ├─ Spark SQL (ad-hoc queries)                           │
│  └─ Hive (legacy table browsing)                         │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│           COLLABORATIVE ANALYTICS                          │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  JupyterHub (custom image: v4.0.7-pyspark-scala-sql)     │
│  ├─ Role: Multi-user collaborative notebooks              │
│  ├─ Image: subhodeep2022/spark-bigdata:jupyterhub-*     │
│  ├─ Kubernetes: KubeSpawner (per-user pods)              │
│  ├─ Home Storage: 50Gi PVC per user                       │
│  └─ Database: PostgreSQL (user/session state)             │
│                                                             │
│  PRE-INSTALLED LIBRARIES:                                 │
│  ├─ PySpark (auto-connected to Spark cluster)            │
│  ├─ Scala support (IJava kernel)                          │
│  ├─ SQL magic (%sql → Gravitino/StarRocks)              │
│  └─ Pandas, NumPy, Matplotlib                            │
│                                                             │
│  KERNEL SETUP:                                            │
│  ├─ PySpark kernel → Spark 3.5.8 @ spark-master:7077    │
│  ├─ Spark configs injected at startup (gravitino plugin) │
│  └─ S3 credentials from global config                    │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

### 5. **Monitoring & Observability**

```
┌────────────────────────────────────────────────────────────┐
│              METRICS COLLECTION                            │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Prometheus (via kube-prometheus-stack v56.6.2)          │
│  ├─ Role: Time-series metrics database                   │
│  ├─ Scrape Targets: K8s API, kubelets, service monitors  │
│  ├─ Storage: 50Gi (configurable)                         │
│  └─ Retention: 15d (default)                             │
│                                                             │
│  SERVICE MONITORS:                                        │
│  ├─ Spark Driver/Executor metrics (port 4040)            │
│  ├─ Airflow metrics (via StatsD exporter)                │
│  ├─ PostgreSQL (via postgres-exporter)                   │
│  ├─ MinIO (via minio-exporter)                           │
│  └─ StarRocks (via starrocks-exporter)                   │
│                                                             │
│  GRAFANA DASHBOARDS:                                      │
│  ├─ Kubernetes cluster (node CPU, memory, disk)          │
│  ├─ Spark jobs (stages, task execution time)             │
│  ├─ Airflow DAG runs (success/failure rates)             │
│  ├─ Data platform health (storage, PostgreSQL)           │
│  └─ Custom data quality metrics                          │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│               LOGGING & AGGREGATION                        │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Loki Stack (v2.10.2)                                     │
│  ├─ Role: Log aggregation + querying (Prometheus-style)  │
│  ├─ Storage: Object storage (MinIO) or local             │
│  ├─ Promtail: Agent on each node (log scraping)          │
│  └─ Grafana integration: Pre-built dashboards             │
│                                                             │
│  SCRAPED LOGS:                                            │
│  ├─ Kubernetes pod logs (stdout/stderr)                  │
│  ├─ Spark driver/executor logs (saved to MinIO)          │
│  ├─ Airflow task logs (persistent storage)               │
│  ├─ Application logs (with structured labels)            │
│  └─ System-level audit logs (optional)                   │
│                                                             │
│  RETENTION:                                               │
│  ├─ Hot storage: 7 days                                  │
│  ├─ Warm storage: 30 days (from MinIO)                   │
│  └─ Query time range: 15m to 30d                         │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              DASHBOARD & VISUALIZATION                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Grafana (via kube-prometheus-stack)                      │
│  ├─ Role: Metrics visualization + alerting               │
│  ├─ Data Sources: Prometheus, Loki                        │
│  ├─ Authentication: OAuth (Cloudflare tunnel)             │
│  └─ Port: :3000 (routed via cloudflared)                 │
│                                                             │
│  HEADLAMP INTEGRATION:                                    │
│  ├─ Web-based K8s dashboard                              │
│  ├─ Pod introspection, log viewer                        │
│  ├─ Resource browser (PVCs, ConfigMaps, Secrets)         │
│  └─ Role-based access control (RBAC visualization)       │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Data Flow Patterns

### Pattern 1: Spark ETL with Gravitino Catalog

```
External Data Source
         ↓
   Spark Job (KubernetesExecutor or SparkApplication)
         ↓
   GravitinoSparkPlugin (catalog discovery)
         ↓
   Iceberg Table Format (via Gravitino IRC @ :9001)
         ↓
   MinIO S3 Storage (/iceberg/ bucket)
         ↓
   [Optional] StarRocks Ingestion (real-time OLAP)
         ↓
   Superset / JupyterHub (visualization & analysis)
```

### Pattern 2: Airflow-Orchestrated Spark Workflows

```
Airflow Scheduler (2.7.1)
         ↓
  DAG Trigger → SparkApplication CRD
         ↓
  Spark Operator (2.4.0) creates Pod
         ↓
  Spark Driver reads from Gravitino → Compute on Workers
         ↓
  Results written to MinIO (or Iceberg catalog)
         ↓
  Task log persisted: PostgreSQL (airflow_db) + MinIO
         ↓
  [Optional] Metadata sync → Gravitino metastore
```

### Pattern 3: Interactive Analysis via JupyterHub

```
User Login → Headlamp (K8s dashboard)
                ↓
         JupyterHub Session (KubeSpawner)
                ↓
    [PySpark Kernel] ← → Spark Cluster (7077)
                ↓
         GravitinoSparkPlugin (catalog)
                ↓
  Query Iceberg tables in Gravitino
                ↓
  [Optional] Push aggregates → StarRocks for BI
```

---

## Critical Dependencies & Initialization Order

### Tier 0 (Foundational)
1. **Persistence (OpenEBS)** - Creates node directories for PVCs
2. **Namespaces** - isolation + network policies
3. **PostgreSQL** - metadata store (blocks: Hive, Airflow, Superset, Gravitino)

### Tier 1 (Core Data Layer)
4. **MinIO** - object storage (blocks: Spark, Gravitino, Hive)
5. **Hive Metastore** - legacy HMS (blocks: Gravitino as fallback)
6. **Redis** (optional) - cache/queueing

### Tier 2 (Catalog & Compute)
7. **Gravitino** - unified catalog (init job creates metastore DB)
8. **Spark Operator** - CRD registration
9. **Spark History Server** - log aggregation

### Tier 3 (Orchestration & Execution)
10. **Airflow** - DAG scheduling (requires: PostgreSQL, Spark Operator)
11. **Spark Connect Server** (optional) - remote execution

### Tier 4 (Analytics & Access)
12. **StarRocks** - OLAP engine (optional, requires: Spark)
13. **JupyterHub** - interactive compute
14. **Superset** - BI/dashboards (init job sets up connections)

### Tier 5 (Monitoring & Extras)
15. **kube-prometheus-stack** - metrics collection
16. **loki-stack** - log aggregation
17. **Cloudflared** - external tunnel
18. **Ingress** - path-based routing
19. **Headlamp** - K8s UI

---

## Known Configuration Issues (From project memory)

| Issue | Status | Impact |
|-------|--------|--------|
| **Spark CRDs** | Pending | SparkApplication may fail pod creation without proper CRD versions |
| **Superset init job** | Pending | Dashboard init fails; manual DB setup required |
| **Airflow naming** | Pending | Helm release name conflicts with subchart naming conventions |
| **Gravitino S3FileIO** | Pending | MinIO path-style access requires explicit S3FileIO configuration |

---

## Node Affinity & Topology

```
┌─────────────────────────────────────────┐
│  k8s-gp-node (general purpose)          │
│  ├─ PostgreSQL                          │
│  ├─ Airflow                             │
│  ├─ StarRocks FE/BE                     │
│  ├─ Gravitino                           │
│  ├─ Redis                               │
│  └─ Monitoring stack                    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  spark-node (primary executors)         │
│  ├─ Spark Executors (KubernetesExecutor)│
│  ├─ JupyterHub spawned pods             │
│  └─ Shuffle map tasks                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  spark-worker (secondary executors)     │
│  ├─ Spark Executors (overflow)          │
│  └─ Long-running service pods           │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  minio-worker (dedicated S3 backend)    │
│  └─ MinIO (high I/O workload)           │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  control-plane (cluster management)     │
│  ├─ API Server, etcd, Controller Manager│
│  ├─ Spark Operator                      │
│  ├─ Airflow Webserver (control)         │
│  └─ Cloudflared tunnel agent            │
└─────────────────────────────────────────┘
```

---

## Integration Summary

| Component | Primary Role | Data Flow | Dependencies |
|-----------|-------------|-----------|--------------|
| **Gravitino** | Unified catalog | ← Spark, StarRocks, Hive | PostgreSQL, MinIO |
| **Spark** | Compute engine | ← Airflow, JupyterHub, Spark Connect | Gravitino/HMS, MinIO, PostgreSQL |
| **Hive Metastore** | Legacy HMS | ← StarRocks, Spark (fallback) | PostgreSQL, MinIO |
| **MinIO** | Object storage | ← All compute + metadata | None (foundational) |
| **PostgreSQL** | Metadata store | ← Hive, Airflow, Superset, Gravitino | None (foundational) |
| **Airflow** | Orchestration | → Spark jobs, metadata sync | PostgreSQL, Spark Operator |
| **StarRocks** | OLAP analytics | ← Spark (batch), Iceberg (real-time) | Gravitino, Spark, PostgreSQL |
| **JupyterHub** | Interactive compute | ← Spark cluster | PostgreSQL, MinIO, Spark |
| **Superset** | BI dashboards | ← StarRocks, Spark, Hive | PostgreSQL |
| **Cloudflared** | External access | → All web UIs | None (optional) |

---

## Semantic Tags for Cross-Reference

- **Metadata Layer:** Gravitino, Hive Metastore, PostgreSQL
- **Compute Layer:** Spark, JupyterHub, Spark Connect, Spark History Server
- **Storage Layer:** MinIO, S3 (via Iceberg)
- **Analytics Layer:** StarRocks, Superset, Spark SQL
- **Orchestration:** Airflow, Spark Operator, KubernetesExecutor
- **Observability:** Prometheus, Grafana, Loki, Headlamp
- **Networking:** Cloudflared, Ingress, NetworkPolicy
- **Data Formats:** Iceberg, Delta (via Gravitino), Hive, Parquet
- **Access Patterns:** Direct JDBC, S3 API, Spark SQL, REST (Gravitino)

---

**Generated by Graphify Deep Semantic Scan**  
**Frequency:** Updated on architecture changes  
**Last Verified:** 2026-04-17
