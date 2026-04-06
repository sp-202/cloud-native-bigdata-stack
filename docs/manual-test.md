# Manual Integration Tests

End-to-end smoke tests to verify the lakehouse stack is working correctly after a fresh deployment or after changes. Run these in order.

> **Catalog architecture recap**
> Gravitino acts as the unified metadata layer (analogous to Databricks Unity Catalog).
> The Iceberg REST service runs on port 9001 in **dynamic-config-provider** mode — the catalog
> name is passed as the `warehouse` query param during the REST handshake, not in the URL path.
> `spark.sql.defaultCatalog = sales_catalog` is pre-configured in the Spark ConfigMap, so
> short names (`schema.table`) resolve to `sales_catalog` by default.

---

## Prerequisites

- Spark Connect Server is `1/1 Running`
- Gravitino pod is `1/1 Running` (Iceberg REST dynamic-config-provider, metalake: `enterprise_metalake`, catalog: `sales_catalog`)
- MinIO is reachable at `http://minio.default.svc.cluster.local:9000`
- A Jupyter/PySpark session connected to `sc://spark-connect-server:15002`

---

## Test 1: PySpark → Iceberg via Gravitino REST Catalog

Writes 200 synthetic sales records as an Iceberg table via `sales_catalog` (backed by Gravitino's
Iceberg REST service on port 9001). Verifies the data lands in `s3://warehouse/iceberg/`.

> **Note:** Use `CREATE NAMESPACE` not `CREATE DATABASE`. Iceberg REST catalogs do not support
> the Hive DDL `CREATE DATABASE` — it will return `HTTP 404` from Gravitino.

### Code (run in JupyterHub or any Spark Connect client)

```python
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType
from datetime import datetime, timedelta
import random

# ── 1. Generate synthetic data ────────────────────────────────────────────────
data = []
start_date = datetime(2026, 1, 1)
for i in range(1, 201):
    data.append((
        i,
        f"Product_{random.randint(1, 50)}",
        round(random.uniform(10.5, 500.0), 2),
        random.randint(1, 10),
        (start_date + timedelta(days=i)).strftime("%Y-%m-%d"),
    ))

schema = StructType([
    StructField("id",       IntegerType(), False),
    StructField("product",  StringType(),  True),
    StructField("price",    DoubleType(),  True),
    StructField("quantity", IntegerType(), True),
    StructField("date",     StringType(),  True),
])

df = spark.createDataFrame(data, schema)

# ── 2. Create namespace and write Iceberg table ───────────────────────────────
# Short names resolve to sales_catalog (spark.sql.defaultCatalog = sales_catalog)
db_name    = "sales"
table_name = f"{db_name}.sales_records"

print(f"==> Ensuring namespace '{db_name}' exists...")
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {db_name}")

print(f"==> Saving 200 records to {table_name}...")
df.write.format("iceberg") \
    .mode("overwrite") \
    .saveAsTable(table_name)

# ── 3. Verify ─────────────────────────────────────────────────────────────────
print(f"==> Verifying table '{table_name}':")
spark.table(table_name).show(10)

spark.sql(f"DESCRIBE EXTENDED {table_name}").show(truncate=False)
```

### Expected Output

```
==> Ensuring namespace 'sales' exists...
==> Saving 200 records to sales.sales_records...
==> Verifying table 'sales.sales_records':
+---+----------+------+--------+----------+
| id|   product| price|quantity|      date|
+---+----------+------+--------+----------+
|  1|Product_46|170.33|      10|2026-01-02|
...
+----------------------------+---------------------------------------------------+
|col_name                    |data_type                                          |
+----------------------------+---------------------------------------------------+
|Location                    |s3://warehouse/iceberg/sales/sales_records         |
|Provider                    |iceberg                                            |
|catalog-backend             |jdbc                                               |
...
```

Key things to confirm:
- `Location` starts with `s3://warehouse/iceberg/` (not `/tmp/`)
- `Provider` is `iceberg`
- No `IllegalArgumentException` about `jdbc-driver`

---

## Test 2: StarRocks reads the Iceberg table

Verifies StarRocks can query the same Iceberg table via the `iceberg_gravitino` external catalog (Gravitino REST + MinIO).

### Connect via kubectl

```bash
kubectl exec starrocks-cluster-fe-0 -- mysql -uroot -h127.0.0.1 -P9030 \
  --execute="SELECT * FROM iceberg_gravitino.sales.sales_records LIMIT 5;" --table
```

### Expected Output

```
+------+------------+--------+----------+------------+
| id   | product    | price  | quantity | date       |
+------+------------+--------+----------+------------+
|  101 | Product_33 | 249.22 |        4 | 2026-04-12 |
|  102 | Product_16 | 460.22 |        6 | 2026-04-13 |
...
+------+------------+--------+----------+------------+
```

### If the catalog is missing (e.g. after FE restart)

```sql
CREATE EXTERNAL CATALOG iceberg_gravitino
COMMENT 'Iceberg via Gravitino REST Catalog (port 9001)'
PROPERTIES (
    'type'                                 = 'iceberg',
    'iceberg.catalog.type'                 = 'rest',
    'iceberg.catalog.uri'                  = 'http://gravitino.default.svc.cluster.local:9001/iceberg/',
    'iceberg.catalog.io-impl'              = 'org.apache.iceberg.aws.s3.S3FileIO',
    'iceberg.catalog.s3.endpoint'          = 'http://minio.default.svc.cluster.local:9000',
    'iceberg.catalog.s3.path-style-access' = 'true',
    'iceberg.catalog.s3.access-key-id'     = 'minioadmin',
    'iceberg.catalog.s3.secret-access-key' = 'minioadmin',
    'aws.s3.use_instance_profile'          = 'false',
    'aws.s3.access_key'                    = 'minioadmin',
    'aws.s3.secret_key'                    = 'minioadmin',
    'aws.s3.region'                        = 'us-east-1',
    'aws.s3.endpoint'                      = 'minio.default.svc.cluster.local:9000',
    'aws.s3.enable_path_style_access'      = 'true',
    'aws.s3.enable_ssl'                    = 'false'
);
```

> Both `iceberg.catalog.s3.*` (Java Iceberg layer) and `aws.s3.*` (C++ BE data reader) are required. See [ISSUES.md issue #14](../ISSUES.md).

---

## Test 3: Superset queries StarRocks (UI test)

1. Open Superset → **SQL Lab**
2. Select the **StarRocks** database connection (`mysql+pymysql://root:@starrocks-cluster-fe-service:9030/`)
3. Run:

```sql
SELECT
    product,
    SUM(price * quantity) AS total_revenue,
    SUM(quantity)         AS total_units,
    COUNT(*)              AS num_orders
FROM iceberg_gravitino.sales.sales_records
GROUP BY product
ORDER BY total_revenue DESC
LIMIT 10;
```

### Expected: top 10 products by revenue, no errors.

---

---

## Catalog Management (PySpark helpers)

Apache Spark has no `CREATE CATALOG` SQL (that is Databricks/Unity Catalog DDL). The helpers
below replicate that experience by combining a Gravitino REST call (persistent — stored in
PostgreSQL) with `spark.conf.set` (session-scoped — lost on Spark Connect restart).

For a catalog to survive restarts it must also be added to the Spark ConfigMap
(`big-data-platform/charts/spark-connect-server/templates/configmap.yaml`).

### Helper: `create_catalog`

```python
import requests

# ── Connection constants (match values.yaml) ─────────────────────────────────
_GRAV_URI  = "http://gravitino.default.svc.cluster.local:8090"
_METALAKE  = "enterprise_metalake"
_GRAV_REST = "http://gravitino.default.svc.cluster.local:9001/iceberg/"
_MINIO_URI = "http://minio.default.svc.cluster.local:9000"
_JDBC_BASE = "jdbc:postgresql://postgres.default.svc.cluster.local:5432"
_JDBC_DB   = "iceberg_catalog"   # reuse the existing Postgres DB
_S3_KEY    = "minioadmin"
_S3_SECRET = "minioadmin"


def create_catalog(name: str, bucket: str = None, use: bool = True) -> None:
    """
    Create a new Iceberg catalog — equivalent to Databricks `CREATE CATALOG`.

    Steps performed:
      1. Registers the catalog in Gravitino under enterprise_metalake (idempotent).
      2. Wires the catalog into the current Spark session via spark.conf.set.
      3. Optionally sets it as the session default catalog (use=True).

    Args:
        name   : Catalog name.  Must match what you registered in Gravitino.
        bucket : S3 warehouse root for this catalog.
                 Defaults to s3://warehouse/iceberg/<name>/
        use    : If True (default), switches the session default to this catalog
                 so unqualified names (schema.table) resolve here.

    Note:
        The Spark wiring is session-scoped and lost on server restart.
        For a permanent catalog, also add it to the Spark ConfigMap.
    """
    bucket = bucket or f"s3://warehouse/iceberg/{name}/"

    # 1. Register in Gravitino ─────────────────────────────────────────────────
    resp = requests.post(
        f"{_GRAV_URI}/api/metalakes/{_METALAKE}/catalogs",
        headers={"Accept": "application/vnd.gravitino.v1+json"},
        json={
            "name": name,
            "type": "RELATIONAL",
            "provider": "lakehouse-iceberg",
            "comment": f"Iceberg catalog '{name}' — created via create_catalog()",
            "properties": {
                "catalog-backend":      "jdbc",
                "uri":                  f"{_JDBC_BASE}/{_JDBC_DB}",
                "jdbc-driver":          "org.postgresql.Driver",
                "jdbc-user":            "postgres",
                "jdbc-password":        "password",
                "warehouse":            bucket,
                "io-impl":              "org.apache.iceberg.aws.s3.S3FileIO",
                "s3-endpoint":          _MINIO_URI,
                "s3-access-key-id":     _S3_KEY,
                "s3-secret-access-key": _S3_SECRET,
                "s3-path-style-access": "true",
            },
        },
    )
    if resp.status_code == 409:
        print(f"[gravitino] Catalog '{name}' already exists — skipping registration.")
    elif resp.status_code != 200:
        raise RuntimeError(f"Gravitino error {resp.status_code}: {resp.text}")
    else:
        print(f"[gravitino] Catalog '{name}' registered → {bucket}")

    # 2. Wire into Spark session ───────────────────────────────────────────────
    pfx = f"spark.sql.catalog.{name}"
    spark.conf.set(pfx,                              "org.apache.iceberg.spark.SparkCatalog")
    spark.conf.set(f"{pfx}.type",                    "rest")
    spark.conf.set(f"{pfx}.uri",                     _GRAV_REST)
    spark.conf.set(f"{pfx}.warehouse",               name)   # dynamic-config-provider key
    spark.conf.set(f"{pfx}.io-impl",                 "org.apache.iceberg.aws.s3.S3FileIO")
    spark.conf.set(f"{pfx}.s3.endpoint",             _MINIO_URI)
    spark.conf.set(f"{pfx}.s3.path-style-access",    "true")
    spark.conf.set(f"{pfx}.s3.access-key-id",        _S3_KEY)
    spark.conf.set(f"{pfx}.s3.secret-access-key",    _S3_SECRET)

    # 3. Optionally switch default catalog ─────────────────────────────────────
    if use:
        use_catalog(name)
    else:
        print(f"[spark]    Catalog '{name}' wired. Call use_catalog('{name}') to switch.")
```

### Helper: `use_catalog`

```python
def use_catalog(name: str) -> None:
    """
    Switch the session default catalog — equivalent to Databricks `USE CATALOG`.

    Note:
        `USE CATALOG <name>` is Databricks-only SQL and raises ParseException in
        standard Apache Spark.  This function is the correct replacement.
        The change is session-scoped; a new Jupyter kernel resets to the default
        configured in the Spark ConfigMap (sales_catalog).

    Args:
        name : Catalog name — must already be wired into the session.
    """
    spark.conf.set("spark.sql.defaultCatalog", name)
    print(f"[spark] Default catalog → {name}")
```

### Creating tables with a custom S3 location

By default, `saveAsTable` uses the catalog's warehouse root. To override the physical location
use one of the approaches below.

**Option A — namespace-level location** (all tables in the namespace inherit the path)

```python
spark.sql("CREATE NAMESPACE IF NOT EXISTS analytics LOCATION 's3://data/analytics/'")
df.write.format("iceberg").mode("overwrite").saveAsTable("analytics.events")
# ↳ lands at s3://data/analytics/events/
```

> Known limitation: Gravitino's Iceberg REST catalog ignores the namespace `LOCATION`
> when computing the table path via `saveAsTable` — it falls back to the catalog warehouse.
> Use Option B or C for a guaranteed custom path.

**Option B — explicit path on the write** (most reliable)

```python
spark.sql("CREATE NAMESPACE IF NOT EXISTS analytics")
df.write.format("iceberg") \
    .option("path", "s3://data/analytics/events/") \
    .mode("overwrite") \
    .saveAsTable("analytics.events")
```

**Option C — pre-create the table with LOCATION, then write**

```python
spark.sql("CREATE NAMESPACE IF NOT EXISTS analytics")
spark.sql("""
    CREATE TABLE IF NOT EXISTS analytics.events (
        id        INT    NOT NULL,
        event     STRING,
        ts        STRING
    )
    USING iceberg
    LOCATION 's3://data/analytics/events/'
""")
df.write.format("iceberg").mode("append").saveAsTable("analytics.events")
```

Verify the physical location after any write:

```python
spark.sql("DESCRIBE EXTENDED analytics.events") \
     .filter("col_name = 'Location'") \
     .show(truncate=False)
```

### End-to-end example

```python
# ── 0. Load helpers (run once per kernel session) ─────────────────────────────
# paste create_catalog() and use_catalog() definitions here

# ── 1. Create & activate catalog ─────────────────────────────────────────────
create_catalog("marketing", bucket="s3://warehouse/iceberg/marketing/")
# [gravitino] Catalog 'marketing' registered → s3://warehouse/iceberg/marketing/
# [spark]    Default catalog → marketing

# ── 2. Create namespace ───────────────────────────────────────────────────────
spark.sql("CREATE NAMESPACE IF NOT EXISTS crm")

# ── 3. Write table to custom path ─────────────────────────────────────────────
df.write.format("iceberg") \
    .option("path", "s3://warehouse/iceberg/marketing/crm/leads/") \
    .mode("overwrite") \
    .saveAsTable("crm.leads")

# ── 4. Verify ─────────────────────────────────────────────────────────────────
spark.table("crm.leads").show(5)
spark.sql("DESCRIBE EXTENDED crm.leads").filter("col_name = 'Location'").show(truncate=False)

# ── 5. Switch back to the default catalog ────────────────────────────────────
use_catalog("sales_catalog")
```

---

## Troubleshooting Checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| `null in jdbc-driver is invalid` | Missing `GRAVITINO_ICEBERG_REST_JDBC_DRIVER` env var | See [issue #12](../ISSUES.md) |
| `relation "metalake_meta" does not exist` | PostgreSQL schema not initialized | See [issue #9](../ISSUES.md) |
| `catalog-backend=memory` in Gravitino log | `rewrite_gravitino_server_config.py` overwriting env | Check env vars on pod: `kubectl exec <pod> -- env \| grep GRAVITINO_ICEBERG` |
| StarRocks `Forbidden 403` from MinIO | Missing `iceberg.catalog.s3.*` properties | See [issue #14](../ISSUES.md) |
| StarRocks `Alive: false` / `Unmatched token` | FE restarted with new cluster ID | See [issue #13](../ISSUES.md) |
| Spark writes to `/tmp/sales/...` | Wrong `eventLog.dir` or S3 path | Check `spark.eventLog.dir` in ConfigMap |
| `NotFoundException: HTTP 404` on any Spark SQL | `sales_catalog.uri` still has `/sales_catalog` appended | URI must be bare `/iceberg/`; catalog selected via `warehouse=sales_catalog` |
| `CREATE DATABASE` raises `HTTP 404` | Iceberg REST catalogs don't support Hive DDL | Use `CREATE NAMESPACE` instead |
| `ParseException: extra input 'marketing'` on `USE CATALOG` | `USE CATALOG` is Databricks-only SQL | Use `use_catalog("name")` helper or `spark.conf.set("spark.sql.defaultCatalog", "name")` |
| `create_catalog()` catalog wired but lost after restart | `spark.conf.set` is session-scoped | Add catalog config blocks to the Spark ConfigMap for persistence |
| Table lands in `s3://warehouse/iceberg/` despite namespace `LOCATION` | Gravitino REST ignores namespace location for `saveAsTable` | Set `.option("path", "s3://...")` on the write or pre-create table with `LOCATION` |
