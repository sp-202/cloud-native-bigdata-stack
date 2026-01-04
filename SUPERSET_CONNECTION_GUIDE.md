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

## 4. Troubleshooting Common Issues

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
