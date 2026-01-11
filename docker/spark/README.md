# 🐳 Custom Spark Docker Image

This directory contains the source for the "Golden Stack" Spark image used across the platform (JupyterHub, Marimo, Polynote, and Spark Operator).

## 🛠 Features
- **Spark 3.5.3**: Distributed processing engine.
- **Python 3.11**: Aligned with JupyterHub for zero-mismatch PySpark.
- **Delta Lake 3.2.0**: ACID transaction support on S3.
- **Unity Catalog 0.3.1**: Modern data governance and catalog integration.
- **AWS SDK / Hadoop AWS**: Necessary for MinIO (S3a) connectivity.

## 🚀 Build Instructions
Run the provided build script to build for `linux/amd64` and push to DockerHub:
```bash
./build.sh
```

## ⚙️ Configuration
The image is designed to be **decoupled**. It does not bake in credentials. Instead, it expects:
- `spark-defaults.conf`: Mounted at `/opt/spark/conf/spark-defaults.conf`.
- Environment Variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `MINIO_ENDPOINT`.
