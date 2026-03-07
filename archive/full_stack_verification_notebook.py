# %% [markdown]
# # Full Stack Lakehouse Verification
# 
# This notebook demonstrates the complete data flow:
# 1. **Spark**: Generate random data and write to S3 (MinIO) as Delta Lake.
# 2. **HMS**: Verify table registration in Hive Metastore.
# 3. **StarRocks**: Query the Delta table using the Hive Catalog.
# 4. **Superset**: Instructions to visualize the data.
#
# **Prerequisites**:
# - Run this in JupyterHub (the `spark` session is auto-initialized).

# %% [python]
# 1. Generate Random Data using Spark
import random
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, FloatType
from pyspark.sql.functions import rand, randn

print("🚀 Step 1: Generating Random Dataset...")

# Define schema
data = []
for i in range(1, 101):  # Generate 100 records
    data.append((
        i, 
        f"Category_{random.choice(['A', 'B', 'C', 'D'])}", 
        random.uniform(10.0, 500.0),
        random.randint(1, 50)
    ))

schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("category", StringType(), True),
    StructField("amount", FloatType(), True),
    StructField("quantity", IntegerType(), True)
])

df = spark.createDataFrame(data, schema)
print("✅ Random DataFrame Created. Preview:")
df.show(5)

# %% [python]
# 2. Write to S3 (MinIO) in Delta Format
TABLE_NAME = "default.sales_delta_test"
S3_PATH = "s3a://test-bucket/sales_data_delta"

print(f"🚀 Step 2: Writing Delta Table to {S3_PATH}...")

# Write data (Overwrites if exists)
df.write.format("delta") \
    .mode("overwrite") \
    .option("path", S3_PATH) \
    .saveAsTable(TABLE_NAME)

print(f"✅ Table {TABLE_NAME} successfully written and registered in HMS.")

# %% [python]
# 3. Verify Read with Spark
print(f"🚀 Step 3: Verifying Read from Spark...")
read_df = spark.sql(f"SELECT * FROM {TABLE_NAME} WHERE amount > 100")
print(f"Found {read_df.count()} records with amount > 100.")
read_df.show(3)

# %% [markdown]
# ## 4. StarRocks Verification (SQL)
#
# Since the Native Delta Catalog isn't fully supported in this version, we use the **Hive Catalog** fallback which reads Delta tables via HMS perfectly.
#
# **Action**: Open a terminal or MySQL client connected to StarRocks and run:
#
# ```sql
# -- Connect to StarRocks (password is empty by default)
# -- mysql -h 127.0.0.1 -P 9030 -u root
#
# -- 1. Refresh the catalog to pick up the new table
# REFRESH EXTERNAL CATALOG hms_test;
#
# -- 2. Query the table
# SELECT * FROM hms_test.default.sales_delta_test LIMIT 10;
#
# -- 3. Run an aggregation query (OLAP speed test)
# SELECT category, SUM(amount) as total_sales, AVG(quantity) as avg_qty
# FROM hms_test.default.sales_delta_test
# GROUP BY category;
# ```

# %% [markdown]
# ## 5. Superset Visualization
#
# Now let's visualize this data in Apache Superset.
#
# ### Step A: Connect Superset to StarRocks
# 1. Login to Superset: [http://superset.34.136.221.189.sslip.io](http://superset.34.136.221.189.sslip.io)
#    - **User**: `admin`
#    - **Password**: `admin`
# 2. Go to **Settings (top right) -> Database Connections -> + Database**.
# 3. Choose **StarRocks** (or MySQL if StarRocks isn't listed - they are compatible).
# 4. **SQLAlchemy URI**:
#    ```
#    mysql+mysqldb://root:@starrocks-fe:9030/default
#    ```
#    *(Note: The host is `starrocks-fe` (internal K8s service name). Empty password.)*
# 5. Click **Test Connection** -> **Connect**.
#
# ### Step B: Create a Dataset
# 1. Go to **Datasets -> + Dataset**.
# 2. Database: `StarRocks`.
# 3. Schema: `hms_test.default` (You might need to type this in if dropdown doesn't show external catalogs).
# 4. Table: `sales_delta_test`.
# 5. Click **Add**.
#
# ### Step C: Create a Chart
# 1. Click on the newly created dataset `sales_delta_test`.
# 2. Choose a Chart Type: **Pie Chart**.
# 3. **Query**:
#    - Group by: `category`
#    - Metric: `SUM(amount)`
# 4. Click **Create Chart**.
#
# 🎉 You should see a Pie Chart of your random sales data generated in Spark!
