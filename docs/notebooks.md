# 📓 Notebook Suites: JupyterHub, Marimo, and Polynote

This platform provides three distinct notebook environments, each optimized for different data engineering and science workflows.

## 🚀 Common Features
- **Spark on K8s**: All notebooks are configured to run as Spark Drivers in "Client Mode," dynamically spawning executors in the GKE cluster.
- **S3 Persistence**: Notebooks are stored in MinIO (`s3a://notebooks/`) to ensure they survive pod restarts.
- **Python 3.11**: All environments are standardized on Python 3.11 to match the Spark executor image.

---

## 🪐 JupyterHub (The Classic)
The standard environment for data engineering, enhanced with Zeppelin features.

### Key Features
- **Apache Toree**: Native Scala support for Spark.
- **SQL Magic**: Use `%%sql` to run Spark SQL queries.
- **Zeppelin Formatting**: Use `z.show(df)` for beautiful, sortable tables.
- **Auto-Injection**: The `spark` session is available immediately on startup.

### When to use?
Use JupyterHub for standard ETL development and when you need the full Zeppelin experience with SQL and Scala.

---

## 🌊 Marimo (The Reactive)
A modern, reactive Python notebook that ensures reproducibility.

### Key Features
- **Reactivity**: Changing a variable in one cell instantly updates all downstream cells. No more "stale" state.
- **Pure Python**: Notebooks are saved as `.py` files, making them perfect for Git and version control.
- **UI Components**: Built-in sliders, tables, and buttons for creating interactive dashboards.
- **`from spark_init import *`**: A custom helper to get Spark running in one line.

### When to use?
Use Marimo for interactive data exploration, creating dashboards, and when you want a clean Git history.

---

## 🎹 Polynote (The IDE)
Netflix's multi-language notebook designed specifically for data science.

### Key Features
- **Multi-Language**: Mix Scala, Python, and SQL in the same notebook with shared variable state.
- **IDE Features**: Real-time error highlighting and advanced autocompletion.
- **Visual Data Exploration**: Built-in data inspector for Spark DataFrames.

### When to use?
Use Polynote for complex data science projects involving multiple languages or when you want an IDE-like experience in the browser.
