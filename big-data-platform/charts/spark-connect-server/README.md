# 📦 Spark Connect Server Sub-chart

Spark Connect Server sub-chart for shared Spark gateway.

## 🚀 Overview
- **Role**: Shared Spark gateway for all interactive clients (JupyterHub, Airflow, Marimo)
- **Sync Wave**: 0 (Application Layer)

## 🌟 Features
- **Shared Gateway**: Single entry point for all Spark clients
- **Multi-User Support**: Isolated sessions for concurrent users
- **Kubernetes Integration**: Native Spark on Kubernetes support
- **Dynamic Resource Allocation**: Automatic scaling of executor resources

## 📂 Components
- **Deployment**: Spark Connect Server deployment
- **ConfigMap**: Server configuration and executor pod template
- **RBAC**: ServiceAccount and role bindings for Kubernetes access

## 🛠 Configuration
```yaml
spark-connect-server:
  enabled: true
  image:
    repository: apache/spark
    tag: 3.5.8
  replicas: 1  # Currently single replica
```

## 🔧 Troubleshooting
Common issues and solutions:

### 1. Cannot connect to Spark Connect Server
Check if the service is running:
```bash
kubectl get pods -l app=spark-connect-server
```

### 2. Executor pods failing to start
Check the executor pod template in the ConfigMap and verify Kubernetes RBAC permissions.

### 3. Performance issues
Monitor resource usage and adjust executor configurations in the pod template ConfigMap.