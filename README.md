# 🚀 Cloud-Native Big Data Platform on Kubernetes (GKE)

> A production-grade, scalable Big Data stack featuring **Spark 3.5**, **Airflow 2.x**, **Zeppelin**, and **Superset**, optimized for Google Kubernetes Engine (GKE).

## 🏗 Architecture
This platform is architected for **statelessness**, **scalability**, and **cost-efficiency**.

*   **Split Architecture**: Infrastructure (Data/PVCs) is separated from Applications (Stateless).
*   **Dynamic Resources**: Spark Executors are spawned on-demand by the Spark Operator.
*   **Cloud-Native Storage**: Uses Standard (HDD) Persistent Disks for cost-effective storage of Metastore/Postgres data, and S3/MinIO for object storage.
*   **Unified Ingress**: Single LoadBalancer entrypoint via Traefik.

## 🛠 Tech Stack

| Component | Role | Version |
| :--- | :--- | :--- |
| **Orchestration** | **Apache Airflow** | 2.x |
| **Compute** | **Apache Spark** | 3.5 |
| **Interactive** | **Apache Zeppelin** | 0.11 |
| **Analytics** | **Apache Superset** | Latest |
| **Storage** | **MinIO** (S3 Compatible) | Latest |
| **Ingress** | **Traefik** | v3 |
| **Monitoring** | **Prometheus & Grafana** | Kube-Prometheus-Stack |

## ⚡ Deployment Guide (GKE)

### Prerequisites
*   Google Kubernetes Engine (GKE) Cluster (Standard or Autopilot)
*   `kubectl` connected to the cluster
*   `helm` installed (Required: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`)

### Quick Start
Run the unified deployment script. This script handles:
1.  **Infrastructure**: Traefik, Spark Operator, Prometheus CRDs.
2.  **Dynamic Config**: Auto-detects LoadBalancer IP and updates Ingress/Grafana configs.
3.  **Applications**: Deploys the full V2 stack.

```bash
./deploy-gke.sh
```

### Accessing Services
After deployment, the script provides a list of URLs (using `sslip.io` DNS mapping).

| Service | Protocol | Default URL Pattern |
| :--- | :--- | :--- |
| **Traefik Dashboard** | HTTP | `traefik.<LB_IP>.sslip.io/dashboard/` |
| **Airflow** | HTTP | `airflow.<LB_IP>.sslip.io` |
| **Superset** | HTTP | `superset.<LB_IP>.sslip.io` |
| **Zeppelin** | HTTP | `zeppelin.<LB_IP>.sslip.io` |
| **Grafana** | HTTP | `grafana.<LB_IP>.sslip.io` |
| **K8s Dashboard** | HTTP | `dashboard.<LB_IP>.sslip.io` |

## 📁 Repository Structure

*   `deploy-gke.sh`: Main deployment automation script.
*   `k8s-platform-v2/`: Core Kubernetes manifests (Kustomize).
    *   `00-core/`: Namespaces, PVCs (Storage).
    *   `01-networking/`: Ingress Routes, Traefik config.
    *   `02-database/`: Postgres, MinIO.
    *   `03-apps/`: Airflow, Superset, Zeppelin, Spark.
    *   `05-monitoring/`: Prometheus, Grafana, K8s Dashboard.
*   `archive/`: Legacy V1 components and deprecated scripts.
*   `docs/`: Detailed architectural documentation.

## 📚 Documentation
*   **[Deployment Guide](DEPLOYMENT.md)**
*   **[Monitoring Guide](MONITORING_GUIDE.md)**
