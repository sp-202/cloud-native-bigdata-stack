# 🐳 Custom Docker Images

This directory contains the source code and build scripts for the custom Docker images used in the platform.

## 🏗️ Build Instructions

We provide a convenient build script for each component.

### 1. **Spark Base Image** (`docker/spark`)
The golden image containing Spark 3.5.8, Hadoop 3.4.1, AWS SDK v2, Delta Lake 4.0.1, Apache Iceberg 1.10.1, and Gravitino Spark Connector for dynamic catalog support.
```bash
./docker/spark/build.sh
```

### 2. **JupyterHub Image** (`docker/jupyterhub`)
Based on the Spark image, adding JupyterLab, Toree (Scala), and widely used Python data libraries.
```bash
./docker/jupyterhub/build.sh
```

### 3. **Marimo Image** (`docker/marimo`)
A lightweight, reactive notebook environment optimised for Python.
```bash
./docker/marimo/build.sh
```

### 4. **Hive Image** (`docker/hive`)
Provides Hive Metastore and HiveServer2 for legacy compatibility.
```bash
./docker/hive/build.sh
```

### 5. **k8s-git-sync Image** (`docker/k8s-git-sync`)
Git synchronization sidecar with MinIO client integration for Airflow DAG deployment.
```bash
./docker/k8s-git-sync/build.sh
```

## 🏷️ Versioning
Images are tagged based on the `SPARK_IMAGE_VERSION` defined in the root `.env` file.

## 🛠️ How to Customize Images

If you need to add custom libraries, jar files, or system packages, you should modify the `Dockerfile` in the respective component directory.

### Example: Adding Python Packages to JupyterHub
To add custom Python packages (e.g., specific machine learning libraries) to JupyterHub:
1. Open `docker/jupyterhub/Dockerfile`.
2. Locate the existing `pip install` command, or add a new one, for instance:
   ```dockerfile
   RUN pip3 install --no-cache-dir my-custom-package==1.0.0
   ```
3. Rebuild the image:
   ```bash
   ./docker/jupyterhub/build.sh
   ```
4. Restart your pods or redeploy the platform so the new image is pulled.

### Example: Adding Spark Dependencies
If you need extra `.jar` files for Spark connections (e.g., Snowflake, Oracle):
1. Open `docker/spark/Dockerfile`.
2. Locate the section where JARs are downloaded and add your `wget` or `curl` command.
3. Rebuild the Spark image:
   ```bash
   ./docker/spark/build.sh
   ```
