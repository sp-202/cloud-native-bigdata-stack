# 🧱 00-Core: The Foundation

This directory establishes the prerequisites for the platform. Nothing else can run if these resources don't exist.

## 📄 Components

### 1. `namespaces.yaml`
Creates the logical isolation boundaries for the platform workloads.

### 2. `persistence.yaml`
Defines PersistentVolumeClaims (PVCs) for stateful services.
*   **OpenEBS `openebs-hostpath`** is the default StorageClass, providing **dynamic provisioning** of local node storage. No manual PV creation is needed.
*   PVCs are created here for services like PostgreSQL, MinIO, Prometheus, and Airflow logs.

## 💡 Why separate this?
By keeping "Core" separate, we ensure that even if we delete the `03-apps` folder (redeployment), the **Data (00-core)** remains untouched. Storage has a different lifecycle than Compute.
