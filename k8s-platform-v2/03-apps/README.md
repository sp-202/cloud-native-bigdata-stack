# 🧠 03-Apps: The Application Layer

This directory contains the actual Big Data logic. Every application here connects to the **02-Database** layer for state and **01-Networking** for access.

## 📂 Components

### `airflow.yaml`
*   **Role**: Workflow Orchestrator.
*   **Key Features**: Scheduler and Webserver deployment.
*   **Config**: Uses `env` vars to connect to Postgres and MinIO (for DAG sync).

### `spark-connect-server.yaml`
*   **Role**: Centralized Spark compute server.
*   **Function**: Runs Spark in client mode with 4 dynamic executors, exposes gRPC endpoint on port 15002.
*   **Features**: Delta Lake extensions, HMS integration, S3A storage.

### `jupyterhub.yaml`
*   **Role**: Interactive thin-client notebooks.
*   **Features**: Connects to Spark Connect Server via `SPARK_REMOTE` environment variable.
*   **S3 Persistence**: Uses `s3contents` for notebook storage in MinIO.

### `marimo.yaml`
*   **Role**: Reactive Python notebooks.
*   **Features**: Ideal for data dashboards and interactive widgets.

### `hms.yaml`
*   **Role**: Hive Metastore 4.0.0.
*   **Function**: Standalone Thrift service translating table names to S3 paths.
*   **Backend**: PostgreSQL for metadata, MinIO for warehouse directory.

### `starrocks.yaml`
*   **Role**: High-performance OLAP database.
*   **Features**: Auto-initializes `hms_delta_catalog` for Delta Lake queries.
*   **Components**: Frontend (FE) and Backend (BE) StatefulSets.

### `superset-values.yaml`
*   **Role**: BI & Analytics configuration.
*   **Features**: Helm values for Superset deployment with Redis caching.

## 🔗 How they connect
*   **Airflow** triggers **Spark** jobs.
*   **JupyterHub** connects to **Spark Connect Server** for compute.
*   **Spark Connect Server** talks to **Hive Metastore** for table metadata.
*   **Hive Metastore** points to **MinIO** for data storage.
*   **StarRocks** reads Delta tables directly from **MinIO** via its HMS catalog.
*   **Superset** connects to **StarRocks** for sub-second analytics queries.
