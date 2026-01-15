⚠️ Updated documentation as of 2026-01-15. See CHANGELOG for details.

# JupyterHub + Spark Connect Guide

JupyterHub provides interactive PySpark notebooks as **thin clients** connecting to a centralized **Spark Connect Server**.

## Quick Start

1. **Access JupyterHub**
   ```
   http://jupyterhub.<INGRESS_IP>.sslip.io
   ```

2. **Create a new notebook** (PySpark Connect kernel)

3. **Verify Spark Connection**
   ```python
   # Spark is auto-initialized via SPARK_REMOTE environment variable
   print(spark)
   spark.range(10).show()
   ```

   **Expected Output:**
   ```
   ✅ Connected to Spark 4.0.1 via Spark Connect
      Remote: sc://spark-connect-server-driver-svc:15002
   +---+
   | id|
   +---+
   |  0|
   |  1|
   ...
   ```

4. **Write & Read Delta Lake (S3)**
   ```python
   # Write
   df = spark.range(100)
   df.write.format("delta").mode("overwrite").saveAsTable("default.test_table")
   
   # Read
   spark.sql("SELECT * FROM default.test_table").show()
   ```

---

## Architecture (Spark Connect)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    JupyterHub Pod (Thin Client)                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ JupyterLab UI (port 8888)                                   │   │
│  │ - No local Spark Driver                                     │   │
│  │ - No executor management                                    │   │
│  │ - Connects via gRPC to Spark Connect Server                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
                              │ gRPC (port 15002)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│               Spark Connect Server (Driver Pod)                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Spark Driver + Connect Service                              │   │
│  │ - Manages 4 dynamic executor pods                           │   │
│  │ - Delta Lake extensions enabled                             │   │
│  │ - Connected to Hive Metastore                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│         Spark Executor Pods (managed by Connect Server)        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ spark-exec-1 │  │ spark-exec-2 │  │ spark-exec-N │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└───────────────────────────────────────────────────────────────┘
```

---

## Configuration Reference

| Setting | Value | Description |
|---------|-------|-------------|
| `SPARK_REMOTE` | `sc://spark-connect-server-driver-svc:15002` | Spark Connect Server endpoint |
| `executor.instances` | 4 | Number of executor pods (managed by server) |
| `HMS URI` | `thrift://hive-metastore:9083` | Hive Metastore for table metadata |
| `warehouse.dir` | `s3a://warehouse/managed/` | Default table storage location |

---

## Troubleshooting Guide

### Error: `Spark Connect initialization failed`

**Symptoms:**
```
⚠️ Spark Connect initialization failed: Connection refused
   Ensure Spark Connect Server is running at sc://spark-connect-server-driver-svc:15002
```

**Cause:** Spark Connect Server is not running or not reachable.

**Fix:**
```bash
# Check if Spark Connect Server is running
kubectl get pods -l app=spark-connect-server
# Expected: spark-connect-server-xxxxx   Running

# Check server logs
kubectl logs -l app=spark-connect-server --tail=50

# Verify service exists
kubectl get svc spark-connect-server-driver-svc
# Expected: Port 15002/TCP exposed
```

---

### Error: `SPARK_REMOTE not set`

**Symptoms:**
```
⚠️ SPARK_REMOTE not set. Spark session not initialized.
```

**Cause:** Environment variable not configured in JupyterHub deployment.

**Fix:**
```bash
# Check JupyterHub environment
kubectl exec deployment/jupyterhub -- env | grep SPARK_REMOTE
# Expected: SPARK_REMOTE=sc://spark-connect-server-driver-svc:15002

# If missing, verify jupyterhub.yaml has:
env:
  - name: SPARK_REMOTE
    value: "sc://spark-connect-server-driver-svc:15002"
```

---

### Error: `502 Bad Gateway`

**Symptoms:** Browser shows "502 Bad Gateway" when accessing JupyterHub URL.

**Cause:** Jupyter server not binding to 0.0.0.0.

**Fix:**
```bash
kubectl exec deployment/jupyterhub -- cat /etc/jupyter/jupyter_notebook_config.py

# Should contain:
# c.ServerApp.ip = '0.0.0.0'
```

---

### Error: `Table not found in Hive Metastore`

**Symptoms:**
```
AnalysisException: Table or view not found: default.my_table
```

**Cause:** Spark Connect Server not connected to Hive Metastore.

**Fix:**
```bash
# Check HMS connectivity from Spark Connect Server
kubectl exec -it deployment/spark-connect-server -- \
  curl -v telnet://hive-metastore:9083

# Check Spark Connect Server config
kubectl logs -l app=spark-connect-server | grep "hive.metastore"
# Expected: spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083
```

---

### Error: Executor pods stuck in `Pending`

**Symptoms:**
```bash
kubectl get pods -l spark-role=executor
# Shows pods in Pending state
```

**Cause:** Insufficient cluster resources or missing service account.

**Fix:**
```bash
# Check pod events
kubectl describe pod <executor-pod-name> | grep -A10 Events

# Common issues:
# - Insufficient CPU/memory: Scale up cluster
# - Missing service account: Check spark-operator-spark SA exists
kubectl get sa spark-operator-spark
```

---

## Useful Commands

```bash
# Watch Spark Connect Server pod
kubectl get pods -l app=spark-connect-server -w

# View Spark Connect Server logs
kubectl logs -l app=spark-connect-server --tail=100

# View executor pods (managed by server)
kubectl get pods -l spark-role=executor

# Access Spark UI (via port-forward)
kubectl port-forward svc/spark-connect-server-driver-svc 4040:4040
# Then open http://localhost:4040

# Restart Spark Connect Server
kubectl rollout restart deployment/spark-connect-server

# Check S3/MinIO connectivity
kubectl exec deployment/spark-connect-server -- \
  curl -s http://minio:9000/minio/health/ready
```

---

## SQL Example

```python
# Create sample data
data = [("Alice", 34), ("Bob", 45), ("Charlie", 29)]
df = spark.createDataFrame(data, ["name", "age"])

# Register as temp view
df.createOrReplaceTempView("people")

# Query with SQL
result = spark.sql("""
    SELECT name, age 
    FROM people 
    WHERE age > 30
    ORDER BY age DESC
""")
result.show()
```

**Expected Output:**
```
+-----+---+
| name|age|
+-----+---+
|  Bob| 45|
|Alice| 34|
+-----+---+
```

---

## Legacy Mode (Deprecated)

> [!WARNING]
> The previous architecture where JupyterHub spawned its own executor pods is **deprecated**. 
> All notebooks should now use Spark Connect mode with `SPARK_REMOTE` environment variable.
> 
> If you need legacy client mode for debugging, see [archived documentation](archive/).
