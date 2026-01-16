from pyspark.sql import SparkSession
import sys
import time

log_file = open('/tmp/test_unity_native.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Native Spark-Unity Catalog Registration Test")

# Note: Using Cluster service name for URI
spark = SparkSession.builder \
    .config("spark.sql.catalog.unity", "io.unitycatalog.spark.UCSingleCatalog") \
    .config("spark.sql.catalog.unity.uri", "http://unity-catalog-unitycatalog-server.default.svc.cluster.local:8080") \
    .config("spark.sql.catalog.unity.token", "not-used") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .config("spark.databricks.delta.reorg.convertUniForm.sync", "true") \
    .config("spark.databricks.delta.universalFormat.iceberg.syncConvert.enabled", "true") \
    .getOrCreate()

try:
    print("Catalog 'unity' configured.")
    
    table_name = "unity.default.uniform_native_proper"
    
    print(f"Dropping table if exists: {table_name}")
    spark.sql(f"DROP TABLE IF EXISTS {table_name}")

    print(f"Creating table {table_name} with UniForm enabled...")
    # Using TBLPROPERTIES to ensure OSS UC picks up requirements
    spark.sql(f"""
        CREATE TABLE {table_name} (
            id INT,
            data STRING
        )
        USING DELTA
        TBLPROPERTIES (
            'delta.universalFormat.enabledFormats' = 'iceberg',
            'delta.enableIcebergCompatV2' = 'true',
            'delta.columnMapping.mode' = 'name'
        )
    """)

    print(f"Inserting data into {table_name}...")
    spark.sql(f"INSERT INTO {table_name} VALUES (1, 'Fixed-Native-UniForm')")

    print(f"Running OPTIMIZE on {table_name} to trigger metadata conversion...")
    spark.sql(f"OPTIMIZE {table_name}")

    print("Success! Table created and data inserted.")
    
    print("Verifying via UC API (identifiers list)...")
    # This part will be checked manually via curl
    
except Exception as e:
    print(f"Caught Error: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
