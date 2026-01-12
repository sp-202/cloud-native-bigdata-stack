from pyspark.sql import SparkSession
import sys

log_file = open('/tmp/uniform_jvm_inspect_3.log', 'w')
sys.stdout = log_file
sys.stderr = log_file

print("Inspecting IcebergConverter via JVM Reflection (Attempt 3)")

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

try:
    jvm = spark.sparkContext._jvm
    
    # Get the singleton instance
    converter_module = jvm.org.apache.spark.sql.delta.icebergShaded.IcebergConverter
    print(f"Module Instance: {converter_module}")
    
    # Get the class of the module instance
    # In Py4J, we can try .getClass() on the wrapper, but sometimes it fails.
    # Let's try iterating declared methods on the class name directly
    
    clazz = jvm.java.lang.Class.forName("org.apache.spark.sql.delta.icebergShaded.IcebergConverter$")
    print(f"Class: {clazz.getName()}")
    
    methods = clazz.getDeclaredMethods()
    print(f"Methods found: {len(methods)}")
    for m in methods:
        print(f" - {m.getName()} args: {[t.getName() for t in m.getParameterTypes()]}")

except Exception as e:
    print(f"Error accessing JVM objects: {e}")
    import traceback
    traceback.print_exc(file=log_file)
