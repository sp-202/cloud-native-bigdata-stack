# 🧠 03-Apps: The Application Layer

This directory contains the actual Big Data logic. Every application here connects to the **02-Database** layer for state and **01-Networking** for access.

## 📂 Sub-Directorires

### `airflow/`
*   **Role**: Workflow Orchestrator.
*   **Key File**: `airflow-deployment.yaml`. Defines the Scheduler and Webserver.
*   **Config**: Uses `env` vars to connect to Postgres and MinIO (for DAG sync).

### `spark-operator/`
*   **Role**: Kubernetes Operator for Spark.
*   **Function**: Watches for `SparkApplication` YAMLs and creates Pods.
*   **Key**: Includes `service-account.yaml` which grants Spark permission to create pods.

### `notebooks/`
*   **JupyterHub**: The primary IDE. Features Apache Toree (Scala), SQL Magics, and `z.show()` formatting.
*   **Marimo**: Reactive Python platform. Ideal for data dashboards and interactive widgets.
*   **Polynote**: IDE-like experience with first-class Scala/Python interoperability.

### `superset/`
*   **Role**: BI & Analytics.
*   **Init Job**: Includes a `k8s-init` job that runs `superset fab create-admin` and `superset init` automatically on deploy.

### `hive-metastore/`
*   **Role**: The Bridge between Spark and Data.
*   **Function**: Translates "Table X" to "s3a://bucket/path/to/x".
*   **Backend**: Connects to `postgres` (metastore db) and `minio` (warehouse directory).

## 🔗 How they connect
*   **Airflow** triggers **Spark**.
*   **Spark** talks to **Hive** to find data.
*   **Hive** points Spark to **MinIO**.
*   **Superset** reads from **Hive/Spark** to visualize.
*   **Notebooks** (Jupyter/Marimo/Polynote) provide the UI to write and run Spark code.
