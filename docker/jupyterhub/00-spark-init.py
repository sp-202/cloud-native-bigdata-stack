import os
from pyspark.sql import SparkSession

# Initialize SparkSession 
# Decoupled approach: This will pick up configurations from:
# 1. spark-defaults.conf (dynamically generated in setup-kernels.sh)
# 2. Environment variables set in jupyterhub.yaml
spark = SparkSession.builder.getOrCreate()

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
