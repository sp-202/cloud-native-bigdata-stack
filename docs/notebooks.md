# 📓 Notebook Suites: JupyterHub, Marimo, and Polynote

This platform provides notebook environments as **thin clients** connecting to a centralized **Spark Connect Server**.

## 🚀 Common Features
- **Spark Connect**: All notebooks connect to `sc://spark-connect-server-driver-svc:15002` via gRPC.
- **S3 Persistence**: Notebooks are stored in MinIO (`s3a://notebooks/`) to survive pod restarts.
- **Python 3.11**: All environments are standardized on Python 3.11 to match PySpark client.
- **No Local Executors**: Notebooks do not spawn executor pods - compute is handled by Spark Connect Server.

---

## 🪐 JupyterHub (The Standard)
The primary environment for data engineering, optimized for Spark Connect.

### Key Features
- **PySpark Connect Kernel**: Pre-configured with `SPARK_REMOTE` environment variable.
- **s3contents**: Notebooks automatically saved to MinIO.
- **Auto-Initialization**: The `spark` session is available immediately on startup via `00-pyspark-setup.py`.

### When to use?
Use JupyterHub for standard ETL development and interactive data exploration.

### Connection Example
```python
# Spark is auto-initialized
print(spark.version)  # 4.0.1
spark.sql("SHOW DATABASES").show()
```

---

## 🌊 Marimo (The Reactive)
A modern, reactive Python notebook that ensures reproducibility.

### Key Features
- **Reactivity**: Changing a variable in one cell instantly updates all downstream cells.
- **Pure Python**: Notebooks are saved as `.py` files, making them perfect for Git.
- **UI Components**: Built-in sliders, tables, and buttons for creating interactive dashboards.

### When to use?
Use Marimo for interactive data exploration, creating dashboards, and when you want a clean Git history.

---

## 🎹 Polynote (The IDE)
Netflix's multi-language notebook designed for data science.

### Key Features
- **Multi-Language**: Mix Scala, Python, and SQL in the same notebook.
- **IDE Features**: Real-time error highlighting and advanced autocompletion.
- **Visual Data Exploration**: Built-in data inspector for Spark DataFrames.

### When to use?
Use Polynote for complex data science projects involving multiple languages.
