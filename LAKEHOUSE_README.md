⚠️ Updated documentation as of 2026-01-15. See CHANGELOG for details.

# Data Lakehouse Architecture & Troubleshooting Guide

**Date:** 2026-01-13
**Status:** Architecture Validated | Production Ready

## 1. System Architecture
This deployment integrates **Spark**, **Hive Metastore (HMS)**, and **StarRocks** into a coherent Data Lakehouse.

### Component Matrix
| Component | Version | Role | Configuration Note |
| :--- | :--- | :--- | :--- |
| **Apache Spark** | **4.0.1** (Scala 2.13) | **Writer** (ETL) | Writes Delta Tables to MinIO; Registers in HMS |
| **Hive Metastore** | **3.1.3** | **Metadata** | Standalone Thrift Service (`thrift://hive-metastore:9083`) |
| **StarRocks** | **3.x** | **Reader** (Analytics) | Reads MinIO directly via Native Delta Catalog |
| **MinIO** | Latest | **Storage** (S3) | Bucket: `test-bucket` |

---

## 2. Recent Issues & Fixes Applied

### ✅ Fix 1: Spark Auto-Initialization Failure
**Symptom:** `NameError: name 'spark' is not defined` in notebooks.
**Root Cause:** Spark Driver Pod name mismatch in Client Mode.
**Fix:** Dynamically injected `spark.kubernetes.driver.pod.name` in `setup-kernels.sh` to match `${HOSTNAME}`.

### ✅ Fix 2: Missing AWS SDK Dependencies
**Symptom:** `NoClassDefFoundError: software/amazon/awssdk/...` during S3 writes.
**Root Cause:** Conflict between Hadoop's AWS SDK v1 and Spark's need for SDK v2.
**Fix:** Rebuilt Spark image (`fix-v4`) including:
*   `hadoop-aws:3.3.4`
*   `software.amazon.awssdk:bundle:2.20.160`

### ✅ Fix 3: Configuration Parsing Error ("60s")
**Symptom:** `NumberFormatException: For input string: "60s"`.
**Root Cause:** Hadoop configuration defaults (`fs.s3a.threads.keepalivetime`) use time suffixes that this Spark/Delta stack couldn't parse.
**Fix:** Hardened `spark-defaults.yaml` with integer overrides:
*   `spark.hadoop.fs.s3a.threads.keepalivetime 60`
*   `spark.dynamicAllocation.executorIdleTimeout 600000`

### ✅ Fix 4: StarRocks Empty Results
**Symptom:** Querying Delta table returned 0 rows.
**Root Cause:** Used `type='hive'`, which expects manifest files.
**Fix:** Switched to **Native Delta Lake Catalog** (`type='deltalake'`), which reads `_delta_log` directly.

---

## 3. Deployment Workflow

### Prerequisites
*   Use the unified Spark image: `subhodeep2022/spark-bigdata:spark-4.0.1-uc-0.3.1-fix-v4`
*   Ensure `.env` is loaded before deploying.

### Validation Steps
1.  **Write Data**: Run PySpark job to write Delta table to `s3a://test-bucket`.
2.  **Verify Metadata**: Check HMS has the table registered.
3.  **Read Data**: Query via StarRocks using the External Catalog.

---

## 4. StarRocks Configuration (Reference)
Correct syntax for the External Catalog to read Delta Tables from MinIO:

```sql
CREATE EXTERNAL CATALOG delta_test
PROPERTIES (
    "type" = "deltalake",
    "hive.metastore.uris" = "thrift://hive-metastore:9083",
    "aws.s3.use_instance_profile" = "false",
    "aws.s3.access_key" = "minioadmin",
    "aws.s3.secret_key" = "minioadmin",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.enable_path_style_access" = "true"
);
```

### Query Syntax
```sql
SELECT * FROM delta_test.`default`.sales_delta_test LIMIT 10;
```
