# Connecting Spark/Hive Data to Superset

This guide explains how to connect your processed data from Spark SQL to Apache Superset for visualization.

## Method 1: Direct Hive Metastore Connection (Recommended)

Superset can connect directly to your Hive Metastore to query tables created in Spark.

### Steps:

1. **Login to Superset**
   - URL: `http://localhost:8088` (or `http://YOUR_SERVER_IP:8088`)
   - Username: `admin`
   - Password: `admin`

2. **Add Database Connection**
   - Click on **Settings** (⚙️) → **Database Connections**
   - Click **+ Database** button
   - Select **Supported Databases** → Choose **Apache Hive**
   
3. **Configure Hive Connection**
   - **Display Name**: `Hive Metastore`
   - **SQLAlchemy URI**: `hive://hive-metastore:10000/default`
   
   > **Note**: The Hive Metastore service runs on port 9083 (Thrift), but HiveServer2 (which Superset connects to) would need to be running on port 10000. Since we only have the Metastore, use Method 2 instead.

## Method 2: Query Hive Tables via Spark Thrift Server (Alternative)

If you want to access Hive tables through Spark, you would need to set up Spark Thrift Server.

## Method 3: PostgreSQL Direct Connection (For Persisted Data)

If you're storing your processed results in PostgreSQL tables, you can connect directly.

### Steps:

1. **Add Database Connection**
   - Click on **Settings** → **Database Connections**
   - Click **+ Database** button
   - Select **PostgreSQL**

2. **Configure PostgreSQL Connection**
   - **Display Name**: `Hive Metastore DB`
   - **SQLAlchemy URI**: `postgresql://hive:hive@hive-metastore-postgresql:5432/metastore`
   
3. **Test Connection**
   - Click **Test Connection** to verify
   - Click **Connect** to save

4. **Query Tables**
   - Go to **SQL Lab** → **SQL Editor**
   - Select your database
   - Write queries against your Hive metadata tables

## Method 4: Export to MinIO/S3 and Use Presto/Trino (Advanced)

For production-scale dashboards, consider:
1. Writing Spark results to Parquet files in MinIO (S3)
2. Setting up Presto/Trino to query those files
3. Connecting Superset to Presto/Trino

## Recommended Workflow

For your current setup, the best approach is:

1. **Create tables in Spark SQL** using Hive
2. **Query the Hive Metastore PostgreSQL database** directly from Superset to see table metadata
3. **For actual data visualization**, consider adding SparkSQL Thrift Server or export results to a dedicated database

## Quick Test

Try this in Superset SQL Lab:

```sql
-- Connect to hive-metastore-postgresql
SELECT * FROM "DBS" LIMIT 10;
SELECT * FROM "TBLS" LIMIT 10;
```

This will show you the databases and tables created in Hive.
