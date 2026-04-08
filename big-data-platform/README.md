# 🏛 Big Data Platform (Umbrella Chart)

This is the primary Helm chart that orchestrates the entire Cloud-Native Big Data Platform. It follows an **Umbrella Chart** pattern, where multiple specialized sub-charts are bundled and configured through a single `values.yaml` file.

## 🌊 Sync Wave Strategy

The platform relies on **ArgoCD Sync Waves** for robust resource ordering:

| Wave | Phase | Components |
| :--- | :--- | :--- |
| **-3** | Foundation | Namespaces, Storage (Persistence) |
| **-2** | Infra Core | Postgres, Redis, MinIO, Secrets |
| **-1** | Init | DB Migrations, S3 Bucket Creation |
| **0** | Application | Airflow, Spark, JupyterHub, Ingress, Monitoring |

## 📂 Local Sub-charts

Each major component is managed as a local sub-chart in the `charts/` directory:

| Chart | Purpose |
| :--- | :--- |
| **[airflow](charts/airflow)** | Workflow orchestration |
| **[minio](charts/minio)** | S3-compatible data lake |
| **[postgres](charts/postgres)** | Metadata relational database |
| **[gravitino](charts/gravitino)** | Unified metadata lake with Iceberg REST (primary catalog) |
| **[monitoring](charts/monitoring)** | Prometheus, Grafana, Loki |
| **[ingress](charts/ingress)** | Traefik routing rules |
| **[persistence](charts/persistence)** | PV/PVC & Storage orchestration |
| **[spark-connect](charts/spark-connect-server)** | Interactive Spark gateway |
| **[jupyterhub](charts/jupyterhub)** | User notebook environments |

## 🛠 Configuration

All configurations are centralized in the root [values.yaml](values.yaml). 

### Example: Enabling/Disabling Components
```yaml
minio:
  enabled: true
starrocks:
  enabled: false
```

## 🚀 Deployment

```bash
# Update internal dependencies
helm dependency update

# Install the umbrella
helm install big-data-platform ./big-data-platform
```
