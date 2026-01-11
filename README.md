# 🚀 Cloud-Native Big Data Platform on Kubernetes (GKE)

[![Version](https://img.shields.io/badge/version-0.1.0--beta-blue)](RELEASES.md)
[![Status](https://img.shields.io/badge/status-initial--beta-success)](README.md#🚦-project-status)

> A production-grade, scalable, and fully containerized Big Data stack featuring **Apache Spark 3.5**, **Airflow 2.x**, **JupyterHub**, and **Superset**, optimized for Google Kubernetes Engine (GKE).

---

👉 **[View the v0.1.0 Release Notes](RELEASES.md)**

![Architecture Diagram](k8s_diagram.drawio.svg)

## 📖 Introduction
This project provides a complete, deployable **Data Platform as Code**. It leverages the power of Kubernetes to orchestrate a modern data stack that separates compute from storage, enabling high scalability and cost efficiency.

Traditionally, big data clusters (like Hadoop/YARN) requires always-on infrastructure. This platform moves to a **Cloud-Native** paradigm:
*   **Ephemeral Compute**: Spark executors are spun up only when needed (via Spark on K8s Operator).
*   **Persistent Storage**: Data resides in Object Storage (MinIO/S3) and decoupled databases (Postgres), not on the compute nodes themselves.
*   **GitOps Ready**: All configurations are defined in declarative Kubernetes manifests.

---

## 🚦 Project Status

| Feature               | Status       | Notes                                           |
| :-------------------- | :----------- | :---------------------------------------------- |
| **JupyterHub / Spark** | ✅ Stable    | Core interactive environment                   |
| **Marimo Notebooks**   | ✅ Stable    | Reactive Python UI integration                 |
| **Delta Lake**         | ✅ Stable    | ACID transactions and Time Travel on S3        |
| **Airflow Scheduling** | 🏗 Beta      | Functional, standard DAG patterns only          |
| **Monitoring Stack**   | 🏗 Beta      | Metrics flowing; Grafana dashboards maturing   |
| **Polynote**           | 🧪 Exp       | High resource usage; testing stability         |
| **Unity Catalog (UC)** | 🧪 Exp       | Integration in progress; not fully active      |
| **StarRocks**          | 🧪 Exp       | Base manifests in place; awaiting verification |

> [!IMPORTANT]
> Features marked as **Experimental (🧪 Exp)** are currently in the development phase. They may have incomplete functionality or require additional configuration.

---

## 🏗 Architecture & Components

The platform is divided into three logical domains:

### 1️⃣ Ingress & Networking (Orange Domain)
*   **Traefik Proxy (v2/v3)**: The unified ingress controller. It handles all external traffic on ports `80` (HTTP) and `443` (HTTPS) and routes it to internal services based on hostnames (e.g., `airflow.example.com`).
*   **SSLP/NIP.IO**: Automatic DNS resolution for LoadBalancer IPs to simplify local development and testing.

### 2️⃣ Application Layer (Blue Domain)
*   **Apache Airflow (2.x)**: The workflow orchestrator. It schedules DAGs that trigger Spark jobs, move data, and manage dependencies. configured with the **KubernetesExecutor** for scaling tasks.
*   **Notebook Suite**: 
    *   **JupyterHub**: Standard interactive environment with **Zeppelin features** (SQL magic, Scala kernel, `z.show()`).
    *   **Marimo**: Reactive Python notebooks with high-performance UI components.
    *   **Polynote**: IDE-focused notebook for Scala and multi-language Spark development.
*   **Apache Spark (3.5)**: The distributed compute engine, pre-configured with **Delta Lake** and **Unity Catalog** support.
*   **Apache Superset**: Enterprise-ready BI. Connects to the platform for data visualization.
*   **Hive Metastore**: Central schema catalog for the Data Lake.

### 3️⃣ Data & Persistence (Green Domain)
*   **MinIO**: High-performance Object Storage (S3 Compatible). Acts as the "Data Lake" storage layer.
*   **PostgreSQL**: The relational metadata backbone. Stores state for Airflow (DAG runs), Superset (dashboards), and Hive (schemas).
*   **Redis**: In-memory cache used by Superset to speed up query results and dashboard loading.

---

## � Tech Stack

| Component           | Version        | Role           | Usage                                    |
| :------------------ | :------------- | :------------- | :--------------------------------------- |
| **Apache Airflow**  | `2.10.x`       | Orchestrator   | Scheduling ETL pipelines                 |
| **Spark / Delta**   | `3.5.3 / 3.2.0` | Compute / Format | Distributed processing & ACID tables     |
| **JupyterHub**      | `4.0.7`        | Notebooks      | Standard Data Engineering workflow       |
| **Marimo**          | `latest`       | Notebooks      | Reactive, Python-first exploration       |
| **Polynote**        | `latest`       | Notebooks      | Scala-first IDE-like experience          |
| **Apache Superset** | `4.0.x`        | BI / Viz       | Dashboards & Analytics                   |
| **MinIO**           | `RELEASE.2024` | Object Store   | Data Lake (S3 API)                       |
| **Traefik**         | `v2.10`        | Ingress        | Load Balancing & Routing                 |
| **Monitoring**      | `Prom/Grafana` | Observability  | Visualizing cluster health & job metrics |

---

## ⚡ Deployment Guide

### Prerequisites
1.  **GKE Cluster**: A standard or Autopilot GKE cluster (Recommended: 3+ nodes, e2-standard-4).
2.  **Tools**: `kubectl`, `helm`, `gcloud` installed locally.
3.  **Permissions**: Admin access to the cluster.

### Step 1: Clone & Configure
```bash
git clone https://github.com/your-repo/k8s-big-data-platform.git
cd k8s-big-data-platform
```

### Step 2: Build Custom Images (Crucial)
The platform uses optimized images for notebooks and executors. Build and push them to your registry:
```bash
# Spark Executor & Driver Base
docker/spark/build.sh

# User Interfaces
docker/jupyterhub/build.sh
docker/marimo/build.sh
```

### Step 3: Deploy Platform
Run the main deployment script. This automation handles namespace creation, CRD installation, and Helm chart deployments.
```bash
chmod +x deploy-gke.sh
./deploy-gke.sh
```
*Wait for the script to complete. It may take 5-10 minutes for the LoadBalancer IP to provision.*

### Step 3: Access Services
The script will output the dynamic URLs for your services. They will look like this (where `X.X.X.X` is your LB IP):

| Service      | URL Pattern                                  | Default Credentials       |
| :----------- | :------------------------------------------- | :------------------------ |
| **Airflow**    | `http://airflow.X.X.X.X.sslip.io`            | `admin` / `admin`         |
| **JupyterHub** | `http://jupyterhub.X.X.X.X.sslip.io`         | No token (Dev Mode)       |
| **Marimo**     | `http://marimo.X.X.X.X.sslip.io`             | No token (Dev Mode)       |
| **Polynote**   | `http://polynote.X.X.X.X.sslip.io`           | N/A                       |
| **Superset**   | `http://superset.X.X.X.X.sslip.io`           | `admin` / `admin`         |
| **Grafana**    | `http://grafana.X.X.X.X.sslip.io`            | `admin` / `prom-operator` |
| **K8s Dashboard** | `https://dashboard.X.X.X.X.sslip.io`      | See token below           |

### Kubernetes Dashboard Token

Generate a token for K8s Dashboard access:

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

Copy the output token and paste it into the Dashboard login page.

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

## � Repository Structure
```bash
├── docker/                   # Custom image source code
│   ├── jupyterhub/           # Notebook environment with Spark & Scala
│   ├── marimo/               # Reactive Python notebook
│   └── spark/                # Golden Spark image (v5)
├── deploy-gke.sh             # Main automation script
├── k8s_diagram.drawio.svg    # Architecture Diagram
├── k8s-platform-v2/          # V2 Source of Truth (Kustomize)
│   ├── 00-core/              # Namespaces, StorageClasses, PVCs
│   ├── 01-networking/        # Traefik, IngressRoutes, Domains
│   ├── 02-database/          # Postgres, MinIO (S3), Redis
│   ├── 03-apps/              # Airflow, Notebooks, Superset, Spark
│   └── 05-monitoring/        # Prometheus, Grafana, Loki
├── docs/                     # Detailed technical guides
│   ├── notebooks.md          # Guide: JupyterHub, Marimo, Polynote
│   ├── delta_lake.md         # Guide: ACID tables on S3
│   ├── spark_on_k8s.md       # Deep Dive: Spark Client vs Cluster mode
│   └── airflow.md            # Workflow orchestration
├── MONITORING_GUIDE.md       # Observability instructions
├── README.md                 # Entry point
└── SUPERSET_CONNECTION_GUIDE.md # BI connectivity instructions
```
