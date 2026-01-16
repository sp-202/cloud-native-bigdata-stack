# 📜 CHANGELOG.md

All notable changes to this project will be documented in this file.

## [v0.3.0] - 2026-01-16

### 🚀 Added
- **Spark Connect Server**: Centralized Spark compute with gRPC endpoint (port 15002) for thin-client notebooks.
- **HOW_TO_DEBUG.md**: Comprehensive debugging guide with 6-step Spark Connect troubleshooting.
- **StarRocks 3.3 Integration**: Auto-initialized `hms_delta_catalog` for sub-second Delta Lake queries.
- **Hive Metastore 4.0.0**: Upgraded standalone Thrift service with PostgreSQL backend.

### 🔄 Changed
- **JupyterHub Architecture**: Migrated from embedded Spark driver to thin-client connecting via `SPARK_REMOTE`.
- **Documentation Overhaul**: Updated 15+ markdown files with current architecture details.
- **Spark Upgraded**: From 3.5.3 to **4.0.1** with Spark Connect support.
- **Delta Lake Upgraded**: From 3.2.0 to **4.0.0**.
- **AWS SDK Upgraded**: Added `aws-java-sdk-bundle:2.20.160` for S3A compatibility.

### 🗑 Removed
- **Legacy UC Configs**: Moved `patch-uc-*.yaml`, `uc-*.yaml` to `archive-v2/legacy-uc-configs/`.
- **Legacy Scripts**: Moved interpreter settings and verification scripts to `archive-v2/legacy-scripts/`.

### 📋 Roadmap (v0.4.0)
- Iceberg table format integration
- Delta Lake UniForm interoperability testing
- Unity Catalog (OSS) re-integration with HMS fallback

---

## [v0.2.0] - 2026-01-13

### 🚀 Added
- **Standalone Hive Metastore (HMS)**: Replaced embedded Derby/UC with Thrift Metastore (`hive-metastore:9083`).
- **StarRocks Native Delta Catalog**: Sub-second queries on Delta Lake tables.
- **Production-Grade Spark Configs**: Integer timeouts fixing `NumberFormatException` crashes.

### 🐛 Bug Fixes
- Fixed `NumberFormatException: For input string: "60s"` in S3A file system.
- Fixed `NoClassDefFoundError` for AWS SDK classes during Delta writes.
- Fixed `NameError: name 'spark' is not defined` in Notebooks.

---

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

---

## [v0.0.1] - Legacy
- Initial deployment of Airflow, Spark Operator, and Zeppelin on GKE.
- Basic MinIO integration.
