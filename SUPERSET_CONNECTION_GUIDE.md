# Connecting Spark/Hive Data to Superset

This guide explains how to connect your processed data and metadata to Apache Superset for visualization.

## Primary Connection: Hive Metastore (PostgreSQL)

To visualize tables and metadata managed by the Hive Metastore, connect Superset directly to the backend PostgreSQL database.

### Connection Details

*   **Database Type**: PostgreSQL
*   **Host**: `hive-metastore-postgresql`
*   **Port**: `5432`
*   **Database Name**: `metastore`
*   **Username**: `hive`
*   **Password**: `hive`

### SQLAlchemy URI

Use the following URI in the Superset "Add Database" configuration:

```
postgresql+psycopg2://hive:hive@hive-metastore-postgresql:5432/metastore
```

### Steps to Add Connection

1.  Login to Superset (`http://localhost:8088`).
2.  Navigate to **Settings** (⚙️) -> **Database Connections**.
3.  Click **+ Database**.
4.  Select **PostgreSQL**.
5.  Enter the **SQLAlchemy URI** provided above.
6.  Click **Test Connection** to verify.
7.  Click **Connect**.

## Alternative: Querying Data via Spark Thrift Server

For direct data querying (not just metadata), you can configure the Spark Thrift Server (if enabled) and connect via the Hive driver.

*   **URI**: `hive://hive-server:10000/default`

> **Note**: Ensure the `hive-server` service is running and accessible on the `databricks-net` network.
