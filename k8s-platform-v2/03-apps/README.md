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

### `zeppelin/`
*   **Role**: Interactive Notebooks.
*   **Mode**: Runs in "Client Mode", acting as a long-running Spark Driver.

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
*   **Zeppelin** provides the UI to write the Spark code.
