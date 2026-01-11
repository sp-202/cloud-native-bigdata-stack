# 💎 Delta Lake: ACID Transactions on Object Storage

Delta Lake is the unified storage layer that brings reliability, security, and performance to your data lake.

## ✨ Key Features in this Platform
- **ACID Transactions**: Ensures data integrity in distributed environments.
- **Scalable Metadata**: Handles petabyte-scale datasets with billions of files.
- **Time Travel**: Access or revert to earlier versions of data for audits or rollbacks.
- **Schema Enforcement**: Prevents corrupt data from being written.

---

## 🛠 Usage in Spark (Pure PySpark)

### 1. Writing a Delta Table
```python
delta_path = "s3a://test-bucket/my_delta_table"

data = [("Alice", 34), ("Bob", 45)]
df = spark.createDataFrame(data, ["Name", "Age"])

# Write as delta format
df.write.format("delta").mode("overwrite").save(delta_path)
```

### 2. Reading a Delta Table
```python
read_df = spark.read.format("delta").load(delta_path)
read_df.show()
```

### 3. Time Travel (Version History)
```python
# View history
# Note: In our current setup, use the spark.sql command for history
spark.sql(f"DESCRIBE HISTORY delta.`{delta_path}`").show()

# Read specific version
df_v0 = spark.read.format("delta").option("versionAsOf", 0).load(delta_path)
```

---

## ⚙️ Configuration
The platform is pre-configured with the Delta Lake JARs. The core settings in `spark-defaults.conf` are:
- `spark.sql.extensions`: `io.delta.sql.DeltaSparkSessionExtension`
- `spark.sql.catalog.spark_catalog`: `org.apache.spark.sql.delta.catalog.DeltaCatalog`

These settings allow Spark to transparently handle Delta tables alongside standard CSV/Parquet files.
