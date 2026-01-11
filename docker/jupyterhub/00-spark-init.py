import os
from pyspark.sql import SparkSession

# Initialize SparkSession 
# Decoupled approach: This will pick up configurations from:
# 1. spark-defaults.conf (dynamically generated in setup-kernels.sh)
# 2. Environment variables set in jupyterhub.yaml
spark = SparkSession.builder.getOrCreate()

# Configure Eager Evaluation for beautiful HTML tables in Jupyter
# This makes Spark DataFrames render as clean tables automatically
spark.conf.set("spark.sql.repl.eagerEval.enabled", True)
spark.conf.set("spark.sql.repl.eagerEval.maxNumRows", 20)

# Enable SQL magic (%%sql) - uses .toPandas() for clean rendering
from IPython.core.magic import register_line_cell_magic
from IPython.display import display

@register_line_cell_magic
def sql(line, cell=None):
    """Execute Spark SQL and display results as a beautiful HTML table."""
    query = cell if cell else line
    # .toPandas() makes it look very clean in Jupyter
    return spark.sql(query).toPandas()

# Create a 'z' helper for Zeppelin-like 'z.show()' commands
class ZeppelinHelper:
    def show(self, df_or_sql, limit=20):
        """Mimics Zeppelin's z.show() for dataframes."""
        if isinstance(df_or_sql, str):
            display(spark.sql(df_or_sql).limit(limit).toPandas())
        else:
            display(df_or_sql.limit(limit).toPandas())

z = ZeppelinHelper()

print("✅ SparkSession ready! Use 'spark' variable.")
print("✅ SQL magic enabled! Use %%sql for SQL cells.")
print("✅ Zeppelin-like visualization ready! Use z.show(df).")
print(f"📊 Spark UI: http://localhost:4040")
