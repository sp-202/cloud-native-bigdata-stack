⚠️ Updated documentation as of 2026-01-15. See CHANGELOG for details.

# Project Issues & Resolutions Log

## 1. Spark Auto-Initialization Failure (`NameError: name 'spark' is not defined`)

**Issue:**
JupyterHub users (IPython/Notebooks) found that `spark` was not defined on startup, despite `00-pyspark-setup.py` being present.

**Root Cause:**
Spark running in **Client Mode** on Kubernetes requires the Driver Pod to have a resolvable name that matches `spark.kubernetes.driver.pod.name`.
*   The default Pod name is random (e.g., `jupyterhub-78dd...`).
*   Spark failed silently during initialization with `SparkException: No pod was found named spark-driver`, causing the startup script to abort without defining `spark`.

**Resolution:**
Updated `k8s-platform-v2/03-apps/jupyterhub.yaml` (inside `setup-kernels.sh`) to dynamically set the property at runtime:
```bash
echo "spark.kubernetes.driver.pod.name    ${HOSTNAME}" >> "${FINAL_CONF}"
```
This ensures the driver name always matches the actual pod hostname.

---

## 2. Missing AWS SDK (`NoClassDefFoundError: software/amazon/awssdk/...`)

**Issue:**
Writing to S3 (MinIO) failed with `NoClassDefFoundError` for AWS SDK v2 classes, preventing Delta Lake operations.

**Root Cause:**
The Spark 4.0 / Hadoop 3.3.4 combination requires specific AWS SDK v2 bundles that were missing from the generic Spark image.

**Resolution:**
1.  **Rebuilt Spark Image**: Created `spark-4.0.1-uc-0.3.1-fix-v4`.
2.  **Dockerfile Updates**:
    *   `HADOOP_AWS_VERSION=3.3.4`
    *   `AWS_SDK_V2_VERSION=2.20.160` (Explicitly added `software.amazon.awssdk:bundle:2.20.160`)
3.  **Deployment**: Updated `.env` to `SPARK_IMAGE_VERSION=fix-v4` and redeployed all services.

**Working Dependency Set:**
*   `io.delta:delta-spark_2.13:4.0.0`
*   `org.apache.hadoop:hadoop-aws:3.3.4`
*   `software.amazon.awssdk:bundle:2.20.160`

---

## 3. Configuration Parsing Error (`NumberFormatException: For input string: "60s"`)

**Issue:**
Spark operations failed with `NumberFormatException: "60s"` or `"24h"`.

**Root Cause:**
Default settings in `hadoop-aws` (specifically `fs.s3a.threads.keepalivetime` and `fs.s3a.multipart.purge.age`) use time suffixes (e.g., "60s"), but the Spark/Delta S3A integration path strictly expects **integer milliseconds** or seconds.

**Resolution:**
Hardened `k8s-platform-v2/04-configs/spark-defaults.yaml` to override these defaults with integers:
```yaml
# Timeouts (Milliseconds)
spark.dynamicAllocation.executorIdleTimeout 600000   # Was 600s
spark.dynamicAllocation.schedulerBacklogTimeout 5000 # Was 5s
spark.hadoop.fs.s3a.connection.timeout 200000

# S3A Specifics (Seconds/Integers)
spark.hadoop.fs.s3a.threads.keepalivetime 60         # Was 60s
spark.hadoop.fs.s3a.multipart.purge.age 86400        # Was 24h
spark.hadoop.fs.s3a.connection.estimated.ttl 300
```

---

## 4. StarRocks Empty Results (`type='hive'`)

**Issue:**
Querying the Delta table in StarRocks using a `hive` catalog returned 0 rows, even though Spark confirmed data existed.

**Root Cause:**
The `hive` catalog in StarRocks expects standard Hive tables (Parquet files in folders). For Delta Lake tables, it relies on `symlink_format_manifest` files, which Spark does not generate by default. Without them, StarRocks sees the folder but no valid data files.

**Resolution:**
Switched to the **Native Delta Lake Catalog** (`type='deltalake'`), which reads the `_delta_log` directly.

**Correct SQL:**
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
