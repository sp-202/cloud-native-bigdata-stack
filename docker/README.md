# 🐳 Custom Docker Images

This directory contains the source code and build scripts for the custom Docker images used in the platform.

## 🏗️ Build Instructions

We provide a convenient build script for each component.

### 1. **Spark Base Image** (`docker/spark`)
The golden image containing Spark 4.0.1, Hadoop 3.3.4, AWS SDK v2, and Delta Lake 4.0.0.
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

## 🏷️ Versioning
Images are tagged based on the `SPARK_IMAGE_VERSION` defined in the root `.env` file.
