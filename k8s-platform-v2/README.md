# ☸️ Infrastructure as Code (K2s-Platform-V2)

This directory contains the declarative Kubernetes manifests that define the entire Big Data Platform. It uses **Kustomize** to manage environments and configurations without template bloat.

## 📂 Structure Breakdown

### ├── `00-core/` (The Foundation)
Sets up the basic namespaces and storage requirements.
*   **`namespaces.yaml`**: Creates the `big-data` namespace where apps reside.
*   **`storage-class.yaml`**: Defines standard HDD/SSD storage classes.
*   **`pv-pvc.yaml`**: Persistent Volume Claims. (Note: We try to be stateless, but Postgres and MinIO need disk).

### ├── `01-networking/` (Ingress & Traffic)
Handles how traffic enters the cluster.
*   **`traefik-config.yaml`**: Middleware configurations (strip prefixes, auth).
*   **`ingress-routes.yaml`**: `IngressRoute` (Traefik CRD) definitions that map `airflow.domain.com` -> `airflow-service`.

### ├── `02-database/` (State Layer)
The persistent backends for our applications.
*   **`postgres/`**: A single Postgres instance with multiple databases (`airflow_db`, `hive_metastore`, `superset`).
*   **`minio/`**: S3-compatible Object Storage.
*   **`redis/`**: Cache for Superset.

### ├── `03-apps/` (Compute & Logic)
The core applications.
*   **`airflow/`**: Deployment, Service, and ConfigMap for the Scheduler/Webserver.
*   **`spark-operator/`**: CRDs and RBAC for managing Spark applications.
*   **`zeppelin/`**: Interactive Notebook deployment.
*   **`superset/`**: BI Tool deployment.
*   **`hive-metastore/`**: The schema registry service that connects Spark to tables.

### ├── `04-configs/` (Global Configs)
Shared configurations used across multiple apps.
*   **`core-site.xml`**: Hadoop configurations for S3A (MinIO) access.
*   **`hive-site.xml`**: Metastore connection details.

### ├── `05-monitoring/` (Observability)
The "Eyes and Ears" of the platform.
*   **`kube-prometheus-stack`** (Helm Chart): Prometheus + Grafana + AlertManager.
*   **`loki-stack`** (Helm Chart): Promtail (Log shipper) + Loki (Log aggregation).
*   **`kubernetes-dashboard`** (Helm Chart): Standard K8s UI.
*   **`dashboards/`**: JSON files for custom Grafana dashboards (Spark, Loki Logs) automatically imported via ConfigMaps.

---

## 🛠 How Deployment Works

We use `kustomize` with the `--enable-helm` flag.

1.  **Hydration**: Kustomize merges all YAMLs from the subdirectories.
2.  **Helm Expansion**: It looks at `kustomization.yaml` -> `helmCharts` and renders the Charts (Prometheus, Loki, etc.) into standard YAML.
3.  **Patching**: It applies patches (like replacing `$(INGRESS_DOMAIN)` with the actual LoadBalancer IP).
4.  **Application**: The final stream of YAML is piped to `kubectl apply`.

*See `../deploy-gke.sh` for the exact command.*
