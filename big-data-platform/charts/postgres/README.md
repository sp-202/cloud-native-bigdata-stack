# 📦 Postgres Sub-chart

This sub-chart deploys a PostgreSQL instance used as the metadata backbone for the platform.

## 🚀 Overview
- **Role**: Relational database for Airflow, Superset, and Hive Metastore.
- **Image**: `postgres:15-alpine` (configurable).
- **Sync Wave**: `-2` (Infrastructure Layer).

## 📂 Components
- **Deployment**: Single-replica Postgres instance.
- **Service**: Internal `ClusterIP` on port 5432.
- **ConfigMap**: Initialization scripts (`postgres-init`).

## 💾 Persistence
Uses a PersistentVolumeClaim `postgres-data-pvc` backed by OpenEBS local hostpath storage.

## 🛠 Configuration
Configuration is managed via the parent `values.yaml` under the `postgres` key.
```yaml
postgres:
  enabled: true
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
```
