import json
import urllib.request
import urllib.error

UC_HOST = "http://unity-catalog-unitycatalog-server:8080"

def get_json(url):
    print(f"GET {url}")
    try:
        with urllib.request.urlopen(url) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTPError: {e.code} - {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

print("\n=== Verifying 'uniform_final' Registration ===")
tables = get_json(f"{UC_HOST}/api/2.1/unity-catalog/tables?catalog_name=unity&schema_name=default")
print(json.dumps(tables, indent=2))
