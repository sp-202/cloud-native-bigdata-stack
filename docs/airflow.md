# 🌬 Apache Airflow on GKE - Detailed Guide

This guide explains the **architecture**, **synchronization**, and **operational patterns** for running Airflow in our Cloud-Native environment.

---

## 1. Architecture: The GitOps "Sidecar" Pattern

In traditional Airflow, you often need a shared filesystem (NFS/EFS) to share DAG files between the Scheduler, Webserver, and Workers. In Kubernetes, we prefer a **Stateless** approach using Object Storage (MinIO).

### How Sync Works
We use a "Sidecar" container pattern to sync DAGs from MinIO to the Airflow pod's local volume.

1.  **Storage**: DAGs are stored in the `dags` bucket in MinIO.
2.  **Sync**: A sidecar container (`minio-sync`) runs alongside the Airflow Scheduler.
3.  **Action**: Every 60 seconds (configurable), it runs `mc mirror` to pull changes from MinIO -> Local Pod Volume.
4.  **Result**: The Scheduler sees the files as if they were local.

**Why?**
*   **No NFS required**: Cheaper and simpler.
*   **Version Control**: You can treat MinIO as a build artifact repository.
*   **Stateless**: You can kill the Airflow pod, and it recovers full state on restart.

---

## 2. Configuration (`kubernetes/airflow.yaml`)

Airflow 2.0+ is configured almost entirely via Environment Variables.

| Variable                          | Value               | Purpose                                                                                 |
| :-------------------------------- | :------------------ | :-------------------------------------------------------------------------------------- |
| `AIRFLOW__CORE__EXECUTOR`         | `LocalExecutor`     | Runs tasks locally inside the pod. (Upgrade to `KubernetesExecutor` for massive scale). |
| `AIRFLOW__CORE__SQL_ALCHEMY_CONN` | `postgresql://...`  | DB Connection string. The "Brain" of Airflow.                                           |
| `AIRFLOW__CORE__DAGS_FOLDER`      | `/opt/airflow/dags` | Where the sidecar syncs files to.                                                       |
| `AIRFLOW__WEBSERVER__BASE_URL`    | `http://airflow...` | For generating links in emails/logs.                                                    |

---

## 3. Operations Guide

### A. Deploying a New DAG
You **do not** need to rebuild Docker images to add DAGs.
1.  Write your python file (`my_dag.py`).
2.  Upload it to MinIO:
    *   **UI**: Open MinIO Browser -> `dags` bucket -> Upload.
    *   **CLI**: `mc cp my_dag.py alias/dags/`
3.  Wait ~60 seconds.
4.  Refresh Airflow UI.

### B. Accessing Logs
*   **Scheduler Logs**:
    ```bash
    kubectl logs -n big-data -l app=airflow-scheduler -c airflow-scheduler
    ```
*   **Sync Sidecar Logs** (Debugging DAGs not appearing):
    ```bash
    kubectl logs -n big-data -l app=airflow-scheduler -c minio-sync
    ```

### C. Resource Tuning
*   **Webserver OOM**: If the UI goes blank, increase RAM limits (`resources.limits.memory`).
*   **Slow Scheduling**: If tasks hang in "Queued", increase CPU limits.

---

[⬅ Back to README](../README.md)
