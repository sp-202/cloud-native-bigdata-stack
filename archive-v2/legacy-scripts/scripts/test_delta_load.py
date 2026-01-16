
from pyspark.sql import SparkSession
import os

# 1. Initialize Spark (HMS is enabled in config)
spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.sql.parquet.enableVectorizedReader", "false")

# 2. Create Dummy Data
print("Creating dummy data for Hive registration...")
data = [(401, "HMS-User", "Gold", 1000.0)]
df = spark.createDataFrame(data, ["id", "name", "plan", "score"])

# 3. Write as Hive Table (Delta format)
# This will save data to MinIO and register metadata in Hive Metastore
table_name = "default.starrocks_hms_delta"
print(f"Writing data to {table_name}...")

df.write.format("delta") \
    .mode("overwrite") \
    .option("path", "s3a://test-bucket/delta/tables/starrocks_hms_delta") \
    .saveAsTable(table_name)

print("Write complete!")

# 4. Verify Read from Hive metadata
print("Reading back from Hive table...")
spark.table(table_name).show()
