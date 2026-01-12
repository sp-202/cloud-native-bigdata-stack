from pyspark.sql import SparkSession
import os

print("Starting Lakehouse Verification...")

# Initialize Spark Session
# Note: configs are largely loaded from spark-defaults.conf in the image/configmap
spark = SparkSession.builder \
    .appName("LakehouseVerification") \
    .getOrCreate()

catalog_name = "uc_catalog" # As defined in spark-defaults.conf
schema_name = "validation_schema"
table_name = "uniform_test"
full_table_name = f"{catalog_name}.{schema_name}.{table_name}"

print(f"Using Catalog: {catalog_name}")

# 1. Create Schema
print(f"Creating Schema {schema_name}...")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog_name}.{schema_name}")

# 2. Create Table with UniForm enabled
print(f"Creating Table {full_table_name}...")
# Dropping first to ensure clean state if re-run
spark.sql(f"DROP TABLE IF EXISTS {full_table_name}")
spark.sql(f"""
    CREATE TABLE {full_table_name} (
        id INT,
        message STRING,
        timestamp TIMESTAMP
    ) USING DELTA 
    TBLPROPERTIES (
        'delta.universalFormat.enabledFormats' = 'iceberg',
        'delta.icebergCompatV2.enabled' = 'true'
    )
""")

# 3. Insert Data
print("Inserting test data...")
spark.sql(f"""
    INSERT INTO {full_table_name} VALUES 
    (1, 'Hello Unity Catalog', current_timestamp()),
    (2, 'Syncing to StarRocks', current_timestamp()),
    (3, 'Verified via Spark', current_timestamp())
""")

# 4. Read Data Back
print("Reading data back via Spark...")
df = spark.sql(f"SELECT * FROM {full_table_name} ORDER BY id")
df.show()

count = df.count()
print(f"Total records: {count}")

if count >= 3:
    print("SUCCESS: Spark write and read verification passed!")
else:
    print("FAILURE: Record count mismatch.")
    exit(1)

spark.stop()
