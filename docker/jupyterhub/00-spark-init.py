import os
from pyspark.sql import SparkSession

# Initialize SparkSession with dynamic values from environment
spark = SparkSession.builder \
    .appName("JupyterNotebook") \
    .master("k8s://https://kubernetes.default.svc") \
    .config("spark.kubernetes.container.image", os.environ.get("SPARK_IMAGE", "subhodeep2022/spark-bigdata:spark-3.5.3-uc-0.3.1-v3")) \
    .config("spark.kubernetes.namespace", "default") \
    .config("spark.kubernetes.authenticate.driver.serviceAccountName", "jupyterhub") \
    .config("spark.driver.host", os.environ.get("SPARK_DRIVER_HOST")) \
    .config("spark.driver.bindAddress", "0.0.0.0") \
    .config("spark.dynamicAllocation.enabled", "true") \
    .config("spark.dynamicAllocation.shuffleTracking.enabled", "true") \
    .config("spark.dynamicAllocation.minExecutors", "1") \
    .config("spark.dynamicAllocation.maxExecutors", "4") \
    .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("MINIO_ENDPOINT", "http://minio.default.svc.cluster.local:9000")) \
    .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", "minioadmin")) \
    .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", "minioadmin")) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Enable SQL magic (%%sql)
from IPython.core.magic import register_line_cell_magic

@register_line_cell_magic
def sql(line, cell=None):
    """Execute Spark SQL and display results."""
    query = cell if cell else line
    return spark.sql(query).toPandas()

print("✅ SparkSession ready! Use 'spark' variable.")
print("✅ SQL magic enabled! Use %%sql for SQL cells.")
print(f"📊 Spark UI: http://localhost:4040")
