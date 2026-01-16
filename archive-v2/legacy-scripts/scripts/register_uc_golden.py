import json
import urllib.request
import urllib.error
import sys
import time

log_file = open('/tmp/register_golden.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Golden Payload Registration Script")

uc_url = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"
catalog = "unity"
schema = "default"
table_name = "uniform_test_simple"
full_name = f"{catalog}.{schema}.{table_name}"
uc_location = "s3://warehouse/test_simple"

# 1. DELETE existing table registration
# We ignore 404 if it doesn't exist
try:
    delete_url = f"{uc_url}/{full_name}"
    print(f"Deleting existing registration: {delete_url}")
    req = urllib.request.Request(delete_url, method='DELETE')
    with urllib.request.urlopen(req) as response:
        print("Deleted existing table.")
except urllib.error.HTTPError as e:
    if e.code == 404:
        print("Table did not exist, proceeding.")
    else:
        print(f"Warning: Failed to delete table: {e.code} {e.reason}")

time.sleep(2)

# 2. CREATE (Register) with Golden Payload
payload = {
    "catalog_name": catalog,
    "schema_name": schema,
    "name": table_name,
    "table_type": "EXTERNAL",
    "data_source_format": "DELTA",
    "storage_location": uc_location,
    "columns": [
        {"name": "id", "type_name": "LONG", "type_text": "bigint", "type_json": "{\"type\":\"long\"}", "position": 0},
        {"name": "data", "type_name": "STRING", "type_text": "string", "type_json": "{\"type\":\"string\"}", "position": 1}
    ],
    "properties": {
        "delta.enableIcebergCompatV2": "true",
        "delta.universalFormat.enabledFormats": "iceberg",
        "delta.columnMapping.mode": "name"
    }
}

try:
    print(f"Registering '{full_name}' with Golden Payload...")
    print(json.dumps(payload, indent=2))
    
    req = urllib.request.Request(uc_url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        print("Success! Table registered.")
        print(response.read().decode('utf-8'))

except urllib.error.HTTPError as e:
    print(f"Failed to register table: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error in execution: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
