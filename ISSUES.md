# Project Issues & Resolutions Log

This document tracks issues encountered during development and their resolutions.

---

## v0.3.0 Issues (Spark Connect Migration)

### 5. Spark Connect Server Connection Refused

**Issue:**
JupyterHub notebooks failed to connect to Spark Connect Server with `grpc._channel._InactiveRpcError: StatusCode.UNAVAILABLE`.

**Root Cause:**
Spark Connect Server pod was not running or service was not properly configured.

**Resolution:**
1. Verified Spark Connect Server deployment:
   ```bash
   kubectl get pods -l app=spark-connect-server
   kubectl get svc spark-connect-server-driver-svc
   ```
2. Ensured service exposes port 15002 correctly.
3. Updated JupyterHub `SPARK_REMOTE` environment variable.

---

### 6. Legacy Client Mode Documentation Confusion

**Issue:**
Users followed outdated JUPYTERHUB_GUIDE.md instructions expecting JupyterHub to spawn executor pods.

**Root Cause:**
Documentation was written for legacy embedded Spark driver architecture.

**Resolution:**
Complete rewrite of JUPYTERHUB_GUIDE.md for Spark Connect thin-client architecture. Added deprecation warning for legacy mode.

---

## v0.2.0 Issues (HMS & StarRocks)

### 4. StarRocks Empty Results (`type='hive'`)

**Issue:**
Querying the Delta table in StarRocks using a `hive` catalog returned 0 rows.

**Root Cause:**
The `hive` catalog expects standard Hive tables (Parquet in folders). Delta Lake requires `symlink_format_manifest` files which Spark doesn't generate by default.

**Resolution:**
Switched to **Native Delta Lake Catalog** (`type='deltalake'`), which reads the `_delta_log` directly.

**Correct SQL:**
```sql
CREATE EXTERNAL CATALOG delta_test
PROPERTIES (
    "type" = "deltalake",
    "hive.metastore.uris" = "thrift://hive-metastore:9083",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.enable_path_style_access" = "true"
);
```

---

### 3. Configuration Parsing Error (`NumberFormatException: "60s"`)

**Issue:**
Spark operations failed with `NumberFormatException: "60s"` or `"24h"`.

**Root Cause:**
Default settings in `hadoop-aws` use time suffixes, but Spark/Delta S3A path expects integers.

**Resolution:**
Hardened `spark-defaults.yaml` with integer overrides:
```yaml
spark.dynamicAllocation.executorIdleTimeout 600000
spark.hadoop.fs.s3a.threads.keepalivetime 60
spark.hadoop.fs.s3a.multipart.purge.age 86400
```

---

### 2. Missing AWS SDK (`NoClassDefFoundError`)

**Issue:**
Writing to S3 (MinIO) failed with `NoClassDefFoundError` for AWS SDK v2 classes.

**Root Cause:**
Spark 4.0 / Hadoop 3.3.4 requires AWS SDK v2 bundles missing from image.

**Resolution:**
Rebuilt Spark image `spark-4.0.1-uc-0.3.1-fix-v4` with:
- `hadoop-aws:3.3.4`
- `software.amazon.awssdk:bundle:2.20.160`

---

### 1. Spark Auto-Initialization Failure

**Issue:**
`NameError: name 'spark' is not defined` despite `00-pyspark-setup.py` being present.

**Root Cause:**
Spark Client Mode requires `spark.kubernetes.driver.pod.name` to match actual pod name.

**Resolution:**
Dynamically set property at runtime in `setup-kernels.sh`:
```bash
echo "spark.kubernetes.driver.pod.name    ${HOSTNAME}" >> "${FINAL_CONF}"
```

> [!NOTE]
> This issue is now obsolete with Spark Connect architecture where JupyterHub is a thin client.

---

## Open Issues (v0.4.0 Roadmap)

### 7. Iceberg Integration Not Yet Implemented

**Status:** 🔵 Planned for v0.4.0

**Description:**
Apache Iceberg table format is not yet supported. Users requesting cross-format compatibility with other tools.

**Planned Resolution:**
- Add `iceberg-spark-runtime` to Spark image
- Configure Iceberg catalog (REST or HMS-based)
- Test StarRocks Iceberg catalog

---

### 8. Delta Lake UniForm Not Tested

**Status:** 🔵 Planned for v0.4.0

**Description:**
Delta Lake UniForm allows reading Delta tables as Iceberg format, but this hasn't been verified on the platform.

**Planned Resolution:**
- Enable UniForm on Delta tables
- Verify StarRocks can read Delta+UniForm as Iceberg
- Document any limitations

---

### 9. Unity Catalog Paused

**Status:** ⏸️ Paused

**Description:**
Unity Catalog (OSS) deployment was paused due to stability issues. HMS is the current catalog.

**Planned Resolution (v0.4.0):**
- Re-deploy UC v0.3.1 with PostgreSQL backend
- Configure Storage Credentials API for MinIO
- Implement HMS fallback for legacy tables
