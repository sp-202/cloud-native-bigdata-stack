# Zeppelin Delta Lake & StarRocks Test Notebook

Copy the following blocks into separate paragraphs in a Zeppelin Note.

### Paragraph 1: Initialize Delta Table (Batch Write & Register in Hive)
```python
%pyspark
from pyspark.sql.functions import col, expr
import random

# definition of the table path (S3) and Hive Table Name
table_path = "s3a://notebooks/delta-table"
table_name = "delta_table_hive"

# Create some random data
data = [(i, random.randint(0, 100), "val_" + str(i)) for i in range(100)]
schema = ["id", "value", "description"]
df = spark.createDataFrame(data, schema)

# Write to Delta Table and Register in Hive
print(f"Writing to {table_path} and registering as table '{table_name}'...")
df.write.format("delta") \
    .mode("overwrite") \
    .option("path", table_path) \
    .saveAsTable(table_name)

print("Batch Write and Hive Registration Successful!")
```

### Paragraph 2: Read Delta Table (via Spark)
```python
%pyspark
# Read back using SQL (Hive Metastore)
print(f"Reading from Hive table '{table_name}'...")
spark.sql(f"SELECT * FROM {table_name} LIMIT 5").show()

print(f"Total count: {spark.sql(f'SELECT count(*) FROM {table_name}').collect()[0][0]}")
```

### Paragraph 3: Update and Merge (Delta Features)
```python
%pyspark
from delta.tables import *

deltaTable = DeltaTable.forPath(spark, table_path)

# Update: Increment value for even IDs
print("Updating even IDs...")
deltaTable.update(
    condition = expr("id % 2 == 0"),
    set = { "value": expr("value + 1") }
)

# Delete: Remove IDs > 90
print("Deleting IDs > 90...")
deltaTable.delete(condition = expr("id > 90"))

# Verify changes
deltaTable.toDF().show(5)
print(f"New count after delete: {deltaTable.toDF().count()}")
```

### Paragraph 4: Streaming Write (Random Source -> Delta)
```python
%pyspark
# Stream random data (Rate source) into a Delta Table
stream_path = "s3a://notebooks/delta-stream-table"
checkpoint_path = "s3a://notebooks/delta-stream-checkpoint"
stream_table_name = "delta_stream_table"

# Read from Rate source (generates rows with timestamp and value)
streaming_df = spark.readStream.format("rate").option("rowsPerSecond", 10).load()

# Write stream to Delta
print("Starting streaming write to Delta...")
query = streaming_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", checkpoint_path) \
    .option("path", stream_path) \
    .start()

# We can't use saveAsTable with start() directly for all Spark versions easily in streams without extra steps,
# but we can create the table pointing to the location once data exists.

print(f"Streaming query started: {query.id}")
query.awaitTermination(timeout=15)
query.stop()
print("Streaming write stopped.")

# Register stream table in Hive for StarRocks to see
print("Registering stream table in Hive...")
spark.sql(f"CREATE TABLE IF NOT EXISTS {stream_table_name} USING DELTA LOCATION '{stream_path}'")
```

### Paragraph 5: Query from StarRocks (JDBC)
```python
# Create a %jdbc interpreter pointing to StarRocks if not already configured, 
# or use %pyspark to connect via JDBC for testing.
%pyspark

# JDBC Connection to StarRocks FE
jdbc_url = "jdbc:mysql://starrocks-fe.default.svc.cluster.local:9030/default"
properties = {
    "user": "root",
    "password": ""
}

print("Querying StarRocks to verify it sees the tables...")

# NOTE: You must have created the External Catalog in StarRocks first!
# Run this in a StarRocks SQL client:
# CREATE EXTERNAL CATALOG delta_catalog PROPERTIES ("type"="hive", "hive.metastore.uris"="thrift://hive-metastore.default.svc.cluster.local:9083");

try:
    # Query the table from the external catalog
    # Assuming catalog name is 'delta_catalog' and db is 'default'
    sr_df = spark.read.jdbc(url=jdbc_url, table="delta_catalog.default.delta_table_hive", properties=properties)
    sr_df.show(5)
    print("StarRocks Verification Successful!")
except Exception as e:
    print("StarRocks Query Failed. Did you create the External Catalog in StarRocks?")
    print(e)
```
