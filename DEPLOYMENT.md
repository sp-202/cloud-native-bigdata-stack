# Deployment Guide

This guide describes how to deploy the entire Spark, Hive, and Superset stack from scratch on a K3s cluster.

## 1. Prerequisites
- **K3s Cluster**: A running Kubernetes cluster.
- **Helm**: Version 3+ installed.
- **Docker**: For building custom images (optional if using provided images).

## 2. Infrastructure Setup
Run the automated deployment script to create PVCs, Databases, and Core Services.

```bash
./deploy.sh
```

This script automates the following steps:
1.  **Storage**: Creates Persistent Volume Claims for MinIO, Postgres, and Zeppelin.
2.  **Databases**: Deploys Postgres (Shared) and MinIO (S3 Object Storage).
3.  **Core Services**: Deploys Hive Metastore and Airflow.
4.  **Compute**: Deploys Zeppelin and applies Spark configurations.
5.  **Visualization**: Installs Apache Superset via Helm.

## 3. Custom Images
The platform uses custom Docker images for Hive and Spark to include necessary dependencies (AWS SDKs, Postgres drivers).

To rebuild and push these images to your registry:
```bash
./build_and_push.sh
```
*Note: Ensure you are logged into Docker Hub (`docker login`) before running.*

## 4. Manual Verification
After deployment, verify all pods are running:

```bash
kubectl get pods
```

### Expected Output
- `hive-metastore-xxx` (2/2 Running)
- `postgres-xxx` (1/1 Running)
- `minio-xxx` (1/1 Running)
- `zeppelin-xxx` (1/1 Running)
- `superset-xxx` (1/1 Running)

## 5. Accessing Services
Refer to `walkthrough.md` for connection details and credentials.
