# 🧱 00-Core: The Foundation

This directory establishes the prerequisites for the platform. Nothing else can run if these resources don't exist.

## 📄 Components

### 1. `namespaces.yaml`
Creates the logical isolation boundaries.
*   **`big-data`**: The main namespace where all our apps (Spark, Airflow, Zeppelin) reside.
*   (Note: Monitoring often runs in `default` or `monitoring`, while Traefik runs in `kube-system`).

### 2. `storage-class.yaml`
Defines *how* data is typically stored on Google Cloud (GKE).
*   **`standard` (default)**: Maps to `pd-standard` (HDD). Cheap, good for bulk logging or backups.
*   **`premium-rwo`**: Maps to `pd-ssd`. High IOPS. Used for **Postgres** and **Metadata** logic where speed matters.

### 3. `pv-pvc.yaml` & `pvc-*`
**Persistent Volume Claims**.
In Kubernetes, if a Pod dies, its filesystem is wiped. PVCs are requests for permanent disk.
*   **`postgres-pvc`**: Ensures Airflow/Superset metadata survives a restart.
*   **`minio-pvc`**: Ensures our "Data Lake" files aren't lost if MinIO restarts.

## 💡 Why separate this?
By keeping "Core" separate, we ensure that even if we delete the `03-apps` folder (redeployment), the **Data (00-core)** remains untouched. Storage has a different lifecycle than Compute.
