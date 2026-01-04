# 💾 02-Database: The State Layer

Cloud-Native apps should be **Stateless**. This directory provides the **Stateful** backends that the apps rely on.

## 📄 Components

### 1. Postgres (`postgres/`)
A single PostgreSQL instance that acts as the metadata backbone.
*   **Database `airflow_db`**: Stores DAG run history, task status, and variables.
*   **Database `hive_metastore`**: Stores the Schema (Table names, columns, S3 locations) for our Data Lake.
*   **Database `superset`**: Stores Dashboard configurations and users.

**Why single instance?**
For this scale, a single shared Postgres is cost-efficient and easier to manage than 3 separate RDS instances.

### 2. MinIO (`minio/`)
This is our **Data Lake**.
*   **API**: 100% S3 Compatible.
*   **Role**: Stores the actual Big Data files (Parquet, CSV, Delta Lake) and Logs (Spark Event Logs).
*   **Why MinIO?**: It allows us to simulate a Cloud environment (like AWS S3 or GCS) locally or on bare-metal K8s.

### 3. Redis (`redis/`)
*   **Role**: High-speed In-Memory Cache.
*   **User**: Primarily used by **Superset** to cache query results so dashboards load instantly on refresh.
