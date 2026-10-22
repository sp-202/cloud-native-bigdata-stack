# 📦 Spark History Server Sub-chart

Provides a web interface to view the status and execution details of completed Spark applications.

## 🚀 Overview
- **Role**: Post-execution monitoring for Spark jobs.
- **Image**: `subhodeep2022/spark-bigdata` (multi-arch).
- **Sync Wave**: `0` (Application Layer).

## 📂 Components
- **Deployment**: Spark History Server instance.
- **Service**: Internal service on port 18080.
- **IngressRoute**: Exposed via Traefik (e.g., `spark-history.domain.com`).

## 💾 Storage
Reads event logs from SeaweedFS (`s3a://lakehouse/spark-events/`), credentials from the `lakehouse-s3` Secret.

## 🛠 Configuration
```yaml
spark-history-server:
  enabled: true
  replicas: 1
```
