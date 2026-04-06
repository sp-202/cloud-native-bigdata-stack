# Implementation Plan

## Plan 1: Gravitino Spark Plugin — Dynamic Multi-Catalog Discovery

**Status**: Pending  
**Priority**: High  
**Motivation**: The current `spark-connect-server` configmap hardcodes a single catalog (`sales_catalog`). Any new catalog created in Gravitino is invisible to Spark after a pod restart unless the configmap is manually updated and redeployed.

### Problem

```
Session 1: create cat1, cat2 in Gravitino → configure Spark manually → works
Spark pod restarts
Session 2: cat1, cat2 data still in Gravitino + MinIO, but Spark only knows sales_catalog
```

### Solution

Replace per-catalog `spark.sql.catalog.<name>.*` blocks with Gravitino's `GravitinoSparkPlugin`. The plugin queries the metalake at Spark startup and auto-registers **all** catalogs — present and future — without any ConfigMap changes.

### Implementation Steps

#### Step 1 — Add Gravitino Spark connector JAR to Spark image or init container

The `GravitinoSparkPlugin` ships as a separate JAR:
```
gravitino-spark-connector-runtime-<version>.jar
```

Options (pick one):
- **Option A**: Download JAR into the Spark image via a custom Dockerfile
- **Option B**: Mount JAR via init container that pulls from MinIO/S3
- **Option C**: Add JAR URL to `spark.jars` in spark-defaults.conf (simplest, no image change)

```properties
# Option C — add to spark-defaults.conf
spark.jars    https://repo1.maven.org/maven2/org/apache/gravitino/gravitino-spark-connector-runtime/<version>/gravitino-spark-connector-runtime-<version>.jar
```

#### Step 2 — Update `spark-connect-server` ConfigMap

File: `big-data-platform/charts/spark-connect-server/templates/configmap.yaml`

Remove:
```properties
spark.sql.defaultCatalog                         sales_catalog
spark.sql.catalog.sales_catalog                  org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.sales_catalog.type             rest
spark.sql.catalog.sales_catalog.uri              ...
spark.sql.catalog.sales_catalog.warehouse        sales_catalog
spark.sql.catalog.sales_catalog.io-impl          org.apache.iceberg.aws.s3.S3FileIO
spark.sql.catalog.sales_catalog.s3.endpoint      ...
spark.sql.catalog.sales_catalog.s3.path-style-access ...
spark.sql.catalog.sales_catalog.s3.access-key-id ...
spark.sql.catalog.sales_catalog.s3.secret-access-key ...
```

Add:
```properties
spark.plugins                        org.apache.gravitino.spark.connector.plugin.GravitinoSparkPlugin
spark.sql.gravitino.metalake         enterprise_metalake
spark.sql.gravitino.uri              http://gravitino.default.svc.cluster.local:8090
```

#### Step 3 — Re-add `metalake` to values.yaml

The `metalake` and `catalogs` keys were removed in commit `fc6dc5d`. Re-add `metalake` (catalogs list no longer needed):

```yaml
# big-data-platform/values.yaml
global:
  gravitino:
    metalake: "enterprise_metalake"
    icebergRestUri: "http://gravitino.default.svc.cluster.local:9001/iceberg/"
    apiUri: "http://gravitino.default.svc.cluster.local:8090"
```

And reference it in the configmap template:
```
spark.sql.gravitino.metalake    {{ .Values.global.gravitino.metalake }}
spark.sql.gravitino.uri         {{ .Values.global.gravitino.apiUri }}
```

#### Step 4 — Verify

```python
# In Jupyter after sync:
spark.sql("SHOW CATALOGS").show()
# Should list all catalogs registered in enterprise_metalake

spark.sql("USE sales_catalog")
spark.sql("SHOW DATABASES").show()
```

### Expected Result After Implementation

| Action | Before | After |
|--------|--------|-------|
| Create new catalog in Gravitino | Must update ConfigMap + redeploy | Nothing — auto-discovered on next Spark start |
| Spark pod restarts | Only `sales_catalog` available | All metalake catalogs available |
| Add 10 catalogs | 10 ConfigMap blocks | Zero ConfigMap changes |

### Notes / Risks

- Gravitino Spark connector version must match the Gravitino server version deployed
- S3/MinIO credentials still needed per-catalog for `io-impl` — Gravitino plugin may pass these through from its catalog registration, needs verification
- Test with `spark.sql("SHOW CATALOGS")` before removing the old hardcoded block
