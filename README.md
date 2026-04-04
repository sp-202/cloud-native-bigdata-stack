# 🚀 Cloud-Native Big Data Platform on Kubernetes (Raw K8s / AWS EKS)

[![Version](https://img.shields.io/badge/version-0.5.1-blue)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-production--beta-success)](README.md#-project-status)
[![Docker Build](https://github.com/sp-202/cloud-native-bigdata-stack/actions/workflows/docker-build.yml/badge.svg)](https://github.com/sp-202/cloud-native-bigdata-stack/actions/workflows/docker-build.yml)

> An enterprise-grade, cloud-native orchestration framework for distributed big data workloads. Built on self-managed Kubernetes (kubeadm) on AWS EC2 with **Cilium CNI**, this platform provides a decoupled, elastic environment for **Apache Spark**, **Delta Lake**, and **Airflow**, featuring a unified suite of modern interactive notebook environments.

---

👉 **[View the v0.3.0 Changelog](CHANGELOG.md)** | **[Release Notes](RELEASES.md)**



## 📖 Introduction
This repository contains a **Data Platform as Code (DPaC)** implementation, designed to modernize distributed computing by enforcing a strict separation of compute and storage. Leveraging Kubernetes as the primary orchestration plane, the platform eliminates infrastructure silos, enabling teams to deploy and scale production-ready data ecosystems elastically.

### Architectural Core Principles:
*   **Decoupled Compute/Storage**: Persistence is offloaded to S3-compatible object storage (MinIO), allowing compute resources (Spark Executors) to remain ephemeral and cost-efficient.
*   **GitOps-Centric Design**: Every component, from networking routes to database schemas, is defined as declarative Kubernetes manifests for reproducible deployments. Docker images are built and pushed automatically via GitHub Actions CI/CD on every Dockerfile change.
*   **Zero-Trust Ingress**: External access is routed through Cloudflare Tunnel (`cloudflared`) — no inbound firewall ports needed. Traefik runs as a pure internal `ClusterIP` service.
*   **High Observability**: Integrated telemetry across the stack provides deep visibility into job performance, resource utilization, and system health.

---

## 🚦 Project Status

| Feature               | Status       | Notes                                           |
| :-------------------- | :----------- | :---------------------------------------------- |
| **JupyterHub / Spark** | ✅ Stable    | Core interactive environment                   |
| **Spark Connect**      | ✅ Stable    | Shared Spark gateway for all clients           |
| **Delta Lake**         | ✅ Stable    | ACID transactions and Time Travel on S3        |
| **Hive Metastore**     | ✅ Stable    | Centralized metadata management (Thrift) — Hive 4.1.0 |
| **Cilium CNI**         | ✅ Stable    | AWS ENI IPAM mode for native VPC networking    |
| **StarRocks**          | ✅ Stable      | Verified with Native Delta Catalog (OLAP)      |
| **Airflow + Git-Sync** | ✅ Stable      | DAGs auto-synced from Git repository           |
| **Umbrella Chart**     | ✅ Stable      | Unified Helm-based GitOps deployment           |
| **ArgoCD Sync Waves**  | ✅ Stable      | Controlled infrastructure orchestration        |

---

## 🏗 Architecture & Components

The platform is managed as a unified **Helm Umbrella Chart** in `big-data-platform/`.

### 1️⃣ Ingress & Networking
*   **Cilium CNI**: Pod networking with AWS ENI IPAM mode. Pods receive real VPC IPs for full AWS compatibility.
*   **MetalLB**: Provides internal network load-balancing.
*   **Cloudflare Tunnel (`cloudflared`)**: Replaces public LoadBalancer exposure. External traffic is routed securely to Traefik without open inbound ports.
*   **Traefik Proxy**: The unified ingress controller, managed by the `ingress` sub-chart.

### 2️⃣ Big Data Sub-charts
*   **airflow**: Managed workflow orchestration with KubernetesExecutor.
*   **spark-connect**: Shared gateway for all interactive clients.
*   **hive-metastore**: Central metadata catalog (Hive 4.1.0).
*   **starrocks**: High-performance OLAP engine.

### 3️⃣ Infrastructure & Persistence
*   **persistence**: Manages dynamic OpenEBS hostpath storage and static PV/PVCs.
*   **postgres / redis**: Relational and in-memory backends.
*   **minio**: S3-compatible data lake storage.

---

## ⚡ Deployment Guide

### Prerequisites
1.  **AWS EC2 Cluster**: K8s 1.28+ on ARM64 nodes.
2.  **ArgoCD**: To leverage the built-in **Sync Wave** orchestration.

### Quick Start
```bash
# Bootstrap the cluster
./deploy-v2.sh

# Deploy via Helm (Umbrella Chart)
helm install platform ./big-data-platform
```

👉 **[Read the Full Deployment Guide](DEPLOYMENT.md)**

---

## 📂 Tech Stack

| Component | Version | Role | Usage |
| :--- | :--- | :--- | :--- |
| **Apache Airflow** | `2.10.x` | Orchestrator | Scheduling ETL pipelines |
| **Spark / Delta** | `4.1.1 / 4.0.1` | Compute / Format | Distributed processing & ACID tables |
| **Hadoop / AWS SDK** | `3.4.1 / v2.29.52` | Storage Access | S3A FileSystem optimizations (AWS SDK v2) |
| **JupyterHub** | `4.0.7` | Notebooks | Standard Data Engineering workflow |
| **Marimo / Polynote** | `latest` | Notebooks | Reactive & Multi-language environments |
| **Hive Metastore** | `4.1.0` | Catalog | Metadata persistence (arm64 native, JDK 17+) |
| **StarRocks** | `v3.x` | OLAP Database | Sub-second queries on large datasets |
| **Apache Superset** | `4.0.x` | BI / Viz | Dashboards & Analytics |
| **MinIO** | `RELEASE.2024` | Object Store | Data Lake (S3 API) |
| **Traefik / Kong** | `v2.10 / v3.x` | Ingress/API Gateway | Load Balancing & Service Routing |
| **Prometheus / Loki** | `Custom Helm` | Observability | Metrics & Centralized Logging |
| **Grafana** | `latest` | Dashboards | Visualizing cluster health & job metrics |

---

## ⚡ Deployment Guide

### Prerequisites
1.  **AWS EC2 Cluster**: Self-managed Kubernetes via `kubeadm` on EC2 instances (ARM64 Graviton recommended).
2.  **Tools**: `kubectl`, `helm` installed locally.
3.  **Permissions**: Admin access to the cluster (`KUBECONFIG` configured).

### Step 1: Clone & Configure
```bash
git clone https://github.com/your-repo/k8s-big-data-platform.git
cd k8s-big-data-platform
```

### Step 2: Build Custom Images (Crucial)
The platform uses optimized images for notebooks and executors. Build and push them to your registry. If you want to customize these images (e.g. adding specific spark dependencies or Python libraries), explore and modify the Dockerfiles within the `docker/` folder before running these scripts:
```bash
# Hive Metastore (arm64-native, Hive 4.1.0)
docker/hive/build.sh

# Spark Executor & Driver Base
docker/spark/build.sh

# User Interfaces
docker/jupyterhub/build.sh
docker/marimo/build.sh
```

> [!TIP]
> **CI/CD Auto-Build**: Any push to `main` that modifies a `docker/*/Dockerfile` will automatically trigger a multi-arch (`linux/amd64` + `linux/arm64`) build and push via GitHub Actions. You only need to run these scripts manually for local testing. See [`.github/workflows/docker-build.yml`](.github/workflows/docker-build.yml).

### Step 3: Deploy Platform
Run the main deployment script. This automation handles namespace creation, CRD installation, and Helm chart deployments.
```bash
chmod +x deploy-v2.sh
./deploy-v2.sh
```
*Wait for the script to complete. It may take 5-10 minutes for the LoadBalancer IP to provision.*

### Step 3: Access Services
The script will output the dynamic URLs for your services. The base domain `$INGRESS_DOMAIN` is constructed automatically using the LoadBalancer IP (e.g., `44.203.26.241.sslip.io`).

| Service | URL Pattern | Default Credentials |
| :--- | :--- | :--- |
| **Airflow** | `http://airflow.<INGRESS_DOMAIN>` | `admin` / `admin` |
| **JupyterHub** | `http://jupyterhub.<INGRESS_DOMAIN>` | No token (Dev Mode) |
| **Superset** | `http://superset.<INGRESS_DOMAIN>` | `admin` / `admin` |
| **Minio** | `http://minio.<INGRESS_DOMAIN>` | `minioadmin` / `minioadmin` |
| **Grafana** | `http://grafana.<INGRESS_DOMAIN>` | `admin` / `prom-operator` |
| **Spark UI** | `http://spark.<INGRESS_DOMAIN>` | - |
| **Spark History** | `http://spark-history.<INGRESS_DOMAIN>` | - |
| **Hubble UI** | `http://hubble.<INGRESS_DOMAIN>` | - |
| **Headlamp UI** | `http://headlamp.<INGRESS_DOMAIN>` | See token below |

### Headlamp Cluster Admin Token

Generate a token for Headlamp UI access:

```bash
# One-time setup: Create admin-user service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: default
EOF

# Generate token (GKE limits to 48h max)
kubectl create token admin-user -n default --duration=48h
```

Copy the output token and paste it into the Headlamp login page.

---

## 📊 Observability

The platform comes with a pre-configured monitoring stack:
*   **Prometheus Operator**: Automatically scrapes metrics from Spark applications and system components.
*   **ServiceMonitors**: Defines <i>what</i> to monitor (Spark Driver/Executors, Airflow scheduler, Nodes).
*   **Grafana Dashboards**: Custom JSON dashboards are provided to visualize:
    *   JVM Heap usage
    *   Active Tasks / Executors
    *   CPU/Memory saturation

👉 **[Read the Full Monitoring Guide](MONITORING_GUIDE.md)**

---

## 🔌 Connecting to Data (Superset)

Superset is pre-connected to the internal Postgres and Hive Metastore.
*   **To query Data Lake files**: Use the Hive connector.
*   **To query Metadata**: Use the Postgres connector.

👉 **[Read the Superset Connection Guide](SUPERSET_CONNECTION_GUIDE.md)**

---

## 📂 Repository Structure
```bash
├── big-data-platform/        # Main Helm Umbrella Chart (The source of truth)
│   ├── charts/               # Modular sub-charts (minio, postgres, airflow, etc.)
│   ├── values.yaml           # Centralized configuration
│   └── README.md             # Sub-chart documentation index
├── docker/                   # Custom image Dockerfiles
├── deploy-v2.sh              # Cluster bootstrap script
├── ARCHITECTURE.md           # Technical deep-dive & diagrams
├── CHANGELOG.md              # Detailed version history
├── ISSUES.md                 # Troubleshooting log & fixes
└── README.md                 # Entry point (this file)
```

---

## 📚 Documentation & References

| Document | Description |
| :--- | :--- |
| **[Changelog](CHANGELOG.md)** | Version history with detailed changes per release |
| **[Issues & Resolutions](ISSUES.md)** | Troubleshooting log of known bugs and fixes |
| **[Deployment Guide](DEPLOYMENT.md)** | Step-by-step installation instructions |
| **[JupyterHub Guide](JUPYTERHUB_GUIDE.md)** | PySpark jobs and executor configuration |
| **[Monitoring Guide](MONITORING_GUIDE.md)** | Prometheus, Grafana, and Loki setup |
| **[Superset Connection](SUPERSET_CONNECTION_GUIDE.md)** | BI tool data source connections |
| **[Lakehouse Architecture](LAKEHOUSE_README.md)** | HMS + StarRocks + Spark architecture |
| **[Docker Images](docker/README.md)** | Build, customize, and version Docker images |
| **[Platform Docs](docs/README.md)** | Full documentation index |

## 🔧 Manual DAG Deployment (Bypass Git-Sync)

For rapid development and testing, you can bypass the Git synchronizer and manually upload DAGs directly to the cluster. This is useful when you want to test changes immediately without committing to the repository.

### 1. Identify the Git-Sync Pod
The `airflow-git-sync` pod has write access to the DAGs volume.

```bash
kubectl get pods -n default -l app=airflow-git-sync
# Example Output: airflow-git-sync-5669c94965-t52rx
```

### 2. Upload Files
Use `kubectl exec` to pipe file contents directly to the pod (this bypasses some read-only/ownership issues with `kubectl cp`).

**Syntax:**
```bash
cat <local-file> | kubectl exec -i -n default <git-sync-pod-name> -- tee /dags/repo/dags/<filename> > /dev/null
```

**Example:**
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

The `spark-production-defaults` ConfigMap provides global defaults for all Spark applications. When you make changes to `production-spark-defaults.conf`, you must sync them to the cluster:

```bash
# Update ConfigMap from local file
kubectl create configmap spark-production-defaults --from-file=spark-defaults.conf=production-spark-defaults.conf --dry-run=client -o yaml | kubectl apply -f -
```

