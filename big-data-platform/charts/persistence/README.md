# 📦 Persistence Sub-chart

Manages the storage foundation of the platform, including namespaces and persistent volumes.

## 🚀 Overview
- **Role**: Storage orchestration and namespace provisioning.
- **Sync Wave**: `-3` (Foundational Layer).

## 📂 Components
- **Namespaces**: `cloudflare`, `monitoring`, `spark-operator`.
- **Volumes**: 
  - Dynamic hostpath storage for Postgres, MinIO, and Airflow.
  - Spark event-log volume definitions.

## 💾 Storage Class
Primary usage of **OpenEBS Local Hostpath** for high-performance node-local storage.

## 🛠 Configuration
```yaml
persistence:
  enabled: true
```
