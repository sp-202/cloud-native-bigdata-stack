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

## 🆘 Troubleshooting

- **CrashLoopBackOff**: Check logs (`kubectl logs -p pod-name`). Common causes include database unavailability or missing S3 buckets.
- **Pending Pods**: Check for `FailedScheduling` or `FailedMount` events (`kubectl describe pod`). Verify that local storage directories exist on the node.
