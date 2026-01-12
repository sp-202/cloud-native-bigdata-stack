# Data Lakehouse Architecture & Troubleshooting Guide

**Date:** 2026-01-12
**Status:** Architecture Validated | Configuration Tweaks Required

## 1. System Architecture
This deployment integrates **Spark**, **Unity Catalog OSS**, and **StarRocks** into a coherent Data Lakehouse.

### Component Matrix
| Component | Version | Role | Configuration Note |
| :--- | :--- | :--- | :--- |
| **Apache Spark** | **4.0.1** (Scala 2.13) | **Writer** (ETL) | Uses Native UC Client (`UCSingleCatalog`) + UniForm |
| **Unity Catalog** | **0.3.1** (OSS) | **Metadata** | Serving Iceberg protocol at `:8080` |
| **StarRocks** | **3.3** | **Reader** (Analytics) | Consumes UC via Iceberg REST interface |
| **MinIO** | Latest | **Storage** (S3) | Bucket: `test-bucket` |

---

## 2. Issues & Fixes Applied

### ✅ Fix 1: StarRocks Connectivity ("Backend node not found")
**Symptom:** StarRocks queried `Alive: false` for its Backend node.
**Root Cause:** Cluster ID mismatch between Frontend (`372192325`) and Backend (`1919895350`) due to persistent storage from a previous installation.
**Fix:**
1.  Wiped Backend storage (`rm -rf /data/storage/*`).
2.  Re-registered Backend to Frontend.
3.  **Result**: Backend is now `Alive`.

### ✅ Fix 2: Spark Writer Mode ("Unsupported Endpoint")
**Symptom:** Spark verification job failed with `UnsupportedOperationException: POST /tables`.
**Root Cause:** We attempted to use the *Iceberg Client* (`SparkCatalog`) to write to UC OSS. UC OSS requires the *Native Client* (`UCSingleCatalog`) for Delta tables.
**Fix:**
1.  Switched `spark-defaults.yaml` to use `io.unitycatalog.spark.UCSingleCatalog`.
2.  Enabled **UniForm** (`spark.databricks.delta.universalFormat.enabledFormats = iceberg`) so writes generate the Iceberg metadata StarRocks needs.

### 🔍 Current Issue: NullPointerException in StarRocks
**Symptom:**
```text
server error: NullPointerException: Cannot invoke "io.unitycatalog.server.service.credential.aws.S3StorageConfig.getRegion()" because "s3StorageConfig" is null
```
**Root Cause Analysis:**
1.  **Mismatch**: The table `uniform_test_simple` was created with storage location `s3://warehouse/test_simple`.
    *   *Note: This likely happened because the Spark configuration `spark.sql.catalog.unity.warehouse` defaulted to `s3://warehouse` or was misconfigured during creation.*
2.  **Server Config**: The Unity Catalog Server (`unity-catalog-server-config.yaml`) is **ONLY** configured to vend credentials for `s3://test-bucket`.
    ```properties
    s3.bucketPath.0=s3a://test-bucket
    ```
3.  **The Crash**: When StarRocks asks UC for credentials to read `s3://warehouse/test_simple`, UC looks for a config for bucket `warehouse`. Finding none, it returns `null` for the config object, and code subsequently crashes on `.getRegion()`.

3.  **The Crash**: When StarRocks asks UC for credentials to read `s3://warehouse/test_simple`, UC looks for a config for bucket `warehouse`. Finding none, it returns `null` for the config object, and code subsequently crashes on `.getRegion()`.

### ✅ Fix 4: Port Conflict (ClosedChannelException)
**Symptom:** Spark failed to connect to Unity Catalog with `java.nio.channels.ClosedChannelException` and `Connection refused` on port 8080.
**Root Cause:** Port 8080 is often congested or used by other services (e.g., Spark Master Web UI).
**Fix:**
1.  **Migrated Unity Catalog Server** to port **8085**.
2.  Updated K8s Service `uc-service-8085.yaml` to map port 8085.
3.  Updated Spark Config `spark.sql.catalog.unity.uri` to `http://unity-catalog-unitycatalog-server:8085`.
4.  Updated StarRocks Catalog `iceberg.catalog.uri` to `http://unity-catalog-unitycatalog-server:8085/...`.

### ❌ Ongoing Issue: AWS SDK Dependency Conflict
**Symptom:** Spark Verification Job fails with:
`Caused by: java.lang.ClassNotFoundException: software.amazon.awssdk.awscore.exception.AwsServiceException`
**Root Cause:**
1.  **Unity Catalog Spark Connector** (in Docker Image) depends on **AWS SDK V2** (`software.amazon.awssdk`).
2.  **Hadoop AWS** (in Docker Image 3.4.0) depends on **AWS SDK V1** (`com.amazonaws`).
3.  **Classloader Isolation:** Runtime injection (via `--packages` or `wget`) places SDK V2 in the *User Classpath*, but Unity Catalog (loaded by *Parent/System Classpath*) cannot see it.
**Required Fix:**
*   **Rebuild Docker Image**: The `aws-java-sdk-bundle` (V2) must be baked into `/opt/spark/jars/` during build time to be visible to the System Classloader. Runtime patching proved unreliable.

---

## 3. Resolution Plan

### Next Step (User Action Required)
**Rebuild Spark Docker Image** with the following changes:
1.  **Dependencies:** Ensure both AWS SDK V1 (for Hadoop) AND AWS SDK V2 (for Unity Catalog) are present in `/opt/spark/jars/`.
2.  **Dockerfile Update:**
    ```dockerfile
    ENV AWS_SDK_VERSION=1.12.638  # V1 for Hadoop
    ENV AWS_SDK_V2_VERSION=2.20.162 # V2 for Unity Catalog
    
    # Download V1
    RUN wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar -P $SPARK_HOME/jars/
    # Download V2
    RUN wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_V2_VERSION}/bundle-${AWS_SDK_V2_VERSION}.jar -P $SPARK_HOME/jars/
    ```

### Post-Rebuild Verification
Re-create the table explicitly inside the supported bucket (`test-bucket`).

**Run this in Spark:**
```python
# Explicitly set the location to the supported bucket
spark.sql("""
    CREATE TABLE unity.default.fixed_table (
        id INT, 
        data STRING
    ) USING DELTA
    LOCATION 's3a://test-bucket/fixed_table'
""")
```

### Permanent Configuration Fix
Ensure `spark-defaults.yaml` points `spark.sql.catalog.unity.warehouse` correctly to `s3a://test-bucket/warehouse/`.

---

## 4. StarRocks Configuration (Reference)
Correct syntax for the External Catalog to read UC OSS:

```sql
CREATE EXTERNAL CATALOG uc_iceberg_catalog
PROPERTIES (
    'type' = 'iceberg',
    'iceberg.catalog.type' = 'rest',
    'iceberg.catalog.uri' = 'http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/iceberg',
    'iceberg.catalog.warehouse' = 'unity',  -- MUST match the Catalog Name in UC
    'aws.s3.enable_ssl' = 'false',
    'aws.s3.enable_path_style_access' = 'true',
    'aws.s3.endpoint' = 'http://minio.default.svc.cluster.local:9000',
    'aws.s3.access_key' = 'minioadmin',
    'aws.s3.secret_key' = 'minioadmin'
);
```

## 5. Query Syntax
```sql
-- Use backticks for reserved keywords like 'default'
SELECT * FROM uc_iceberg_catalog.`default`.fixed_table;
```
