# 🧠 03-Apps: The Application Layer

This directory contains the Big Data application manifests. Every application here connects to the **02-Database** layer for state and **01-Networking** for external access.

## 📄 Components

### Airflow (`airflow.yaml`, `airflow-git-sync.yaml`)
*   **Role**: Workflow Orchestrator.
*   **Scheduler & Webserver** are defined in `airflow.yaml`.
*   **Git-Sync**: `airflow-git-sync.yaml` deploys a sidecar that automatically pulls DAGs from a Git repository.
*   **RBAC**: `airflow-rbac.yaml` and `airflow-spark-rbac.yaml` provide Kubernetes permissions for Airflow to launch Spark pods.

### Spark Connect Server (`spark-connect-server.yaml`)
*   **Role**: A shared, long-running Spark gateway.
*   **Function**: Clients (JupyterHub, Marimo) connect via Spark Connect protocol instead of each spawning their own Spark driver.
*   **Benefits**: Reduced resource usage, shared Spark sessions, and centralized Spark configuration.

### Spark History Server (`spark-history-server.yaml`)
*   **Role**: Web UI for reviewing completed Spark job logs.
*   **Function**: Reads Spark event logs from MinIO (S3) and presents them via a web interface.

### JupyterHub (`jupyterhub.yaml`)
*   **Role**: Primary interactive notebook IDE.
*   **Features**: Apache Toree (Scala kernel), SQL Magics, `z.show()` formatting, and Spark Connect integration.

### Superset (`superset-values.yaml`)
*   **Role**: BI & Analytics.
*   **Init Job**: Helm chart includes an init job that runs `superset fab create-admin` and `superset init` on deploy.

### Hive Metastore (`hive.yaml`, `hms.yaml`)
*   **Role**: The bridge between Spark and Data.
*   **Function**: Translates "Table X" to `s3a://bucket/path/to/x`.
*   **Backend**: Connects to PostgreSQL (metastore db) and MinIO (warehouse directory).

### StarRocks (`starrocks.yaml`)
*   **Role**: High-performance OLAP database.
*   **Function**: Reads directly from MinIO via Delta Native Catalog for sub-second analytical queries.

### Spark Operator (Helm Chart)
*   **Role**: Kubernetes Operator for Spark.
*   **Function**: Watches for `SparkApplication` CRDs and manages Spark Driver/Executor pods.

## 🔗 How they connect
*   **Airflow** triggers **Spark** jobs via the Spark Operator.
*   **Spark** (and Spark Connect) talks to **Hive Metastore** to find table locations.
*   **Hive** points Spark to **MinIO** for the actual data files.
*   **Superset** reads from **Hive/StarRocks** to visualize data.
*   **JupyterHub** connects to **Spark Connect Server** for interactive development.
