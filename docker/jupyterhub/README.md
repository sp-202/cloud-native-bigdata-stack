# 🐳 Custom JupyterHub Docker Image

This image provides a ready-to-use JupyterLab environment optimized as a **thin client** for Spark Connect Server.

## 🛠 Features
- **JupyterLab 4.0.7**: Modern notebook interface.
- **Spark Connect Client**: Connects to remote Spark Connect Server via `SPARK_REMOTE` environment variable.
- **s3contents**: Seamless MinIO/S3 notebook persistence.
- **00-pyspark-setup.py**: Startup script that auto-initializes SparkSession using `SparkSession.builder.remote()`.

## 🚀 Build Instructions
```bash
./build.sh
```

## ⚙️ Configuration
The container uses `setup-kernels.sh` at startup to:
1. Create a PySpark (Connect) kernel with `SPARK_REMOTE` environment variable.
2. Configure S3 persistence via environment variables.

## 🔌 Spark Connect Mode
Unlike traditional Spark client mode, this image does **not** spawn executor pods. Instead, it connects to a centralized **Spark Connect Server** running in the cluster:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect-server-driver-svc:15002").getOrCreate()
```
