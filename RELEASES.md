⚠️ Updated documentation as of 2026-01-15. See CHANGELOG for details.

# 🏷️ Release Notes: v0.2.0 (The HMS & StarRocks Lakehouse)

This release stabilizes the **Data Lakehouse** architecture by completing the migration from Unity Catalog (OSS) to a production-ready **Hive Metastore (HMS)** setup. It creates a robust, end-to-end flow from Spark (ETL) to StarRocks (Analytics).

---

## 🚀 Key Features

### 🏰 Standalone Hive Metastore (HMS)
- **Centralized Catalog**: Replaced embedded Derby/UC with a standalone Thrift Metastore (`hive-metastore:9083`).
- **Persistence**: Backed by PostgreSQL for metadata durability.
- **Compatibility**: Verified support for both Spark 4.0.1 and StarRocks 3.x.

### ⚡ Confirmed StarRocks Integration
- **Native Delta Catalog**: Successfully verified reading Delta Lake tables directly from S3 (MinIO) without manifest generation.
- **Performance**: Sub-second queries on Delta Lake data using the `deltalake` catalog type.

### 🛡️ Production-Grade Spark Configs
- **Integer Timeouts**: Hardened `spark-defaults.conf` to use integer milliseconds (`600000`) instead of strings (`600s`), fixing legacy `NumberFormatException` crashes.
- **AWS SDK v2**: Unified `hadoop-aws:3.3.4` and `aws-java-sdk-bundle:2.20.160` in the `fix-v4` image to resolve classpath conflicts.
- **Auto-Initialization**: Fixed JupyterHub kernel setup to automatically define the `spark` session variable (`spark.kubernetes.driver.pod.name` fix).

---

## 🛠️ Deployment Instructions
1.  **Update Configs**:
    ```bash
    cp .env.example .env
    # Ensure SPARK_IMAGE_VERSION=fix-v4
    ```
2.  **Deploy**:
    ```bash
    ./deploy-gke.sh
    ```

## 🐛 Bug Fixes
- Fixed `NumberFormatException: For input string: "60s"` in S3A file system.
- Fixed `NoClassDefFoundError` for AWS SDK classes during Delta writes.
- Fixed `NameError: name 'spark' is not defined` in Notebooks.

---

# 🏷️ Release Notes: v0.1.0 (Initial Beta)

We are proud to announce the first official beta release of the **Cloud-Native Big Data Platform on GKE**. This release marks the transition from a legacy monolithic notebook setup to a scalable, multi-engine, and persistent Big Data architecture.

---

## 🚀 Key Features

### 🍱 The Multi-Notebook Suite
Deploy three industry-leading notebook environments with a single command:
- **JupyterHub**: Standardized for DE/DS teams with **Apache Toree** (Scala) and **SQL Magic**.
- **Marimo**: A reactive Python environment with **Zero-Config Spark Auto-Import** (automatically injects `spark`, `mo`, `pd`, and `np`).
- **Polynote**: IDE-quality Scala/Python interoperability from Netflix.

### 💎 Robust Spark-on-K8s
- **Python 3.11 Uniformity**: Zero-mismatch guarantee between Driver and Executors.
- **Delta Lake 3.2.0**: Production-ready ACID transactions on S3/MinIO.
- **Dynamic Config**: Runtime Pod-IP injection for stable Spark Client mode connections.

### 📊 Enterprise Observability
- **Prometheus/Grafana**: Deep-visibility dashboards for Spark JVM, Executor health, and Airflow task status.

---

## 🛠️ Deployment Summary
1. **Cluster**: GKE Standard/Autopilot (3+ nodes recommended).
2. **Setup**: `./deploy-gke.sh` (Kustomize + Helm orchestration).
3. **Persistence**: MinIO S3 for data lake and notebook storage.

## 🚧 Status: Beta
This version is stable for development and testing. **Unity Catalog** and **StarRocks** integration are currently in **Alpha/Experimental** state and are tracked for the `v0.2.0` milestone.

---

## 🏷️ How to Tag this Release
If you have Git configured, you can tag this version locally:
```bash
git tag -a v0.1.0 -m "Release v0.1.0: Initial Big Data Beta"
git push origin v0.1.0
```
