# 🐳 Custom Marimo Docker Image

This image provides a reactive Python notebook environment optimized for Spark development.

## 🛠 Features
- **Marimo**: A reactive, modern Python notebook.
- **Spark v5 Base**: Inherits the "Golden Stack" (Spark 3.5.3, Python 3.11, Delta Lake).
- **spark_init.py**: A one-line helper for Spark integration. 
    - Just run: `from spark_init import *` to get a pre-configured `spark` session and `mo` (marimo) object.

## 🚀 Build Instructions
```bash
./build.sh
```

## ⚙️ Configuration
The container uses `init-marimo.sh` at startup to:
1. Dynamically template `config.yml` and `spark-defaults.conf`.
2. Map the Pod IP for executor connectivity.
