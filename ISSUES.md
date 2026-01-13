# Migration Issues Log

This document tracks issues encountered during the migration from Unity Catalog to Hive Metastore (HMS) and their resolution status.

## 1. Hive Metastore (HMS) Startup Failures

### 1.1 Missing Database Driver
**Issue:**  
HMS container (`apache/hive:4.0.0`) failed to start with `ClassNotFoundException: org.postgresql.Driver`. The official image does not include the Postgres JDBC driver.

**Resolution:**  
Modified `hms.yaml` to include an `initContainer` that downloads `postgresql-42.6.0.jar` and mounts it to `/opt/hive/lib` using a `subPath` volume mount (to avoid overwriting existing jars).

### 1.2 Missing Database
**Issue:**  
HMS failed to initialize because the backend database `metastore_db` did not exist in the Postgres service.
```
FATAL: database "metastore_db" does not exist
```

**Resolution:**  
Manually connected to the Postgres pod and created the database:
```sql
CREATE DATABASE metastore_db OWNER hive;
GRANT ALL PRIVILEGES ON DATABASE metastore_db TO hive;
```

### 1.3 Incorrect Default Configuration (Derby)
**Issue:**  
HMS attempted to connect to an embedded Derby database instead of Postgres, despite environment variables being set. This indicates `hive-site.xml` was defaults or missing.
```
Metastore connection URL: jdbc:derby:;databaseName=metastore_db;create=true
```

**Resolution:**  
Created a ConfigMap `hive-config` containing a proper `hive-site.xml` with Postgres connection details and S3A configurations, and mounted it to `/opt/hive/conf/hive-site.xml`.

### 1.4 Missing S3A Support Jars
**Issue:**  
Spark jobs failed with `ClassNotFoundException: org.apache.hadoop.fs.s3a.S3AFileSystem` when trying to write to S3 via HMS. The HMS image lacks the AWS Hadoop libraries required for S3A support.

**Resolution:**  
Updated the `initContainer` in `hms.yaml` to download:
- `hadoop-aws-3.3.6.jar` (Matches HMS Hadoop version 3.3.6)
- `aws-java-sdk-bundle-1.12.367.jar`

## 2. StarRocks Integration Issues

### 2.1 Native Delta Catalog Support
**Issue:**  
StarRocks 3.3 failed to create a catalog of type `delta_lake`.
```
ERROR 1064 (HY000): ... [type : delta_lake] is not supported.
```
**Resolution:**  
Functionality verified using `type = 'hive'` catalog (`hms_test`), which successfully connects to HMS. Native `delta_lake` type appears to be unavailable in the current image `starrocks/fe-ubuntu:3.3-latest`.

### 2.2 Backend Node Failure
**Issue:**  
StarRocks frontend reported the backend node as "alive: false" during verification queries.
```
Backend node not found. Check if any backend node is down.backend: [10.100.1.152 alive: false]
```

**Resolution:**  
(Resolved) Restarted StarRocks BE pod. New pod `starrocks-be-0` came up with IP `10.100.1.60`. Dropped stale backend `10.100.1.152` and registered the new one using `ALTER SYSTEM ADD BACKEND`.

## 3. Deployment & Configuration

### 3.1 Spark Image Updates
**Update:**  
Updated `spark-defaults.yaml`, `jupyterhub.yaml`, and `marimo.yaml` to use the unified image `subhodeep2022/spark-bigdata:spark-4.0.1-uc-fix-v3` to ensure consistency across all services.

### 3.2 MinIO Bucket Missing
**Issue:**  
E2E verification job failed because the target bucket `test-bucket` did not exist.

**Resolution:**  
Manually created the bucket using `aws s3 mb s3://test-bucket`.
