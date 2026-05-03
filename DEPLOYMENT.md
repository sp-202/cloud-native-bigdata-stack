# ⚡ Deployment Guide (AWS / Self-Managed K8s)

This guide details the steps to deploy the Cloud-Native Big Data Platform on a Kubernetes cluster.

## 📋 Prerequisites

- **Cluster**: A Kubernetes 1.28+ cluster. Optimized for AWS EC2 ARM64 (Graviton) nodes.
- **CNI**: Cilium (configured in AWS ENI IPAM mode recommended).
- **Storage**: OpenEBS (for dynamic hostpath provisioning).
- **Tools**:
  - `kubectl`
  - `helm` v3.12+
  - `argocd` CLI (optional, but recommended)

## 🚀 Installation

### 1. Configure Environment
The platform uses an Umbrella Chart architecture. All configurations are centralized in `big-data-platform/values.yaml`.

### 2. Run the Bootstrap Script
The `deploy-v2.sh` script automates the initial cluster setup, including namespace creation and CRD installation.

```bash
chmod +x deploy-v2.sh
./deploy-v2.sh
```

### 3. ArgoCD Deployment (GitOps)
The preferred way to manage the platform is via ArgoCD.

1.  **Install ArgoCD**:
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

2.  **Connect the Repository**:
    Create a new ArgoCD Application pointing to the `big-data-platform/` directory in this repository.

3.  **Sync**:
    ArgoCD will automatically apply the resources in the correct order using **Sync Waves**.

## 🌊 Sync Wave Hierarchy

| Order | Chart | Description |
| :--- | :--- | :--- |
| **-3** | `persistence` | Sets up Namespaces, PVs, and PVCs. |
| **-2** | `infra-core` | Deploys Postgres, Redis, MinIO, and Airflow Secrets. |
| **-1** | `init-jobs` | Runs Airflow DB migrations and creates S3 buckets. |
| **0** | `applications` | Deploys Airflow, JupyterHub, Superset, StarRocks, and Ingress. |

## 🛠 Manual Directory Setup (AWS EC2)

On fresh AWS nodes, the local storage paths for persistent volumes must be initialized:

```bash
# Automated via kubectl debug node (run for each node)
kubectl debug node/<node-name> -it --image=alpine -- chroot /host mkdir -p /var/openebs/local/postgres-data /var/openebs/local/minio-data /var/openebs/local/airflow-scheduler-logs
```

## 🔍 Verification

1.  **Network**: Verify IngressRoutes are correctly mapped:
    ```bash
    kubectl get ingressroute -A
    ```

2.  **Health**: Ensure all application pods are `Running`:
    ```bash
    kubectl get pods -n default
    ```

## 🔐 Post-Deployment Configuration

### Admin Credentials Setup

After the first deployment, admin users are automatically created by ArgoCD PostSync hooks:

| Service | Username | Default Password | Location |
|---------|----------|------------------|----------|
| **Superset** | `admin` | `CHANGE_ME_STRONG_PASSWORD` | values.yaml line 568 |
| **Airflow** | `admin` | `admin` | Auto-created by webserver.defaultUser |
| **Grafana** | `admin` | `admin` | values.yaml line 601 |

**Important**: Change Superset's default password in values.yaml before production deployment:

```yaml
superset:
  init:
    createAdmin: true
    adminUser:
      username: admin
      password: "YOUR_SECURE_PASSWORD_HERE"  # Change this!
```

Then commit and push to trigger ArgoCD sync.

### Verifying Admin User Creation

```bash
# Superset
kubectl exec deploy/superset -c superset -- \
  superset fab list-users

# Airflow
kubectl exec deploy/big-data-platform-webserver -c webserver -- \
  airflow users list

# Grafana (check login works via web interface)
```

---

## 🔑 Kubernetes Cluster Admin Access

To access Kubernetes cluster administration interfaces (e.g., Headlamp, kubectl commands):

### Step 1: Create Admin Service Account

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: default
EOF
```

**Output**:
```
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user-binding created
```

### Step 2: Generate Admin Token

```bash
kubectl create token admin-user -n default
```

**Copy the output token** — this is your Kubernetes cluster admin token. Use it to log in to:
- **Headlamp UI** — Kubernetes cluster dashboard
- **kubectl remote access** — For out-of-cluster administration
- Any other Kubernetes API-based tools

The token is valid for 1 hour by default. To create a longer-lived token (e.g., 7 days):

```bash
kubectl create token admin-user -n default --duration=168h
```

---

## 🔐 ArgoCD Admin Password

ArgoCD is installed with a default admin user. Retrieve the password:

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Output**: Your ArgoCD admin password (e.g., `abc123xyz...`)

### Access ArgoCD UI

1. **Port-forward to ArgoCD**:
   ```bash
   kubectl port-forward -n argocd svc/argocd-server 8080:443
   ```

2. **Open browser**: `https://localhost:8080`

3. **Login**:
   - Username: `admin`
   - Password: (from command above)

### Change ArgoCD Admin Password (Optional)

```bash
argocd account update-password --account admin --new-password YOUR_NEW_PASSWORD
```

Or via the web UI: ArgoCD → User Settings → Change Password

---

## 📊 Post-Deployment Verification

### 1. Check All Pods are Running
```bash
kubectl get pods -n default -o wide
```
All pods should be in `Running` state. If any are stuck in `Pending` or `CrashLoopBackOff`, see Troubleshooting section.

### 2. Verify Data Connectivity
```bash
# Test Spark to S3
kubectl exec -it deploy/jupyterhub -c jupyterhub -- python3 << 'EOF'
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect-server-driver-svc:15002").getOrCreate()
spark.range(10).write.format("delta").mode("overwrite").save("s3a://warehouse/test")
print("✅ Spark → S3 write successful")
EOF
```

### 3. Verify Hive Metastore
```bash
# Create a Hive database
kubectl exec deploy/spark-connect-server -- \
  /opt/spark/bin/spark-sql -e "CREATE DATABASE IF NOT EXISTS test; SHOW DATABASES;"
```

### 4. Verify Ingress Routes
```bash
# All routes should resolve via cloudflared
kubectl get ingressroute -A
kubectl logs -n cloudflare deploy/cloudflared | tail -20
```

### 5. Check Storage Paths Exist
```bash
# From a node, verify OpenEBS directories were created
ssh ec2-user@<node-ip>
ls -la /var/openebs/local/ | grep -E "postgres|minio|airflow|spark"
```

---

## 🆘 Troubleshooting

### CrashLoopBackOff
**Cause:** Application crashed or failed to start.

```bash
# Check logs
kubectl logs deploy/<app-name> --previous  # Previous container logs
kubectl logs deploy/<app-name> -f          # Tail current logs

# Common causes:
# - Database connection failure: Check Postgres pod
# - Missing S3 buckets: Check MinIO initialization job
# - Configuration error: Check values.yaml syntax
```

### Pending Pods / FailedMount
**Cause:** Local storage paths don't exist on node.

```bash
# Check pod events
kubectl describe pod <pod-name>

# Create missing directory on node
ssh ec2-user@<node-ip>
sudo mkdir -p /var/openebs/local/<missing-path>
sudo chown -R 1000:1000 /var/openebs/local/<missing-path>
```

### 500 Errors on Superset Login
**Cause:** Database not initialized.

```bash
# Check if superset-init job ran
kubectl get jobs | grep superset
kubectl logs job/superset-db-init

# Manually trigger database init if needed
kubectl exec deploy/big-data-platform-superset -c superset -- \
  superset db upgrade && superset init
```

### Spark Kryo Serialization Error
**Cause:** Incorrect Kryo registrator class name.

See [DEBUG_GUIDE.md](DEBUG_GUIDE.md#error-failed_register_class_with_kryo)

### Hive Metastore Socket Closed Error
**Cause:** AWS SDK v1 vs v2 mismatch.

See [DEBUG_GUIDE.md](DEBUG_GUIDE.md#error-ttransportexception-socket-is-closed-by-peer)

---

## 🔄 Updating the Platform

All updates are managed via **GitOps**. To make changes:

1. **Edit configuration** in `big-data-platform/values.yaml`
2. **Commit and push** to the repository
3. **ArgoCD automatically syncs** the changes (usually within 3 minutes)
4. **Pods restart** with new configuration

Example:
```bash
# Change Superset admin password
vim big-data-platform/values.yaml
# Edit: superset.init.adminUser.password

git add big-data-platform/values.yaml
git commit -m "chore: update Superset admin password"
git push origin main

# ArgoCD syncs automatically
# Monitor via: argocd app get big-data-platform
```

### Manual Sync Trigger
```bash
kubectl -n argocd exec deploy/argocd-server -- \
  argocd app sync big-data-platform --force --prune
```

---

## 🐳 Rebuilding Docker Images

If you modify a Dockerfile (e.g., `docker/spark/Dockerfile`), the image is automatically rebuilt and pushed by GitHub Actions on `git push`.

Manual rebuild:
```bash
cd docker/spark
./build.sh  # Multi-arch build + push
```

**Note:** Update the image tag in `big-data-platform/values.yaml` after the image is pushed, so ArgoCD knows to pull the new version.

---

## 📚 Documentation

For detailed debugging steps, see [DEBUG_GUIDE.md](DEBUG_GUIDE.md).  
For known issues and resolutions, see [ISSUES.md](ISSUES.md).  
For architecture overview, see [ARCHITECTURE.md](ARCHITECTURE.md).
