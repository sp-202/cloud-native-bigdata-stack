from pyhive import hive
import sys

def test_conn(auth_mech, username=None, password=None, note=""):
    print(f"\n--- Testing auth={auth_mech} {note} ---")
    try:
        if auth_mech in ['PLAIN', 'LDAP', 'CUSTOM']:
            conn = hive.Connection(host="172.21.0.11", port=10000, database="default", username=username, password=password, auth=auth_mech)
        else:
            conn = hive.Connection(host="172.21.0.11", port=10000, database="default", auth=auth_mech)
        
        import time
        start_time = time.time()
        print("Connection object created.")
        cursor = conn.cursor()
        print("Cursor created. Executing query...")
        cursor.execute("SELECT 1")
        end_time = time.time()
        print(f"Success! Result: {cursor.fetchall()}")
        print(f"Time taken: {end_time - start_time:.2f} seconds")
        conn.close()
    except Exception as e:
        print(f"FAILED: {e}")

if __name__ == "__main__":
    test_conn('PLAIN', 'hive', '', '(Empty Password)')
    test_conn('PLAIN', 'hive', None, '(None Password)')
    test_conn('LDAP', 'hive', 'hive', '(With Password)')
    test_conn('CUSTOM', 'hive', 'hive', '(With Password)')
    # Retrying NOSASL just in case
    test_conn('NOSASL')
