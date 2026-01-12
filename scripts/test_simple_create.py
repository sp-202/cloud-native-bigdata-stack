from pyspark.sql import SparkSession
import sys
import time
import os

log_file = open('/tmp/test_simple_create.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Starting Simple saveAsTable Test")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.databricks.delta.properties.defaults.enableIcebergCompatV2", "true") \
    .config("spark.databricks.delta.properties.defaults.universalFormat.enabledFormats", "iceberg") \
    .config("spark.databricks.delta.iceberg.async.conversion.enabled", "false") \
    .config("spark.databricks.delta.reorg.convertUniForm.sync", "true") \
    .config("spark.databricks.delta.universalFormat.iceberg.syncConvert.enabled", "true") \
    .getOrCreate()

try:
    spark.sql("DROP TABLE IF EXISTS default.test_simple")
    
    print("Creating dataframe...")
    data = [(1, "Simple")]
    df = spark.createDataFrame(data, ["id", "data"])
    
    # Enable UniForm on the writer via options if possible, or better yet, rely on defaults
    # But saveAsTable often doesn't like options for properties.
    # So we'll create the table first? No, let's try saveAsTable creation.
    # But we need properties.
    
    print("Writing with saveAsTable...")
    # Using format("delta") explicitly
    df.write \
      .format("delta") \
      .option("delta.enableIcebergCompatV2", "true") \
      .option("delta.universalFormat.enabledFormats", "iceberg") \
      .option("delta.columnMapping.mode", "name") \
      .saveAsTable("default.test_simple")
      
    print("Table created. Inserting more data...")
    spark.sql("INSERT INTO default.test_simple VALUES (2, 'More data')")
    
    print("Running OPTIMIZE...")
    spark.sql("OPTIMIZE default.test_simple")
    
    time.sleep(5)
    print("Done.")

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc(file=log_file)
