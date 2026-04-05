# 🔌 Superset Connection Guide

This guide details how to connect Apache Superset to the data sources running within your Kubernetes cluster.

---

## 1. Concepts: How Superset Connects

Superset uses **SQLAlchemy** drivers to connect to databases. Since Superset is running *inside* the Kubernetes cluster, it can talk to other services (like Hive or Postgres) using their **DNS Service Names**.

*   **Format**: `dialect+driver://username:password@host:port/database`
*   **Internal Domain**: In Kubernetes, services are reachable at `<service-name>.<namespace>.svc.cluster.local`.

---

## 2. Connecting to Hive (The Data Lake)

This is the primary connection for querying your Big Data (Parquet/Delta/CSV tables) registered in the Metastore.

### Step-by-Step
1.  Login to Superset (`admin` / `admin`).
2.  Navigate to **Settings** (top right) -> **Database Connections**.
3.  Click **+ Database**.
4.  Select **Apache Hive**. (If not listed, look for "Other").
5.  **Enter the SQLAlchemy URI**:
    ```
    hive://hive:hive@hive-metastore.big-data.svc.cluster.local:10000/default?auth=NOSASL
    ```

    **Breakdown of the URI**:
    *   `hive://`: Protocol.
    *   `hive:hive`: Username/Password (Default for our installation).
    *   `hive-metastore`: Service name of the Hive Server.
    *   `big-data`: Namespace where Hive is running.
    *   `10000`: Hive Thrift Server port.
    *   `?auth=NOSASL`: **CRITICAL**. Disables SASL authentication which is the default for the Python client but usually off for simple Hive setups.

6.  Click **Test Connection**. It should turn green.
7.  Click **Connect**.

---

## 3. Connecting to PostgreSQL (Metadata)

You might want to query the Airflow or Hive metadata schemas directly.

### Step-by-Step
1.  Go to **+ Database**.
2.  Select **PostgreSQL**.
3.  **Enter the SQLAlchemy URI**:
    ```
    postgresql://postgres:postgres@postgres-db.big-data.svc.cluster.local:5432/airflow_db
    ```
    *(Replace `airflow_db` with `hive_metastore` to query Hive internals)*.

4.  Test and Connect.

---

## 4. Connecting to StarRocks (OLAP)

StarRocks provides high-performance real-time analytics. It is MySQL-compatible and can query Iceberg tables stored in MinIO via the Gravitino REST Catalog.

### Step-by-Step: Add StarRocks Database in Superset

1.  Go to **Settings** → **Database Connections** → **+ Database**.
2.  Select **MySQL** (StarRocks is MySQL-wire-protocol compatible; the native StarRocks dialect may not be installed).
3.  **Enter the SQLAlchemy URI**:
    ```
    mysql+pymysql://root:@starrocks-cluster-fe-service.default.svc.cluster.local:9030/
    ```
    - No password for the root user (StarRocks default).
    - Leave the database name empty — use fully-qualified names in SQL instead.
4.  Under **Advanced → SQL Lab**, enable **Allow DML** and **Allow multi-statement queries**.
5.  Click **Test Connection** then **Connect**.

### Querying Iceberg Tables (via `iceberg_gravitino` catalog)

StarRocks has an external catalog `iceberg_gravitino` pre-configured to read Iceberg tables from Gravitino's REST Catalog (backed by MinIO S3 + PostgreSQL).

In **SQL Lab**, use three-part naming:

```sql
-- List namespaces (databases) in the Iceberg catalog
SHOW DATABASES FROM iceberg_gravitino;

-- List tables in a namespace
SHOW TABLES FROM iceberg_gravitino.sales;

-- Query the Iceberg table written by Spark
SELECT * FROM iceberg_gravitino.sales.sales_records LIMIT 10;

-- Aggregation example
SELECT
    product,
    SUM(price * quantity) AS total_revenue,
    SUM(quantity)         AS total_units,
    COUNT(*)              AS num_orders
FROM iceberg_gravitino.sales.sales_records
GROUP BY product
ORDER BY total_revenue DESC
LIMIT 20;
```

### Creating a View for the Superset Table Browser

The Superset table browser only shows tables in the connected database, not external catalog tables. Create a view in StarRocks's internal catalog to expose them:

```sql
-- Create a database first if needed
CREATE DATABASE IF NOT EXISTS lakehouse;

-- Create a view pointing to the Iceberg table
CREATE VIEW lakehouse.sales_records AS
SELECT * FROM iceberg_gravitino.sales.sales_records;
```

Connect Superset to `mysql+pymysql://root:@starrocks-cluster-fe-service.default.svc.cluster.local:9030/lakehouse` and the view will appear in the table browser.

### Setting Up the `iceberg_gravitino` Catalog in StarRocks

If the catalog is missing (e.g. after a StarRocks FE restart), recreate it with:

```sql
CREATE EXTERNAL CATALOG iceberg_gravitino
COMMENT 'Iceberg via Gravitino REST Catalog (port 9001)'
PROPERTIES (
    'type'                                  = 'iceberg',
    'iceberg.catalog.type'                  = 'rest',
    'iceberg.catalog.uri'                   = 'http://gravitino.default.svc.cluster.local:9001/iceberg/',
    -- Iceberg file IO credentials (used by StarRocks Iceberg layer)
    'iceberg.catalog.io-impl'               = 'org.apache.iceberg.aws.s3.S3FileIO',
    'iceberg.catalog.s3.endpoint'           = 'http://minio.default.svc.cluster.local:9000',
    'iceberg.catalog.s3.path-style-access'  = 'true',
    'iceberg.catalog.s3.access-key-id'      = 'minioadmin',
    'iceberg.catalog.s3.secret-access-key'  = 'minioadmin',
    -- Native S3 credentials (used by StarRocks BE data reader)
    'aws.s3.use_instance_profile'           = 'false',
    'aws.s3.access_key'                     = 'minioadmin',
    'aws.s3.secret_key'                     = 'minioadmin',
    'aws.s3.region'                         = 'us-east-1',
    'aws.s3.endpoint'                       = 'minio.default.svc.cluster.local:9000',
    'aws.s3.enable_path_style_access'       = 'true',
    'aws.s3.enable_ssl'                     = 'false'
);
```

> **Why both property sets?** StarRocks uses `iceberg.catalog.s3.*` for its Iceberg metadata layer (Java) and `aws.s3.*` for its native C++ data reader. Both must be set for MinIO to work correctly.

### Available External Catalogs
| Catalog | Type | Description |
|---------|------|-------------|
| `iceberg_gravitino` | Iceberg REST | Spark/Gravitino Iceberg tables at `s3://warehouse/iceberg/` via port 9001 |
| `default_catalog` | Internal | StarRocks native tables |

---

## 5. Troubleshooting Common Issues

### ❌ Error: `TSocket read 0 bytes`
*   **Cause**: Authentication protocol mismatch.
*   **Fix**: Ensure you appended `?auth=NOSASL` to the end of your Hive URI.

### ❌ Error: `Could not resolve host`
*   **Cause**: You might be using `localhost` or an external IP.
*   **Fix**: Since Superset is **inside** the cluster, you must use the internal Kubernetes DNS name: `hive-metastore.big-data.svc.cluster.local`.

### ❌ Error: `Invalid table alias` or `Graph Parsing Error`
*   **Cause**: Hive generates column names that Superset's strict SQL parser doesn't like, or reserved keywords (like `type`, `date`) are used as column names without quotes.
*   **Fix**:
    1.  Go to **SQL Lab** in Superset.
    2.  Write a custom SQL query: `SELECT "type" as type_col, ... FROM my_table`.
    3.  Save this query as a **Dataset** (Explore -> Save as Dataset).
    4.  Use the Dataset for building charts instead of the raw table.
