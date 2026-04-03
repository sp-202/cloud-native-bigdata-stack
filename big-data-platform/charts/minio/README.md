# 📦 MinIO Sub-chart

High-performance, S3-compatible object storage that serves as the "Data Lake" storage layer.

## 🚀 Overview
- **Role**: Object storage for Spark data, Delta Lake tables, and Airflow logs.
- **Image**: `minio/minio` (multi-arch).
- **Sync Wave**: `-2` (Infrastructure Layer).

## 📂 Components
- **Deployment**: MinIO server instance.
- **Service**: 
  - `minio`: API port 9000.
  - `minio-console`: UI port 9001.
- **Job**: `minio-create-buckets` (Wave -1) to seed required buckets.

## 💾 Persistence
Uses a PersistentVolumeClaim `minio-data-pvc` backed by OpenEBS local hostpath storage.

## 🛠 Configuration
Configuration is managed via the parent `values.yaml` under the `minio` key.
```yaml
minio:
  enabled: true
  accessKey: "minioadmin"
  secretKey: "minioadmin"
```
