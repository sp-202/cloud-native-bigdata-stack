from pyspark.sql import SparkSession
import sys
import time
import json
import urllib.request
import urllib.error

# Log file for final verification
log_file = open('/tmp/registration_proven.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting PROVEN Unified Delta-UniForm-UC Registration Script")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .config("spark.databricks.delta.reorg.convertUniForm.sync", "true") \
    .config("spark.databricks.delta.universalFormat.iceberg.syncConvert.enabled", "true") \
    .getOrCreate()

# Name of the Hive Metastore / Spark Catalog table
spark_table_name = "default.uniform_final_proven"
# Location in S3 (path-based, but we will access via table name)
s3_table_location = "s3a://test-bucket/delta/tables/uniform_final_proven"
# Location for Unity Catalog Registration (generic s3://)
uc_table_location = "s3://test-bucket/delta/tables/uniform_final_proven"

try:
    # 1. Drop existing table to start fresh
    print(f"Dropping existing table {spark_table_name}...")
    spark.sql(f"DROP TABLE IF EXISTS {spark_table_name}")

    # 2. Create the Table in the Catalog
    # This is critical: We create the catalog entry first.
    print(f"Creating SQL Delta table {spark_table_name} in catalog...")
    spark.sql(f"""
        CREATE TABLE {spark_table_name} (
            id INT,
            name STRING,
            plan STRING,
            score DOUBLE
        )
        USING DELTA
        LOCATION '{s3_table_location}'
        TBLPROPERTIES (
            'delta.universalFormat.enabledFormats' = 'iceberg',
            'delta.enableIcebergCompatV2' = 'true',
            'delta.columnMapping.mode' = 'name'
        )
    """)
    
    # 3. Insert Data (Strictly using Table Identity)
    print(f"Inserting data into {spark_table_name}...")
    spark.sql(f"INSERT INTO {spark_table_name} VALUES (2024, 'UniForm-Proven', 'Diamond', 100.0)")

    # 4. Force Optimization / Metadata Generation
    print(f"Running OPTIMIZE on {spark_table_name}...")
    spark.sql(f"OPTIMIZE {spark_table_name}")
    
    # 5. Register in Unity Catalog via REST API
    uc_url = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"
    uc_table_name_final = "uniform_final_proven"

    payload = {
        "catalog_name": "unity",
        "schema_name": "default",
        "name": uc_table_name_final,
        "table_type": "EXTERNAL",
        "data_source_format": "DELTA",
        "storage_location": uc_table_location,
        "columns": [
            {"name": "id", "type_name": "INTEGER", "type_text": "int", "type_json": "{\"type\":\"integer\"}", "position": 0},
            {"name": "name", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 1},
            {"name": "plan", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 2},
            {"name": "score", "type_name": "DOUBLE", "type_text": "double", "type_json": "{\"type\":\"double\"}", "position": 3}
        ]
    }

    print(f"Registering table '{uc_table_name_final}' in Unity Catalog...")
    req = urllib.request.Request(uc_url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        print(f"Success! Table '{uc_table_name_final}' registered in UC.")
        print(response.read().decode('utf-8'))

    time.sleep(5)
    print("Done.")

except urllib.error.HTTPError as e:
    print(f"Failed to register table in UC: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error in execution: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
