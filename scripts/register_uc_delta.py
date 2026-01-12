import json
import urllib.request
import urllib.error
from pyspark.sql import SparkSession
import sys
import time

log_file = open('/tmp/registration_final_optimize.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Unified Delta-UniForm-UC Registration Script (OPTIMIZE + CATALOG FIX)")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .config("spark.databricks.delta.reorg.convertUniForm.sync", "true") \
    .config("spark.databricks.delta.universalFormat.iceberg.syncConvert.enabled", "true") \
    .getOrCreate()

s3_path = "s3a://test-bucket/delta/tables/uniform_final_optimize"
uc_location = "s3://test-bucket/delta/tables/uniform_final_optimize"
table_name = "default.uniform_final_optimize"

try:
    print(f"Ensuring spark_catalog is DeltaCatalog: {spark.conf.get('spark.sql.catalog.spark_catalog')}")
    
    # 1. Create Table (Table-Based)
    print(f"Creating SQL Delta table {table_name} at {s3_path}...")
    spark.sql(f"DROP TABLE IF EXISTS {table_name}")
    
    spark.sql(f"""
        CREATE TABLE {table_name} (
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

    # 2. Insert Data (Table-Based)
    print("Inserting data into table...")
    spark.sql(f"INSERT INTO {table_name} VALUES (1015, 'UniForm-Optimize', 'Platinum', 999.9)")
    
    # 3. OPTIMIZE (Table-Based)
    # This should trigger the conversion hook if sync is enabled
    print("Running SYNC OPTIMIZE to generate Iceberg metadata...")
    spark.sql(f"OPTIMIZE {table_name}")
    
    # 4. Register in UC
    uc_url = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"
    uc_table_name = "uniform_final_optimize"

    payload = {
        "catalog_name": "unity",
        "schema_name": "default",
        "name": uc_table_name,
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

    print(f"Registering table '{uc_table_name}' at {uc_location}...")
    req = urllib.request.Request(uc_url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        print(f"Table '{uc_table_name}' registered successfully in Unity Catalog!")
        print(response.read().decode('utf-8'))

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
