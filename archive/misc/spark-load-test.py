import time
import random

# In Zeppelin/Spark-Shell, 'spark' and 'sc' are pre-defined.
# We check if they exist, otherwise we create them (for standalone running).
try:
    spark
except NameError:
    from pyspark.sql import SparkSession
    print("Creating new Spark Session...")
    spark = SparkSession.builder.appName("Prometheus-Load-Test").getOrCreate()
    sc = spark.sparkContext

def heavy_computation(x):
    # Simulate CPU load
    val = 0
    for i in range(5000):
        val += random.random()
    return val

print("Starting Load Gen (Infinite Loop)...")
print("Press Stop to Cancel.")

# Infinite loop
while True:
    # Use enough partitions to trigger all executors
    rdd = sc.parallelize(range(1, 200000), 10)
    count = rdd.map(heavy_computation).count()
    print(f"Processed batch of {count} items.")
    # Short sleep
    time.sleep(1)
