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
║                        AWS EC2 — Self-Managed Kubernetes (kubeadm)                         ║
║                        ARM64 Graviton Nodes  |  Cilium CNI (ENI IPAM)                      ║
║                                                                                              ║
║  namespace: cloudflare                                                                       ║
║  ┌────────────────────────────────────────────┐                                             ║
║  │  cloudflared  (3 replicas, HA)             │                                             ║
║  │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │                                             ║
║  │  │  pod-1   │ │  pod-2   │ │  pod-3   │   │  topology spread across nodes               ║
║  │  └────┬─────┘ └────┬─────┘ └────┬─────┘   │  PodDisruptionBudget enforced               ║
║  └───────┼────────────┼────────────┼──────────┘                                             ║
║          └────────────┴────────────┘                                                         ║
║                          │ routes to Traefik ClusterIP                                       ║
║                          ▼                                                                   ║
║  namespace: kube-system                                                                      ║
║  ┌─────────────────────────────────────────────────────────────────┐                        ║
║  │  Traefik Ingress Controller  (ClusterIP — no LoadBalancer)      │                        ║
║  │                                                                  │                        ║
║  │  IngressRoutes:                                                  │                        ║
║  │    airflow.*        →  airflow svc                               │                        ║
║  │    jupyterhub.*     →  jupyterhub svc                           │                        ║
║  │    superset.*       →  superset svc                             │                        ║
║  │    minio.*          →  minio svc                                │                        ║
║  │    grafana.*        →  grafana svc                              │                        ║
║  │    spark.*          →  spark-connect svc                        │                        ║
║  │    spark-history.*  →  spark-history svc                        │                        ║
║  │    hubble.*         →  hubble-ui svc                            │                        ║
║  │    headlamp.*       →  headlamp svc                             │                        ║
║  └──────────────────────────────┬──────────────────────────────────┘                        ║
║                                 │                                                            ║
║          ┌──────────────────────┼────────────────────────────────┐                          ║
║          │                      │                                │                          ║
║          ▼                      ▼                                ▼                          ║
║  ┌───────────────┐   ┌──────────────────────┐   ┌───────────────────────────────┐          ║
║  │  NOTEBOOK &   │   │  COMPUTE LAYER       │   │  OBSERVABILITY STACK          │          ║
║  │  WORKFLOW     │   │                      │   │                               │          ║
║  │               │   │  ns: default         │   │  ns: monitoring               │          ║
║  │  ns: default  │   │  ┌────────────────┐  │   │  ┌───────────┐ ┌──────────┐  │          ║
║  │  ┌──────────┐ │   │  │ Spark Connect  │  │   │  │Prometheus │ │  Loki    │  │          ║
║  │  │JupyterHub│ │   │  │    Server      │  │   │  │ Operator  │ │  Stack   │  │          ║
║  │  │          │◄├───┤  │  (gateway for  │  │   │  └─────┬─────┘ └─────┬────┘  │          ║
║  │  │PySpark   │ │   │  │   all clients) │  │   │        │             │       │          ║
║  │  │Scala     │ │   │  └───────┬────────┘  │   │  ┌─────▼─────────────▼────┐  │          ║
║  │  │SQL magic │ │   │          │           │   │  │      Grafana            │  │          ║
║  │  └──────────┘ │   │          │ submits   │   │  │  Dashboards / Alerts    │  │          ║
║  │               │   │          ▼           │   │  └─────────────────────────┘  │          ║
║  │  ┌──────────┐ │   │  ┌────────────────┐  │   │                               │          ║
║  │  │  Marimo  │ │   │  │ Spark Operator │  │   │  ServiceMonitors watching:    │          ║
║  │  │(reactive │◄├───┤  │                │  │   │   - Spark driver/executors    │          ║
║  │  │ Python)  │ │   │  │  SparkApp CRDs │  │   │   - Airflow scheduler         │          ║
║  │  └──────────┘ │   │  └───────┬────────┘  │   │   - cloudflared metrics       │          ║
║  │               │   │          │ spawns     │   │   - Node metrics              │          ║
║  │  ┌──────────┐ │   │          ▼           │   └───────────────────────────────┘          ║
║  │  │ Airflow  │ │   │  ┌────────────────┐  │                                              ║
║  │  │          │ │   │  │Spark Executors │  │   ┌───────────────────────────────┐          ║
║  │  │K8s Exec  │─┼───►  │  (ephemeral    │  │   │  METADATA & CATALOG           │          ║
║  │  │Git-Sync  │ │   │  │   pods, auto-  │  │   │                               │          ║
║  │  │DAG sync  │ │   │  │   scaled)      │  │   │  ns: default                  │          ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  ┌─────────────────────────┐  │          ║
║  │               │   │                      │   │  │   Hive Metastore 4.1.0  │  │          ║
║  │  ┌──────────┐ │   │  ┌────────────────┐  │   │  │                         │  │          ║
║  │  │ Superset │ │   │  │  Spark History │  │   │  │  HMS (Thrift :9083)      │  │          ║
║  │  │  (BI/Viz)│ │   │  │    Server      │  │   │  │  HiveServer2 (:10000)    │  │          ║
║  │  └──────────┘ │   │  └────────────────┘  │   │  │                         │  │          ║
║  └───────────────┘   └──────────────────────┘   │  │  Drivers (in image):    │  │          ║
║                                                  │  │   postgresql-42.6.0.jar │  │          ║
║                                                  │  │   hadoop-aws-3.4.1.jar  │  │          ║
║                                                  │  │   aws-sdk-1.12.367.jar  │  │          ║
║                                                  │  └──────────┬──────────────┘  │          ║
║                                                  │             │ reads/writes     │          ║
║                                                  │             ▼                  │          ║
║                                                  │  ┌─────────────────────────┐  │          ║
║                                                  │  │   StarRocks (OLAP)      │  │          ║
║                                                  │  │   Delta Native Catalog  │  │          ║
║                                                  │  │   reads MinIO directly  │  │          ║
║                                                  │  └─────────────────────────┘  │          ║
║                                                  └───────────────────────────────┘          ║
║                                                                                              ║
║  ┌───────────────────────────────────────────────────────────────────────────────────────┐  ║
║  │                        DATA & PERSISTENCE LAYER                                       │  ║
║  │                                                                                       │  ║
║  │  ns: default                                                                          │  ║
║  │                                                                                       │  ║
║  │  ┌──────────────────────────┐   ┌────────────────────────┐   ┌──────────────────┐    │  ║
║  │  │        MinIO             │   │      PostgreSQL         │   │      Redis        │    │  ║
║  │  │  (S3-compatible)         │   │  (metadata backbone)   │   │  (Superset cache) │    │  ║
║  │  │                          │   │                        │   └──────────────────┘    │  ║
║  │  │  Buckets:                │   │  Databases:            │                           │  ║
║  │  │  ├── spark-data/         │   │  ├── airflow_db        │   Storage: OpenEBS        │  ║
║  │  │  ├── delta-lake/         │   │  ├── superset_db       │   (hostpath dynamic       │  ║
║  │  │  ├── warehouse/          │   │  └── hive_metastore    │    provisioner on each    │  ║
║  │  │  └── checkpoints/        │   │                        │    node)                  │  ║
║  │  └──────────────────────────┘   └────────────────────────┘                           │  ║
║  └───────────────────────────────────────────────────────────────────────────────────────┘  ║
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

NAMESPACE MAP

  ┌─────────────────┬──────────────────────────────────────────────────────────────────┐
  │ Namespace       │ Workloads                                                        │
  ├─────────────────┼──────────────────────────────────────────────────────────────────┤
  │ cloudflare      │ cloudflared (3 pods, HA tunnel)                                  │
  │ kube-system     │ Traefik, Cilium, CoreDNS, MetalLB                               │
  │ default         │ Airflow, JupyterHub, Marimo, Superset, Spark Connect,            │
  │                 │ Spark History, Hive Metastore, StarRocks, MinIO, PostgreSQL,     │
  │                 │ Redis, airflow-git-sync                                           │
  │ monitoring      │ Prometheus Operator, Grafana, Loki, Alertmanager                 │
  │ spark-operator  │ Spark Operator controller                                        │
  │ headlamp        │ Headlamp UI (cluster dashboard)                                  │
  └─────────────────┴──────────────────────────────────────────────────────────────────┘


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CUSTOM DOCKER IMAGES (all multi-arch: linux/amd64 + linux/arm64)

  subhodeep2022/spark-bigdata:hive-4.1.0-custom-prod
      └── apache/hive:4.1.0  (UBI9-minimal, JRE 21)
          ├── postgresql-42.6.0.jar
          ├── hadoop-aws-3.4.1.jar
          └── aws-java-sdk-bundle-1.12.367.jar

  subhodeep2022/spark-bigdata:spark-4.1.1-uc-0.3.1-v8-sedona-h3
      └── eclipse-temurin:17-jdk-jammy
          ├── Spark 4.1.1 + Delta 4.0.1
          ├── hadoop-aws-3.4.1.jar + aws-sdk-v2-bundle-2.29.52.jar
          ├── Unity Catalog 0.3.1
          ├── Iceberg 1.10.0
          ├── Apache Sedona 1.8.1  (geospatial)
          ├── H3 4.0.1             (spatial indexing)
          └── Python 3.11 + pandas + pyarrow + numpy

  subhodeep2022/spark-bigdata:jupyterhub-4.0.7-pyspark-scala-sql-prod-v2
      └── JupyterHub 4.0.7
          ├── Apache Toree (Scala kernel)
          ├── PySpark + SQL magic
          └── z.show() Zeppelin-style display

  subhodeep2022/spark-bigdata:marimo-v1
      └── Marimo (reactive Python notebooks)

  subhodeep2022/k8s-git-sync:v2-prod
      └── Git-sync sidecar for Airflow DAG repository


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CI/CD PIPELINE (GitHub Actions)

  git push to main
      │
      │  changed file detected by paths: filter
      ▼
  .github/workflows/docker-build.yml
      │
      ├── detect-changes job  (git diff --name-only)
      │       │
      │       ├── docker/hive/Dockerfile changed?        ──►  hive job
      │       ├── docker/spark/Dockerfile changed?       ──►  spark job
      │       ├── docker/jupyterhub/Dockerfile changed?  ──►  jupyterhub job
      │       ├── docker/marimo/Dockerfile changed?      ──►  marimo job
      │       └── docker/k8s-git-sync/Dockerfile changed?──► k8s-git-sync job
      │
      └── each build job:
              │
              ├── actions/checkout@v4
              ├── docker/setup-qemu-action@v3     (arm64 emulation)
              ├── docker/setup-buildx-action@v3
              ├── docker/login-action@v3           (DOCKERHUB_TOKEN secret)
              └── docker/build-push-action@v6
                      platforms: linux/amd64, linux/arm64
                      cache:     type=gha
                      push:      true  →  Docker Hub
```
