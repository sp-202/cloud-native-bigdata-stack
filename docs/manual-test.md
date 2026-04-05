# Manual Integration Tests

End-to-end smoke tests to verify the lakehouse stack is working correctly after a fresh deployment or after changes. Run these in order.

---

## Prerequisites

- Spark Connect Server is `1/1 Running`
- Gravitino pod is `1/1 Running` (entity store: PostgreSQL, catalog backend: jdbc, warehouse: `s3://warehouse/iceberg/`)
- MinIO is reachable at `http://minio.default.svc.cluster.local:9000`
- A Jupyter/PySpark session connected to `sc://spark-connect-server:15002`

---

## Test 1: PySpark → Iceberg via Gravitino REST Catalog

Writes 200 synthetic sales records as an Iceberg table via `spark_catalog` (backed by Gravitino's Iceberg REST service on port 9001). Verifies the data lands in `s3://warehouse/iceberg/`.

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
db_name    = "sales"
table_name = f"{db_name}.sales_records"

print(f"==> Ensuring namespace '{db_name}' exists...")
spark.sql(f"CREATE DATABASE IF NOT EXISTS {db_name}")

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

## Troubleshooting Checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| `null in jdbc-driver is invalid` | Missing `GRAVITINO_ICEBERG_REST_JDBC_DRIVER` env var | See [issue #12](../ISSUES.md) |
| `relation "metalake_meta" does not exist` | PostgreSQL schema not initialized | See [issue #9](../ISSUES.md) |
| `catalog-backend=memory` in Gravitino log | `rewrite_gravitino_server_config.py` overwriting env | Check env vars on pod: `kubectl exec <pod> -- env \| grep GRAVITINO_ICEBERG` |
| StarRocks `Forbidden 403` from MinIO | Missing `iceberg.catalog.s3.*` properties | See [issue #14](../ISSUES.md) |
| StarRocks `Alive: false` / `Unmatched token` | FE restarted with new cluster ID | See [issue #13](../ISSUES.md) |
| Spark writes to `/tmp/sales/...` | Wrong `eventLog.dir` or S3 path | Check `spark.eventLog.dir` in ConfigMap |
