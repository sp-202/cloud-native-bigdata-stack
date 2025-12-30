# 🌬 Apache Airflow - Detailed Guide

## 1. Architecture: The "Sidecar" Sync Pattern
Standard Airflow relies on a shared file system (NFS/EFS) for DAGs. In our cloud-native GKE setup, we use **MinIO (S3)** as the source of truth to avoid complex storage drivers.

### How it Works (`kubernetes/airflow.yaml`)
1.  **User Action**: You upload `my_dag.py` to MinIO bucket `dags`.
2.  **Sidecar Container**: Inside the Airflow Pod, a container named `minio-sync` runs `mc mirror` every 60 seconds.
3.  **Local Volume**: Use an `emptyDir` volume shared between the Sidecar and the Airflow Scheduler/Webserver.
4.  **Result**: Airflow sees the file as if it were local.

**Why?**: This makes the cluster "Stateless". You can delete the Airflow Pods, and they will re-download the DAGs from MinIO on startup.

## 2. Configuration (Environment Variables)
Airflow is configured entirely via Environment Variables in `kubernetes/airflow.yaml`.

| Variable | Value | Explanation |
| :--- | :--- | :--- |
| `AIRFLOW__CORE__EXECUTOR` | `LocalExecutor` | We run a single Scheduler/Worker pod for simplicity. For scale, switch to `KubernetesExecutor`. |
| `AIRFLOW__CORE__SQL_ALCHEMY_CONN` | `postgresql://...` | Connection string to the `postgres` service. |
| `AIRFLOW__CORE__FERNET_KEY` | `...` | Encryption key for passwords in the DB. **Must be consistent across restarts.** |
| `_AIRFLOW_WWW_USER_CREATE` | `true` | Auto-creates the Admin user on startup. |

## 3. Resource Tuning
*   **Webserver**: The UI is heavy. We bumped limits to `2Gi` RAM.
    *   **Symptom**: "Airflow UI is white/blank" -> OOM (Out Of Memory).
    *   **Fix**: Increase `resources.limits.memory`.
*   **Scheduler**: Needs CPU. If tasks are late, increase `cpu: 1000m`.

## 4. Common Issues
*   **DAG not showing up**:
    1.  Check Sidecar logs: `kubectl logs -l app=airflow-scheduler -c minio-sync`.
    2.  Check MinIO bucket: Is the file actually there?
*   **"Task stuck in Queued"**:
    1.  Check Scheduler logs: `kubectl logs -l app=airflow-scheduler -c airflow-scheduler`.
    2.  Is the DB full? (Unlikely with 10GB PVC).
