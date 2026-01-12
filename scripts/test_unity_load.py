
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp

# 1. Initialize Spark (Unity Catalog is defined in config)
spark = SparkSession.builder.getOrCreate()

# 2. Create Dummy Data
print("Creating dummy data...")
data = [
    (201, "UC-SQL-1", "Standard", 500.0),
    (202, "UC-SQL-2", "Growth", 650.5)
]
columns = ["user_id", "user_name", "plan_type", "credit_score"]
df = spark.createDataFrame(data, schema=columns).withColumn("processed_at", current_timestamp())

# 3. Create Schema in UC explicitly via SQL
print("Creating schema 'default' in Unity Catalog...")
spark.sql("CREATE SCHEMA IF NOT EXISTS unity.default")

# 4. Write to Unity Catalog via SQL path
full_table_name = "unity.default.starrocks_unity_sql"
print(f"Writing data to {full_table_name}...")
df.createOrReplaceTempView("temp_data")
spark.sql(f"CREATE TABLE IF NOT EXISTS {full_table_name} USING delta AS SELECT * FROM temp_data")

print("Write complete!")

# 4. Verify Read
print("Reading back from Unity Catalog...")
spark.table(full_table_name).show()

# 5. Check UC metadata
print("DESCRIBE EXTENDED unity.default.starrocks_unity_test")
spark.sql(f"DESCRIBE EXTENDED {full_table_name}").show(truncate=False)

print("Unity Catalog Integration Test Successful!")
