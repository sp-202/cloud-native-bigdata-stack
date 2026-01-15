⚠️ Updated documentation as of 2026-01-15. See CHANGELOG for details.

# 📜 CHANGELOG.md

All notable changes to this project will be documented in this file.

## [v0.1.0] - 2026-01-11
### 🚀 Added
- **Multi-Notebook Suite**: Integrated JupyterHub, Marimo, and Polynote.
- **Delta Lake Support**: ACID transactions enabled on MinIO S3.
- **Reactive Notebooks**: Marimo added for high-performance Python UIs.
- **Scala Power**: Apache Toree kernel added to JupyterHub.
- **Dynamic Config**: Runtime detection of Pod IPs for Spark Client Mode.
- **Professional Docs**: Detailed technical guides in `docs/` and custom `README` files for images.

### 🔄 Changed
- **Unified Image**: Moved to a "Golden Stack" image (`spark-bigdata`) for all Spark roles.
- **Python Alignment**: Standardized all Python components on 3.11.

### 🗑 Removed
- **Apache Zeppelin**: Retired in favor of JupyterHub and Marimo.
- **Legacy V1 Manifests**: Moved outdated K8s code to `archive/`.

## [v0.0.1] - Legacy
- Initial deployment of Airflow, Spark Operator, and Zeppelin on GKE.
- Basic MinIO integration.
