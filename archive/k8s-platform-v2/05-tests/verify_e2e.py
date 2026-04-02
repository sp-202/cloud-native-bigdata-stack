from pyspark.sql import SparkSession
import os

def verify_e2e():
    print("Starting End-to-End Verification (Spark -> HMS -> StarRocks)...")
    
    spark = SparkSession.builder \
        .appName("HMS_E2E_Verification") \
        .enableHiveSupport() \
        .getOrCreate()

    # Define table and location
    table_name = "default.starrocks_e2e_test"
    s3_path = "s3a://test-bucket/starrocks_e2e_data"

    print(f"Target Table: {table_name}")
    print(f"Target Location: {s3_path}")

    # Drop existing to ensure clean state
    spark.sql(f"DROP TABLE IF EXISTS {table_name}")

    # Create Native Delta Table with explicit location
    print("Creating Delta Table...")
    spark.sql(f"""
        CREATE TABLE {table_name} (
            id INT,
            message STRING,
            created_at TIMESTAMP
        ) USING DELTA
        LOCATION '{s3_path}'
    """)

    # Insert Data
    print("Inserting data...")
    spark.sql(f"""
        INSERT INTO {table_name} 
        VALUES 
            (101, 'Hello StarRocks', current_timestamp()),
            (102, 'Native Delta via HMS', current_timestamp())
    """)

    # Verify Spark Read
    print("Verifying Spark Read...")
    df = spark.sql(f"SELECT * FROM {table_name} ORDER BY id")
    df.show(truncate=False)

    count = df.count()
    if count == 2:
        print("SUCCESS: Spark write/read successful.")
    else:
        print(f"FAILURE: Expected 2 rows, got {count}")
        exit(1)

    spark.stop()

if __name__ == "__main__":
    verify_e2e()
