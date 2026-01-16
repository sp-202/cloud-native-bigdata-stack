from pyspark.sql import SparkSession
import sys
import json
import urllib.request
import urllib.error

log_file = open('/tmp/register_existing.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Registering Existing Working Table (test_simple)")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# 1. Get Location of the working table
# We hardcode it based on previous finding: s3a://warehouse/test_simple
# But for UC registration we need s3:// scheme (assuming generic S3 compat)
# MinIO usually handles s3a vs s3 fine if endpoints are same, but UC might need s3://
spark_location = "s3a://warehouse/test_simple"
uc_location = "s3://warehouse/test_simple"

print(f"Table Location: {uc_location}")

# 2. Register in Unity Catalog via REST API
uc_url = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"
uc_table_name = "uniform_test_simple"

# We need to know columns. test_simple had (id long, data string) - inferred from createDataFrame
# Schema from createDataFrame([(1, "Simple")]) -> id: bigint (Long), data: string
payload = {
    "catalog_name": "unity",
    "schema_name": "default",
    "name": uc_table_name,
    "table_type": "EXTERNAL",
    "data_source_format": "DELTA",
    "storage_location": uc_location,
    "columns": [
        {"name": "id", "type_name": "LONG", "type_text": "bigint", "type_json": "{\"type\":\"long\"}", "position": 0},
        {"name": "data", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 1}
    ]
}

try:
    print(f"Registering table '{uc_table_name}' in Unity Catalog...")
    req = urllib.request.Request(uc_url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        print(f"Success! Table '{uc_table_name}' registered in UC.")
        print(response.read().decode('utf-8'))

except urllib.error.HTTPError as e:
    print(f"Failed to register table in UC: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error in execution: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
