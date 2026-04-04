# 🔍 Debugging Guide

Quick reference for diagnosing and resolving common issues in the cloud-native big data platform.

---

## Table of Contents
1. [Spark & Kryo Errors](#spark--kryo-errors)
2. [Hive Metastore Issues](#hive-metastore-issues)
3. [Superset & Airflow Login Issues](#superset--airflow-login-issues)
4. [Connectivity & Network Debugging](#connectivity--network-debugging)
5. [Storage & Persistence Issues](#storage--persistence-issues)

---

## Spark & Kryo Errors

### Error: `[FAILED_REGISTER_CLASS_WITH_KRYO]`

**Symptoms:**
```
java.lang.ClassNotFoundException: org.apache.sedona.spark.SedonaKryoRegistrator
```

**Diagnosis:**
1. Check the Spark Connect server logs:
```bash
kubectl logs -n default deploy/spark-connect-server -c spark-connect-server --tail=50 | grep -i kryo
```

2. Verify the Kryo registrator config in the ConfigMap:
```bash
kubectl get cm spark-config -o jsonpath='{.data.spark-defaults\.conf}' | grep kryo
```

**Resolution:**
Ensure the class name is correct in three places:
- Dockerfile: `org.apache.sedona.core.serde.SedonaKryoRegistrator`
- ConfigMap: `org.apache.sedona.core.serde.SedonaKryoRegistrator`
- Deployment --conf args: `org.apache.sedona.core.serde.SedonaKryoRegistrator`

The common mistake is using `org.apache.sedona.spark.SedonaKryoRegistrator` (doesn't exist).

**Reference:** See ISSUES.md #7

---

### Error: `CreateDataFrame` or Spark SQL timeouts

**Symptoms:**
```
Task/job times out when creating DataFrames
Spark executor pods not spawning
```

**Diagnosis:**
1. Check if Spark Connect server is running:
```bash
kubectl get pod -l app=spark-connect-server
```

2. Check Spark executor spawning:
```bash
kubectl get pods | grep spark-executor
```

3. View Spark Connect server logs for errors:
```bash
kubectl logs deploy/spark-connect-server --all-containers=true -f
```

**Resolution:**
- Ensure `spark.dynamicAllocation.minExecutors` is set (e.g., 2) so executors are pre-allocated
- Check node resources: `kubectl top nodes`
- Verify Kubernetes API is accessible: `kubectl get nodes`

---

## Hive Metastore Issues

### Error: `TTransportException: Socket is closed by peer`

**Symptoms:**
```
AnalysisException: org.apache.hadoop.hive.ql.metadata.HiveException: 
  org.apache.thrift.transport.TTransportException: Socket is closed by peer
```

With HMS logs showing:
```
java.lang.ClassNotFoundException: software.amazon.awssdk.core.exception.SdkException
```

**Diagnosis:**
1. Check HMS pod status:
```bash
kubectl get pod -l app=hive-metastore
kubectl logs deploy/hive-metastore -c hive-metastore --tail=100 | grep -i "exception\|error"
```

2. Check if AWS SDK v2 JARs are present:
```bash
kubectl exec deploy/hive-metastore -c hive-metastore -- ls /opt/hive/lib/ | grep -E "bundle|aws"
```

Should see:
- `bundle-2.29.52.jar` ✅
- `url-connection-client-2.29.52.jar` ✅
- NOT `aws-java-sdk-bundle-1.12.367.jar` ❌

**Resolution:**
The HMS image needs to be rebuilt with AWS SDK v2. Check the image tag in values.yaml:

```bash
kubectl get deploy hive-metastore -o jsonpath='{.spec.template.spec.containers[0].image}'
```

If it shows `hive-4.1.0-custom-prod` (old), rebuild and push the new image:

```bash
cd docker/hive
# Update .env.hive: HIVE_IMAGE_VERSION_TAG=custom-prod-v2
./build.sh
# Wait for image to push, then trigger ArgoCD sync
```

**Reference:** See ISSUES.md #6

---

### Error: `Invalid method name: 'get_table'`

**Symptoms:**
```
AnalysisException: org.apache.hadoop.hive.ql.metadata.HiveException: Unable to fetch table X. 
  Invalid method name: 'get_table'
```

**Root Cause:**
This is often a symptom of the AWS SDK v2 ClassNotFoundException (#6 above) or a missing Hive database.

**Diagnosis:**
1. Check HMS logs for the root exception (see #6)
2. Verify the database exists:
```bash
# Using Spark SQL
kubectl exec deploy/spark-connect-server -- \
  /opt/spark/bin/spark-sql -e "SHOW DATABASES;" 2>/dev/null | grep default
```

**Resolution:**
- If HMS SDK issue, see #6 above
- If database missing, create it:
```python
spark.sql("CREATE DATABASE IF NOT EXISTS <db_name>")
```

---

## Superset & Airflow Login Issues

### Error: Superset `500 Internal Server Error` on Login

**Symptoms:**
```
POST /login → 500 Internal Server Error
"Sorry, something went wrong. We are fixing the mistake now."
```

**Diagnosis:**
1. Check Superset pod logs:
```bash
kubectl logs deploy/big-data-platform-superset -c superset --tail=100
```

2. Check if `superset-init` PostSync job ran:
```bash
kubectl get jobs | grep superset
kubectl logs job/superset-db-init
```

3. Check if admin user exists:
```bash
kubectl exec deploy/big-data-platform-superset -c superset -- \
  superset fab list-users
```

**Resolution:**
If no users are shown, create the admin user manually:

```bash
kubectl exec deploy/big-data-platform-superset -c superset -- \
  superset fab create-admin \
  --username admin \
  --firstname Superset \
  --lastname Admin \
  --email admin@superset.com \
  --password "CHANGE_ME_STRONG_PASSWORD"
```

Then trigger a new ArgoCD sync so the PostSync job runs automatically next time.

**Reference:** See ISSUES.md #8

---

### Error: Airflow Webserver `Invalid login. Please try again.`

**Symptoms:**
```
Login page loads, but credentials (admin/admin) don't work
```

**Diagnosis:**
1. Check if admin user exists:
```bash
kubectl exec deploy/big-data-platform-webserver -- airflow users list
```

2. Check Airflow logs:
```bash
kubectl logs deploy/big-data-platform-webserver -c webserver | tail -50
```

**Resolution:**
Create admin user manually:

```bash
kubectl exec deploy/big-data-platform-webserver -c webserver -- \
  airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@airflow.com \
  --password admin
```

**Reference:** See ISSUES.md #8

---

## Connectivity & Network Debugging

### Error: Spark executors can't connect to S3 (MinIO)

**Symptoms:**
```
FileNotFoundException: No such file or directory
Couldn't open file: s3a://warehouse/...
```

**Diagnosis:**
1. Check MinIO pod:
```bash
kubectl get pod -l app=minio
```

2. Test S3A connectivity from a Spark executor:
```bash
# From executor logs, look for connection timeouts
kubectl logs spark-executor-* | grep -i "s3a\|endpoint\|connection"
```

3. Verify S3A endpoint in Spark config:
```bash
kubectl get cm spark-config -o jsonpath='{.data.spark-defaults\.conf}' | grep s3a.endpoint
```

**Resolution:**
Ensure MinIO endpoint matches your environment:
- In-cluster: `http://minio.default.svc.cluster.local:9000`
- External: Update values.yaml `global.s3.endpoint`

Then trigger ArgoCD sync.

---

### Error: JupyterHub can't reach Spark Connect Server

**Symptoms:**
```
SparkConnectException: Cannot invoke RPC
TimeoutError: Connection timed out
```

**Diagnosis:**
1. Check Spark Connect Server is running:
```bash
kubectl get svc spark-connect-server-driver-svc
kubectl logs deploy/spark-connect-server --tail=50
```

2. Test connectivity from JupyterHub pod:
```bash
kubectl exec deploy/jupyterhub -c jupyterhub -- \
  curl -v spark-connect-server-driver-svc:15002
```

3. Verify the remote() URL in JupyterHub config:
```bash
kubectl get cm jupyterhub-config -o jsonpath='{.data.00-pyspark-setup\.py}' | grep remote
```

**Resolution:**
Ensure the Spark Remote URL is correct:
```python
spark = SparkSession.builder.remote("sc://spark-connect-server-driver-svc:15002").getOrCreate()
```

---

## Storage & Persistence Issues

### Error: Pod stuck in `Pending` with `FailedMount`

**Symptoms:**
```
Pod events show: "FailedMount: Unable to mount path /var/openebs/local/..."
```

**Diagnosis:**
1. Check which node the pod is scheduled on:
```bash
kubectl describe pod <pod-name> | grep Node:
```

2. SSH into the node and check if the directory exists:
```bash
ssh ec2-user@<node-ip>
ls -la /var/openebs/local/
```

**Resolution:**
Create the missing directory on the node:

```bash
ssh ec2-user@<node-ip>
sudo mkdir -p /var/openebs/local/<app-name>
sudo chown -R 1000:1000 /var/openebs/local/<app-name>
```

Better yet, ensure Terraform creates these dirs in the node user_data script (see `compute-k8s-gp.tf`).

---

### Error: MinIO bucket doesn't exist

**Symptoms:**
```
NoSuchBucket: The specified bucket does not exist
```

**Diagnosis:**
1. List MinIO buckets:
```bash
kubectl exec deploy/minio -c minio -- \
  /usr/bin/mc ls minio/
```

2. Check MinIO initialization job:
```bash
kubectl get jobs | grep minio
kubectl logs job/minio-create-buckets
```

**Resolution:**
Create missing bucket:

```bash
kubectl exec deploy/minio -c minio -- \
  /usr/bin/mc mb minio/<bucket-name>
```

Or add to the MinIO init job in the Helm chart.

---

## Troubleshooting Checklist

When something breaks, run this diagnostic sequence:

```bash
# 1. Check pod health
kubectl get pods -n default -A | grep -E "Error|CrashLoop|Pending"

# 2. Check ArgoCD sync status
argocd app get big-data-platform

# 3. Check recent pod events
kubectl describe pod <failing-pod>

# 4. Check logs
kubectl logs deploy/<app-name> --all-containers=true --tail=100

# 5. Check resources
kubectl top nodes
kubectl top pods -n default

# 6. Check ConfigMaps/Secrets
kubectl get cm
kubectl get secret | grep -v default-token

# 7. Test inter-pod connectivity
kubectl run -it debug --image=busybox -- sh
# Inside the pod:
wget -O- http://service-name:port

# 8. Check ArgoCD hooks
kubectl get jobs | grep -E "sync|hook"
kubectl logs job/<hook-job>
```

---

## Common Fix Patterns

### 1. Pod Restart after Image Update
```bash
kubectl rollout restart deploy/<app-name>
```

### 2. Force ArgoCD Sync
```bash
kubectl -n argocd exec deploy/argocd-server -- \
  argocd app sync big-data-platform --force --prune
```

### 3. Rebuild and Push Docker Image
```bash
cd docker/<component>
./build.sh  # or manually: docker buildx build --push ...
```

### 4. Delete and Recreate a Persistent Volume
```bash
# WARNING: This deletes data!
kubectl delete pvc <pvc-name>
kubectl delete pv <pv-name>
# Then redeploy via ArgoCD
```

---

## Getting Help

1. **Check ISSUES.md** for known issues and their solutions
2. **Check CHANGELOG.md** for recent fixes
3. **Check pod logs**: `kubectl logs <pod> -c <container> -f`
4. **Check ArgoCD UI**: Port-forward to see sync status and errors
5. **Check K8s events**: `kubectl describe pod <pod>`

---

**Last Updated:** 2026-04-04
