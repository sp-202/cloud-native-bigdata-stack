from pyspark.sql import SparkSession
import sys

# Redirect stdout/stderr
log_file = open('/tmp/uniform_test.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Testing UniForm Optimization Explicitly")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .getOrCreate()

s3_path = "s3a://test-bucket/delta/tables/uniform_optimize_test"

spark.sql(f"DROP TABLE IF EXISTS default.uniform_optimize_test")

print("Creating table...")
spark.sql(f"""
    CREATE TABLE default.uniform_optimize_test (id INT)
    USING DELTA
    LOCATION '{s3_path}'
    TBLPROPERTIES (
        'delta.universalFormat.enabledFormats' = 'iceberg',
        'delta.enableIcebergCompatV2' = 'true',
        'delta.columnMapping.mode' = 'name'
    )
""")

print("Inserting data...")
spark.sql("INSERT INTO default.uniform_optimize_test VALUES (1)")

print("Running OPTIMIZE...")
df = spark.sql(f"OPTIMIZE default.uniform_optimize_test")
df.show(truncate=False)

print("Check for metadata now.")
