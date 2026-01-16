# %% [markdown]
# # Big Data Stack Verification Notebook
# This notebook verifies the integration between **Spark 4.0**, **Hive Metastore (HMS) 4.0**, **MinIO**, and **StarRocks 3.3**.
#
# **Prerequisites**:
# - Run this inside the Kubernetes cluster (e.g., via JupyterHub or a Spark Pod) or ensure network connectivity/port-forwarding.
# - Image used: `subhodeep2022/spark-bigdata:spark-4.0.1-uc-fix-v3`

# %% [python]
import os
from pyspark.sql import SparkSession

# Configuration
HMS_URI = "thrift://hive-metastore:9083"
MINIO_ENDPOINT = "http://minio.default.svc.cluster.local:9000"
ACCESS_KEY = "minioadmin"
SECRET_KEY = "minioadmin"
TABLE_NAME = "default.notebook_verification_test"
S3_PATH = "s3a://test-bucket/notebook_data"

print("Initializing Spark Session...")
spark = SparkSession.builder \
    .appName("HMS_Stack_Verification") \
    .config("spark.sql.catalogImplementation", "hive") \
    .config("spark.hadoop.hive.metastore.uris", HMS_URI) \
    .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT) \
    .config("spark.hadoop.fs.s3a.access.key", ACCESS_KEY) \
    .config("spark.hadoop.fs.s3a.secret.key", SECRET_KEY) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
    .enableHiveSupport() \
    .getOrCreate()

print("Spark Session Created.")
print(f"Spark Version: {spark.version}")

# %% [python]
# 1. Clean up previous run
print(f"Dropping table {TABLE_NAME} if exists...")
spark.sql(f"DROP TABLE IF EXISTS {TABLE_NAME}")

# 2. Create Native Delta Table via HMS
print(f"Creating Delta Table {TABLE_NAME} at {S3_PATH}...")
spark.sql(f"""
    CREATE TABLE {TABLE_NAME} (
        id INT,
        data STRING,
        ts TIMESTAMP
    ) USING DELTA
    LOCATION '{S3_PATH}'
""")
print("Table created successfully.")

# %% [python]
# 3. Insert Test Data
print("Inserting data...")
spark.sql(f"""
    INSERT INTO {TABLE_NAME} VALUES
    (1, 'Verified from Notebook', current_timestamp()),
    (2, 'HMS Integration Works', current_timestamp())
""")
print("Data inserted.")

# %% [python]
# 4. Verify Read with Spark
print("Reading back data via HMS...")
df = spark.sql(f"SELECT * FROM {TABLE_NAME} ORDER BY id")
df.show(truncate=False)

assert df.count() == 2, "Row count mismatch!"
print("SUCCESS: Spark Read/Write verification pass.")

# %% [markdown]
# ## StarRocks Verification
#
# Since the StarRocks frontend does not support the native `delta_lake` catalog type in this version,
# we verified it using the Hive catalog compatibility layer.
#
# **Run the following SQL in your StarRocks SQL Client or MySQL CLI:**
#
# ```sql
# -- 1. Connect to StarRocks
# -- mysql -h 127.0.0.1 -P 9030 -u root
#
# -- 2. Refresh the Hive Catalog (if previously created)
# REFRESH EXTERNAL CATALOG hms_test;
#
# -- 3. Query the table created by this notebook
# SELECT * FROM hms_test.default.notebook_verification_test;
# ```
#
# **Expected Output:**
# You should see the 2 rows inserted above.
