# 📦 Hive Metastore Sub-chart

Hive Metastore and HiveServer2 sub-chart for legacy compatibility.

## 🚀 Overview
- **Role**: Provides Hive Metastore and HiveServer2 for legacy applications
- **Sync Wave**: Typically -1 (Infrastructure Core)

## 🌟 Features
- **Legacy Compatibility**: Support for applications requiring Hive Metastore
- **HiveServer2**: JDBC interface for SQL queries
- **Metadata Storage**: Stores table metadata in PostgreSQL

## 📂 Components
- **Deployment**: Hive Metastore and HiveServer2 deployment
- **ConfigMap**: Hive configuration

## 🛠 Configuration
```yaml
hive-metastore:
  enabled: false  # Disabled by default
  image:
    repository: apache/hive
    tag: 3.1.3
```

## 🔧 Troubleshooting
Common issues and solutions:

### 1. Cannot connect to Hive Metastore
Check if the service is running:
```bash
kubectl get pods -l app=hive-metastore
```

### 2. Metadata storage issues
Verify PostgreSQL connectivity and credentials in the ConfigMap.