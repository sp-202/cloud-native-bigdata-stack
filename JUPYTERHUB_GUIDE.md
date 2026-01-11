# JupyterHub + Spark-on-Kubernetes Guide

JupyterHub provides interactive PySpark notebooks with dynamic Spark executor allocation on Kubernetes.

## Quick Start

1. **Access JupyterHub**
   ```
   http://jupyterhub.<INGRESS_IP>.sslip.io
   ```

2. **Create a new notebook** (Python 3 kernel)

3. **Initialize Spark**
   ```python
   from pyspark.sql import SparkSession
   
   spark = SparkSession.builder \
       .appName("MyNotebook") \
       .getOrCreate()
   
   # Test
   spark.range(10).show()
   ```

4. **Read from MinIO (S3)**
   ```python
   df = spark.read.parquet("s3a://my-bucket/data/")
   df.show()
   ```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     JupyterHub Pod                          │
│  ┌─────────────────┐  ┌──────────────────────────────────┐ │
│  │ Spark Driver    │  │ JupyterLab UI                    │ │
│  │ (port 22321)    │  │ (port 8888)                      │ │
│  └────────┬────────┘  └──────────────────────────────────┘ │
└───────────┼─────────────────────────────────────────────────┘
            │ Executor communication
            ▼
┌───────────────────────────────────────────────────────────┐
│         Spark Executor Pods (dynamic scaling 1-4)          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ spark-exec-1 │  │ spark-exec-2 │  │ spark-exec-N │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────────────────────────────────────────────────────────┘
```

---

## Configuration Reference

| Setting | Value | Description |
|---------|-------|-------------|
| `minExecutors` | 1 | Minimum executor pods |
| `maxExecutors` | 4 | Maximum executor pods |
| `executorIdleTimeout` | 600s (10 min) | Idle time before executor shutdown |
| `executor.memory` | 1GB | Memory per executor |
| `executor.cores` | 1 | CPU cores per executor |
| `driver.port` | 22321 | Spark driver RPC port |
| `blockManager.port` | 22322 | Block manager port |

---

## Troubleshooting Guide

### Error: `SparkContext was shut down`

**Symptoms:**
```
Py4JJavaError: An error occurred while calling o88.showString.
: org.apache.spark.SparkException: Job 0 cancelled because SparkContext was shut down
```

**Cause:** Executors failed to connect to the driver, causing max failure limit (8) to be reached.

**Fix:** Ensure dynamic driver configuration is working:
```bash
# Check startup logs for driver.host
kubectl logs -l app=jupyterhub -n default | grep "driver.host"

# Expected output:
# spark.driver.host                10.x.x.x
```

If missing, redeploy JupyterHub:
```bash
kubectl rollout restart deployment/jupyterhub -n default
```

---

### Error: `No pod was found named spark-driver`

**Symptoms:**
```
SparkException: No pod was found named spark-driver in the cluster
```

**Cause:** Static `spark.kubernetes.driver.pod.name` is set but doesn't match actual pod name.

**Fix:** In client mode, the driver IS the JupyterHub pod. Remove any static driver pod name:
```bash
# Verify spark-defaults.conf doesn't have:
# spark.kubernetes.driver.pod.name  spark-driver

kubectl get configmap spark-config -o yaml | grep "driver.pod.name"
```

---

### Error: `Max number of executor failures (8) reached`

**Symptoms:**
```
WARN ExecutorPodsAllocator: 1 new failed executors.
ERROR ExecutorPodsAllocator: Max number of executor failures (8) reached
```

**Cause:** Executors start but can't connect back to driver.

**Fix:** Check driver networking configuration:
```bash
# Verify driver config in startup logs
kubectl logs -l app=jupyterhub -n default | grep -E "spark.driver|blockManager"

# Expected:
# spark.driver.host          10.x.x.x  (pod IP)
# spark.driver.bindAddress   0.0.0.0
# spark.driver.port          22321
# spark.blockManager.port    22322
```

---

### Error: `InvalidImageName` for executor pods

**Symptoms:**
```
kubectl get pods
spark-executor-exec-1   InvalidImageName
```

**Cause:** `${SPARK_IMAGE}` variable not substituted.

**Fix:** Use `$(SPARK_IMAGE)` syntax for Kustomize/sed substitution in YAML files:
```yaml
# Wrong
image: ${SPARK_IMAGE}

# Correct
image: $(SPARK_IMAGE)
```

---

### Error: `Permission denied` on `/opt/spark/conf`

**Symptoms:**
```
cp: cannot create regular file '/opt/spark/conf/spark-defaults.conf': Permission denied
```

**Cause:** InitContainer copies files as root, but main container runs as jovyan (UID 1000).

**Fix:** InitContainer must set permissions:
```yaml
initContainers:
  - name: spark-home-init
    command: ["sh", "-c", "cp -r /opt/spark/* /mnt/spark/ && chown -R 1000:100 /mnt/spark"]
```

---

### Error: `502 Bad Gateway`

**Symptoms:** Browser shows "502 Bad Gateway" when accessing JupyterHub URL.

**Cause:** Jupyter server not binding to 0.0.0.0.

**Fix:** Verify Jupyter config:
```bash
kubectl exec deployment/jupyterhub -- cat /etc/jupyter/jupyter_notebook_config.py

# Should contain:
# c.ServerApp.ip = '0.0.0.0'
```

---

### Error: Executors creating and terminating rapidly

**Symptoms:** Executor pods appear and disappear quickly without completing work.

**Cause:** Dynamic allocation with short idle timeout.

**Fix:** Current config uses 600s (10 min) idle timeout. If you need longer:
```
spark.dynamicAllocation.executorIdleTimeout  1200s
```

---

## Useful Commands

```bash
# Watch JupyterHub pod in real-time
kubectl get pods -l app=jupyterhub -w

# View executor pods
kubectl get pods -l spark-role=executor

# Check Spark driver logs
kubectl logs -l app=jupyterhub -c jupyterhub --tail=100

# Port-forward to Spark UI
kubectl port-forward deployment/jupyterhub 4040:4040
# Then open http://localhost:4040

# Delete stuck executor pods
kubectl delete pods -l spark-role=executor

# Restart JupyterHub cleanly
kubectl rollout restart deployment/jupyterhub -n default
kubectl rollout status deployment/jupyterhub -n default
```

---

## SQL Magic Example

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
