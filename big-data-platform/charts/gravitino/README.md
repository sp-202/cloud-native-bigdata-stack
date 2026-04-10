# 📦 Gravitino Sub-chart

Apache Gravitino 1.2.0 — Unified AI & Data Metadata Lake with Iceberg REST Catalog (IRC).

## 🚀 Overview
- **Role**: Unified metadata lake with Iceberg REST Catalog (IRC) for governance
- **Version**: 1.2.0
- **Sync Wave**: Depends on Postgres (typically -1 or 0)

## 🌟 Features
- **Unified Metadata**: Single API endpoint for all catalog operations
- **Iceberg REST Catalog**: Native Iceberg REST interface for table discovery
- **Multi-Catalog Support**: Support for Iceberg, Delta, and Hive tables
- **Web UI**: Built-in web interface for browsing catalogs and tables
- **Access Control**: Fine-grained access control for data resources

## 📂 Components
- **Deployment**: Gravitino server deployment
- **ConfigMap**: Server configuration

## 🛠 Configuration
```yaml
gravitino:
  enabled: true
  image:
    repository: apache/gravitino
    tag: 0.5.0
```

## 🔧 Troubleshooting
Common issues and solutions:

### 1. Cannot connect to Gravitino server
Check if the service is running:
```bash
kubectl get pods -l app=gravitino
```

### 2. Authentication issues
Verify the configuration in the ConfigMap and ensure credentials are correct.