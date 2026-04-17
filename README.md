# 🚀 Cloud-Native Big Data Platform on Kubernetes (AWS EKS / Self-Managed)

[![Version](https://img.shields.io/badge/version-1.0.1-blue)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-production-success)](README.md#-project-status)
[![Docker Build](https://github.com/sp-202/cloud-native-bigdata-stack/actions/workflows/docker-build.yml/badge.svg)](https://github.com/sp-202/cloud-native-bigdata-stack/actions/workflows/docker-build.yml)

> An enterprise-grade, cloud-native orchestration framework for distributed big data workloads. Built on **Amazon EKS** utilizing **self-managed node groups** with **AWS Auto Scaling Groups (ASG)** and **Cilium CNI**, this platform provides a decoupled, elastic environment for **Apache Spark**, **Apache Iceberg**, and **Airflow**, powered by **Apache Gravitino** as the unified metadata catalog.

---

👉 **[View the v1.0.1 Changelog](CHANGELOG.md)** | **[Release Notes](RELEASES.md)** | **[Architecture](ARCHITECTURE.md)**

## 📖 Introduction

This repository contains a **Data Platform as Code (DPaC)** implementation, designed to modernize distributed computing by enforcing strict separation of compute and storage. Built on **Apache Iceberg** as the primary table format and **Apache Gravitino** for unified metadata governance, the platform leverages Kubernetes as the primary orchestration plane, eliminating infrastructure silos and enabling teams to deploy and scale production-ready data ecosystems elastically.

### Architectural Core Principles:

*   **Decoupled Compute/Storage**: Persistence is offloaded to S3-compatible object storage (MinIO) using Apache Iceberg as the primary table format, allowing compute resources (Spark Executors) to remain ephemeral and cost-efficient.
*   **Unified Metadata via Gravitino**: Apache Gravitino 1.2.0 serves as the primary metadata lake with native Iceberg REST Catalog, enabling seamless table discovery and governance across the platform.
*   **GitOps-Centric Design**: Every component, from networking routes to database schemas, is defined as declarative Kubernetes manifests for reproducible deployments. Docker images are built and pushed automatically via GitHub Actions CI/CD on every Dockerfile change.
*   **Zero-Trust Ingress**: External access is routed through **Cloudflare Tunnel** (`cloudflared`) — no inbound firewall ports needed. Traefik runs as a pure internal `ClusterIP` service with encrypted outbound-only tunnels.
*   **High Observability**: Integrated telemetry across the stack provides deep visibility into job performance, resource utilization, and system health.

---

## 🚦 Project Status

| Feature               | Status       | Notes                                           |
| :-------------------- | :----------- | :---------------------------------------------- |
| **JupyterHub / Spark** | ✅ Stable    | Core interactive environment with Spark 3.5.8  |
| **Spark Connect**      | ✅ Stable    | Shared Spark gateway for all clients           |
| **Apache Iceberg**     | ✅ Stable    | Primary table format with ACID & Time Travel   |
| **Gravitino Catalog**  | ✅ Stable    | Unified metadata lake with Iceberg REST (primary) — v1.2.0 |
| **Cilium CNI**         | ✅ Stable    | AWS ENI IPAM mode for native VPC networking    |
| **StarRocks**          | ✅ Stable    | Native Iceberg queries via Gravitino IRC       |
| **Airflow + Git-Sync** | ✅ Stable    | DAGs auto-synced from Git repository           |
| **Umbrella Chart**     | ✅ Stable    | Unified Helm-based GitOps deployment           |
| **ArgoCD Sync Waves**  | ✅ Stable    | Controlled infrastructure orchestration        |

---

## 🏗 Architecture & Components

The platform is managed as a unified **Helm Umbrella Chart** in `big-data-platform/`.

### 1️⃣ Ingress & Networking
*   **Cilium CNI**: Pod networking with AWS ENI IPAM mode. Pods receive real VPC IPs for full AWS compatibility.
*   **Cloudflare Tunnel (`cloudflared`)**: Zero-trust secure tunnel providing external access. No inbound firewall ports (80/443) needed on EC2 instances.
*   **Traefik Proxy**: The unified ingress controller (ClusterIP service), managed by the `ingress` sub-chart. Routes internal traffic to all services.

### 2️⃣ Big Data & Metadata Sub-charts
*   **spark-connect**: Shared Spark gateway for all interactive clients (JupyterHub, Airflow, Marimo).
*   **gravitino**: **Primary metadata lake** with Iceberg REST Catalog (IRC) for unified governance.
*   **airflow**: Managed workflow orchestration with KubernetesExecutor and Git-Sync DAG auto-deployment.
*   **starrocks**: High-performance OLAP engine querying Iceberg tables via Gravitino IRC.

### 3️⃣ Infrastructure & Persistence
*   **persistence**: Manages dynamic OpenEBS hostpath storage and static PV/PVCs.
*   **postgres**: Relational database for Airflow, Superset, and Gravitino metadata.
*   **redis**: In-memory cache for Superset.
*   **minio**: S3-compatible data lake storage (MinIO, not AWS S3).

---

## ⚡ Deployment Guide

### Prerequisites
1.  **AWS EC2 Cluster**: Kubernetes 1.28+ on ARM64 (Graviton) nodes recommended.
2.  **ArgoCD**: Pre-installed for sync wave orchestration.
3.  **Cloudflare Account**: For tunnel configuration (optional; can use direct LoadBalancer).

### Quick Start
```bash
# 1. Bootstrap the cluster
./deploy-v2.sh

# 2. Deploy via Helm (Umbrella Chart)
helm install big-data-platform ./big-data-platform -f big-data-platform/values.yaml

# 3. Monitor deployment via ArgoCD
argocd app get big-data-platform
```

👉 **[Read the Full Deployment Guide](DEPLOYMENT.md)**

---

## 📂 Tech Stack

| Component | Version | Role | Notes |
| :--- | :--- | :--- | :--- |
| **Apache Spark** | `3.5.8` | Distributed Computing | Primary compute engine with GravitinoSparkPlugin |
| **Apache Iceberg** | `1.10.1` | Table Format | Primary format with ACID, time travel, Z-ordering |
| **Apache Gravitino** | `1.2.0` | Metadata Catalog | Unified metadata lake with Iceberg REST (IRC) |
| **Apache Airflow** | `2.10.x` | Orchestration | Workflow scheduling with KubernetesExecutor |
| **StarRocks** | `v3.x` | OLAP Database | Sub-second queries on Iceberg tables |
| **JupyterHub** | `4.0.7` | Notebooks | Multi-user interactive environment |
| **Marimo / Polynote** | `latest` | Notebooks | Reactive & multi-language alternatives |
| **Apache Superset** | `4.0.x` | BI / Visualization | Dashboard & analytics platform |
| **MinIO** | `RELEASE.2024` | Object Store | S3-compatible data lake (not AWS S3) |
| **PostgreSQL** | `latest` | Metadata DB | Backend for Airflow, Superset, Gravitino |
| **Redis** | `latest` | Cache | Session/query cache for Superset |
| **Cilium** | `AWS ENI IPAM` | CNI | Native VPC networking for pods |
| **Traefik** | `v2.10` | Ingress | Internal ClusterIP routing |
| **Cloudflare Tunnel** | `cloudflared` | Zero-Trust Ingress | External access without inbound ports |
| **Prometheus / Loki** | `Custom Helm` | Observability | Metrics & centralized logging |
| **Grafana** | `latest` | Dashboards | Cluster health & job metrics visualization |

---

## 📊 Observability

The platform comes with a pre-configured monitoring stack:

*   **Prometheus Operator**: Automatically scrapes metrics from Spark applications and system components.
*   **ServiceMonitors**: Defines what to monitor (Spark Driver/Executors, Airflow scheduler, Nodes).
*   **Grafana Dashboards**: Custom JSON dashboards for:
    *   JVM Heap usage and GC metrics
    *   Active Tasks / Executors
    *   CPU/Memory saturation
    *   Spark job completion rates

👉 **[Read the Full Monitoring Guide](MONITORING_GUIDE.md)**

---

## 🔌 Connecting to Data (Superset)

Superset is pre-connected to **Gravitino** and **PostgreSQL**:

*   **To query Iceberg tables**: Create a catalog connection to Gravitino API (`http://gravitino.default.svc.cluster.local:8090`)
*   **To query StarRocks**: Add a native StarRocks connection
*   **To query metadata**: Use the PostgreSQL connector

👉 **[Read the Superset Connection Guide](SUPERSET_CONNECTION_GUIDE.md)**

---

## 📂 Repository Structure

```bash
├── big-data-platform/        # Main Helm Umbrella Chart (source of truth)
│   ├── charts/               # Modular sub-charts (gravitino, minio, postgres, airflow, etc.)
│   ├── values.yaml           # Centralized configuration for all components
│   └── README.md             # Sub-chart documentation index
├── docker/                   # Custom image Dockerfiles (Spark, JupyterHub, etc.)
├── deploy-v2.sh              # Cluster bootstrap script (AWS EKS self-managed setup)
├── ARCHITECTURE.md           # Technical deep-dive with data flow diagrams
├── CHANGELOG.md              # Version history with detailed changes
├── ISSUES.md                 # Troubleshooting & known issues
└── README.md                 # Entry point (this file)
```

---

## 📚 Documentation & References

| Document | Description |
| :--- | :--- |
| **[Changelog](CHANGELOG.md)** | Version history with detailed changes per release |
| **[Release Notes](RELEASES.md)** | Release highlights and upgrade paths |
| **[Architecture](ARCHITECTURE.md)** | Technical deep-dive with data flows and topology |
| **[Deployment Guide](DEPLOYMENT.md)** | Step-by-step installation instructions |
| **[Debug Guide](DEBUG_GUIDE.md)** | Step-by-step debugging procedures and diagnostics |
| **[Issues & Resolutions](ISSUES.md)** | Troubleshooting log of known bugs and fixes |
| **[JupyterHub Guide](JUPYTERHUB_GUIDE.md)** | PySpark jobs and executor configuration |
| **[Monitoring Guide](MONITORING_GUIDE.md)** | Prometheus, Grafana, and Loki setup |
| **[Superset Connection](SUPERSET_CONNECTION_GUIDE.md)** | Gravitino + StarRocks data source setup |
| **[Lakehouse Architecture](LAKEHOUSE_README.md)** | Gravitino + StarRocks + Spark architecture |
| **[Docker Images](docker/README.md)** | Build, customize, and version Docker images |
| **[Platform Docs](docs/README.md)** | Full documentation index |

---

## 🔧 Manual DAG Deployment (Bypass Git-Sync)

For rapid development and testing, you can bypass the Git synchronizer and manually upload DAGs directly to the cluster.

### 1. Identify the Git-Sync Pod
```bash
kubectl get pods -n default -l app=airflow-git-sync
# Example Output: airflow-git-sync-5669c94965-t52rx
```

### 2. Upload Files
Use `kubectl exec` to pipe file contents directly to the pod:

**Syntax:**
```bash
cat <local-file> | kubectl exec -i -n default <git-sync-pod-name> -- tee /dags/repo/dags/<filename> > /dev/null
```

**Examples:**
```bash
# Upload DAG file
cat airflow-dags/dags/my_dag.py | kubectl exec -i -n default airflow-git-sync-5669c94965-t52rx -- tee /dags/repo/dags/my_dag.py > /dev/null

# Upload Spark Manifest
cat airflow-dags/dags/my_manifest.yaml | kubectl exec -i -n default airflow-git-sync-5669c94965-t52rx -- tee /dags/repo/dags/my_manifest.yaml > /dev/null
```

> [!WARNING]
> Changes made this way are **ephemeral** and will be overwritten the next time the Git-Sync sidecar pulls from the remote repository. Always commit your final changes to Git.

---

## 🔧 Spark Configuration Management

The `spark-production-defaults` ConfigMap provides global defaults for all Spark applications. When you make changes to Spark configuration, update the cluster:

```bash
# Update ConfigMap from local file
kubectl create configmap spark-production-defaults --from-file=spark-defaults.conf=production-spark-defaults.conf --dry-run=client -o yaml | kubectl apply -f -
```

### Key Spark Settings

All Spark jobs automatically use:
- **Gravitino Plugin**: For dynamic catalog discovery and multi-catalog support
- **Iceberg Format**: Default table format with ACID transactions
- **MinIO S3**: For data lake storage (S3-compatible, not AWS S3)
- **Executor Auto-Scaling**: Spark Operator manages dynamic executor scaling

---

## 🌐 Key Features

### ✨ Gravitino-Powered Unified Metadata
- Single API endpoint for all catalog operations
- Automatic table discovery across multiple catalog types
- Web UI for table browsing and governance
- Iceberg REST Catalog for downstream systems (StarRocks, etc.)

### ⚡ Spark 3.5.8 with Iceberg
- Native Iceberg support with Z-ordering and partition evolution
- GravitinoSparkPlugin for automatic catalog resolution
- Multi-catalog access from single Spark session
- Optimized for both batch and streaming workloads

### 🔄 StarRocks OLAP Integration
- Direct Iceberg table access via Gravitino IRC
- Sub-second query performance on data lake
- No Hive Metastore middleware
- Simplified architecture with unified governance

### 🔒 Zero-Trust Security
- Cloudflare Tunnel for external access (no inbound ports)
- Cilium CNI with AWS ENI IPAM for native VPC integration
- Pod-to-pod encryption and network policies
- No LoadBalancer exposure

### 🚀 Complete CI/CD Integration
- GitHub Actions for automated multi-arch Docker builds
- GitOps-driven deployment via ArgoCD
- Declarative infrastructure as code
- Automated sync waves for dependency ordering

---

## 📋 Known Limitations (v1.0.1)

| Limitation | Workaround | Status |
|-----------|-----------|--------|
| **Single Spark Connect Replica** | Deploy multiple replicas manually | Planned for v1.1.0 |
| **Single-Region Only** | Multi-region support in roadmap | Planned for v1.1.0 |
| **Superset Password** | Change `CHANGE_ME_STRONG_PASSWORD` in values.yaml | Manual (pre-deploy) |
| **Gravitino HA** | Single replica, no replication | Planned for v1.1.0 |

---

## 🔮 Roadmap for v1.1.0

- [ ] Gravitino High Availability (HA replicas)
- [ ] Spark Connect Server High Availability
- [ ] Multi-region federation support
- [ ] Advanced catalog governance policies
- [ ] Cost optimization analytics dashboard
- [ ] Enterprise LDAP/SAML integration

---

## 👥 Contributors & Acknowledgments

- **Subhodeep Pal** — Platform architecture & core implementation
- **Claude (Anthropic)** — Documentation, debugging, and issue resolution
- **AWS Community** — Guidance on EKS, Cilium, and Graviton optimization
- **Apache Spark, Iceberg, and Gravitino Teams** — Excellent open-source foundation

---

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

For questions or issues, please open a GitHub issue or contact the maintainers.
