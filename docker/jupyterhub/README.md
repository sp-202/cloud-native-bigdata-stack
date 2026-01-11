# 🐳 Custom JupyterHub Docker Image

This image provides a ready-to-use JupyterLab environment optimized for Spark on Kubernetes with "Zeppelin-like" interactive features.

## 🛠 Features
- **JupyterLab 4.0.7**: Modern notebook interface.
- **Apache Toree (Scala)**: Native Spark-Scala kernel.
- **Sparkmagic**: SQL magics and remote Spark kernel support.
- **s3contents**: Seamless MinIO/S3 notebook persistence.
- **00-spark-init.py**: Startup script that auto-injects the `spark` session and enables:
    - `%%sql` magic for SQL cells.
    - `z.show(df)` for Zeppelin-style table formatting.
    - Eager Evaluation (DataFrames render as HTML automatically).

## 🚀 Build Instructions
```bash
./build.sh
```

## ⚙️ Configuration
The container uses `setup-kernels.sh` at startup to:
1. Dynamically generate `spark-defaults.conf` based on the Pod's IP.
2. Configure S3 persistence via environment variables.
