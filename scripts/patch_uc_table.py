import json
import urllib.request
import urllib.error
import sys

log_file = open('/tmp/patch_uc_table.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Unity Catalog Table Patch Script")

uc_url_base = "http://unity-catalog-unitycatalog-server:8080/api/2.1/unity-catalog/tables"
catalog = "unity"
schema = "default"
table = "uniform_test_simple"
full_name = f"{catalog}.{schema}.{table}"

print(f"Patching table: {full_name}")

# The user-provided "Golden Properties" to enable Iceberg visibility
payload = {
    "properties": {
        "delta.enableIcebergCompatV2": "true",
        "delta.universalFormat.enabledFormats": "iceberg",
        "delta.columnMapping.mode": "name"
    }
}

try:
    url = f"{uc_url_base}/{full_name}"
    print(f"Sending PATCH request to: {url}")
    
    req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'}, method='PATCH')
    
    with urllib.request.urlopen(req) as response:
        print("Success! Table properties updated.")
        print(response.read().decode('utf-8'))

except urllib.error.HTTPError as e:
    print(f"Failed to patch table: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error in execution: {e}")
    import traceback
    traceback.print_exc(file=log_file)
finally:
    log_file.close()
