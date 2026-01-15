# ⚡ Spark on Kubernetes: Deep Dive

This platform uses **Spark Connect** to provide a centralized compute server, eliminating the need for each notebook to spawn its own executor pods.

## 🏗 Architecture

### Spark Connect Mode (Current)
The platform uses a **thin client** architecture:
- **Spark Connect Server**: A dedicated deployment running Spark in client mode with 4 dynamic executors.
- **Notebooks**: JupyterHub and Marimo connect via gRPC (port 15002) without local Spark processes.
- **Benefits**: Resource efficiency, centralized management, simpler notebook containers.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    JupyterHub (Thin Client)                         │
│    Uses: SparkSession.builder.remote("sc://server:15002")          │
└───────────────────────────────────────────────────────────────────┘
                              │ gRPC (15002)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│               Spark Connect Server (Driver Pod)                     │
│    Uses: spark-submit --class SparkConnectServer                   │
│    Manages: 4 dynamic executor pods                                │
└───────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│                     Executor Pods                                  │
│    Managed dynamically by Spark Kubernetes backend                │
└───────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Key Configurations

| Property | Description |
| :--- | :--- |
| `spark.master` | `k8s://https://kubernetes.default.svc` |
| `spark.kubernetes.container.image` | Golden Stack image (`spark-4.0.1-uc-0.3.1-fix-v4`) |
| `spark.sql.connect.port` | `15002` (gRPC endpoint) |
| `spark.executor.instances` | `4` (managed by Connect Server) |
| `spark.hadoop.hive.metastore.uris` | `thrift://hive-metastore:9083` |

---

## 📦 Python Version Alignment
- **All components use Python 3.11** - unified Docker image ensures driver/executor compatibility.
- **PySpark client version** must match server version (4.0.1).

## 💾 S3/MinIO Integration (S3a)
- **Endpoint**: `http://minio.default.svc.cluster.local:9000`
- **Path Style**: Required for MinIO (`fs.s3a.path.style.access = true`)

---

## 🛠 Troubleshooting K8s Issues

| Error | Root Cause | Solution |
| :--- | :--- | :--- |
| **`Pending`** pods | Cluster/Node full | Increase node count or reduce executor memory/CPU |
| **`ImagePullBackOff`** | Incorrect image tag | Verify image exists: `kubectl describe pod <pod>` |
| **`Connection refused`** | Service not running | Check: `kubectl get svc spark-connect-server-driver-svc` |
| **`grpc.StatusCode.UNAVAILABLE`** | Server not started | Check logs: `kubectl logs -l app=spark-connect-server` |
| **`Table not found`** | HMS not connected | Verify: `spark.hadoop.hive.metastore.uris` config |
