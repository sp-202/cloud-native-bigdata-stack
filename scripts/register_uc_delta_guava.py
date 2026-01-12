import json
import urllib.request
import urllib.error
from pyspark.sql import SparkSession
import sys
import time

# Redirect stdout/stderr to a log file for retrieval
log_file = open('/tmp/registration_final_guava.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Unified Delta-UniForm-UC Registration Script (Guava + Sync)")

# Path to the downloaded JAR
guava_jar = "/home/marimo/guava-31.1-jre.jar"

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .config("spark.databricks.delta.reorg.convertUniForm.sync", "true") \
    .config("spark.databricks.delta.universalFormat.iceberg.syncConvert.enabled", "true") \
    .config("spark.driver.extraClassPath", guava_jar) \
    .config("spark.executor.extraClassPath", guava_jar) \
    .config("spark.driver.userClassPathFirst", "true") \
    .config("spark.executor.userClassPathFirst", "true") \
    .getOrCreate()

# Use s3a for Spark (Hadoop AWS)
s3_path = "s3a://test-bucket/delta/tables/uniform_final_guava"
# Use s3 for Unity Catalog (Generic S3)
uc_location = "s3://test-bucket/delta/tables/uniform_final_guava"

try:
    # 1. Create External Table in HMS (via spark_catalog)
    print(f"Creating SQL Delta table at {s3_path}...")
    spark.sql(f"DROP TABLE IF EXISTS default.uniform_final_guava")
    
    # We must enable UniForm at creation time
    spark.sql(f"""
        CREATE TABLE default.uniform_final_guava (
            id INT,
            name STRING,
            plan STRING,
            score DOUBLE
        )
        USING DELTA
        LOCATION '{s3_path}'
        TBLPROPERTIES (
            'delta.universalFormat.enabledFormats' = 'iceberg',
            'delta.enableIcebergCompatV2' = 'true',
            'delta.columnMapping.mode' = 'name'
        )
    """)

    # 2. Insert Data
    print("Inserting data...")
    spark.sql(f"INSERT INTO default.uniform_final_guava VALUES (1011, 'UniForm-Guava', 'Diamond', 999.9)")
    
    print("Forcing optimization (Synchronous via config)...")
    spark.sql(f"OPTIMIZE default.uniform_final_guava")
    
    # 3. Register in Unity Catalog via REST API
    uc_url = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"

    payload = {
        "catalog_name": "unity",
        "schema_name": "default",
        "name": "uniform_final_guava",
        "table_type": "EXTERNAL",
        "data_source_format": "DELTA",
        "storage_location": uc_location,
        "columns": [
            {"name": "id", "type_name": "INTEGER", "type_text": "int", "type_json": "{\"type\":\"integer\"}", "position": 0},
            {"name": "name", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 1},
            {"name": "plan", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 2},
            {"name": "score", "type_name": "DOUBLE", "type_text": "double", "type_json": "{\"type\":\"double\"}", "position": 3}
        ]
    }

    print(f"Registering table 'uniform_final_guava' at {uc_location}...")
    req = urllib.request.Request(uc_url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        print("Table 'uniform_final_guava' registered successfully in Unity Catalog!")
        print(response.read().decode('utf-8'))

    # Final Wait
    time.sleep(10)
    print("Done.")

except urllib.error.HTTPError as e:
    print(f"Failed to register table: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error executing script: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
