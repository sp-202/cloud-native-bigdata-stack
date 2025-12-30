# 🚀 Big Data Platform on Kubernetes

> A production-ready, cloud-native Big Data stack featuring **Spark**, **Airflow**, **Zeppelin**, and **Superset**, optimized for Kubernetes dynamic scaling.

## 🏗 Architecture
This platform is architected for **statelessness** and **scalability**.
*   **Split Architecture**: Infrastructure (Data/PVCs) is separated from Applications (Stateless).
*   **Dynamic Resources**: Spark Executors are spawned on-demand by the Kubernetes Scheduler.
*   **S3-First Design**: All logs, DAGs, and notebooks are stored in MinIO (S3), not on local disks.

```mermaid
graph TD
    User[User] -->|Ingress (Traefik)| Airflow
    User -->|Ingress| Zeppelin
    User -->|Ingress| Superset
    
    subgraph "Application Layer"
        Airflow -->|Submit Job| SparkOp[Spark Operator]
        Zeppelin -->|Interactive| SparkOp
        Superset -->|Query| Hive
    end
    
    subgraph "Compute Layer"
        SparkOp -.->|Spawns| Driver[Spark Driver]
        Driver -.->|Spawns| Exec[Spark Executors]
    end
    
    subgraph "Infrastructure Layer"
        Hive -->|Metastore| Postgres
        Driver -->|Read/Write| MinIO[MinIO (S3)]
        Exec -->|Read/Write| MinIO
    end
```

## 🛠 Tech Stack

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Orchestration** | Apache Airflow 2.x | Workflow Management (Git-Sync / S3-Sync) |
| **Compute** | Apache Spark 3.5 | Distributed Data Processing (Kubeflow Operator) |
| **Interactive** | Apache Zeppelin | Multi-user Notebooks (Spark/Python/SQL) |
| **Analytics** | Apache Superset | Business Intelligence & Visualizations |
| **Storage** | MinIO | S3-compatible Object Storage |
| **Ingress** | Traefik | Edge Router & LoadBalancer |
| **Monitoring** | Prometheus & Grafana | Metrics Collection & Dashboards |

## ⚡ Getting Started

Choose the deployment method that matches your environment.

| Environment | Directory | Command | Best For |
| :--- | :--- | :--- | :--- |
| **Standard / Cloud** | `root (./)` | `./deploy-infra.sh` | GKE, EKS, AKS, Generic K8s |
| **K3s (Edge/IoT)** | [`k3s/`](k3s/) | `cd k3s && ./deploy-infra.sh` | Single Node, Homelab, Edge Devices |
| **MicroK8s** | [`microk8s/`](microk8s/) | `cd microk8s && ./deploy-infra.sh` | Ubuntu Desktop, Dev Workstations |

### 1. Deploy Infrastructure (Stateful)
This sets up Databases, Storage, and Monitoring. Run this **ONCE**.
```bash
./deploy-infra.sh
# Wait for "Infrastructure Deployment Complete"
```

### 2. Deploy Applications (Stateless)
This installs/updates Airflow, Zeppelin, and Superset.
```bash
./deploy-apps.sh
```

## 📚 Documentation
For detailed guides, please refer to:

*   **[Production Guide](PRODUCTION.md)**: Deployment SOP and Safety Procedures.
*   **[Debugging Guide](DEBUGGING.md)**: Troubleshooting common errors (Ingress, 500s, OOM).
*   **Service Reference**:
    *   [Apache Spark Details](docs/spark.md)
    *   [Apache Zeppelin Tuning](docs/zeppelin.md)
    *   [Airflow Architecture](docs/airflow.md)
    *   [Superset Caching](docs/superset.md)
    *   [Monitoring Stack](docs/monitoring.md)

## 🧹 Maintenance (Cleanup)
To switch clusters or reset the environment:

*   **Safe Cleanup** (Preserves Data/PVCs):
    ```bash
    ./cleanup.sh
    ```
*   **Total Destruction** (Wipes ALL Data):
    ```bash
    ./cleanup.sh --destroy-all
    ```
