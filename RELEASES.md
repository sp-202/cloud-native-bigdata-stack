# 🏷️ Release Notes: v0.3.0 (The Spark Connect Revolution)

**Release Date:** 2026-01-16

This release introduces the **Spark Connect** architecture, fundamentally changing how notebooks interact with Spark compute. JupyterHub and Marimo now operate as **thin clients**, connecting to a centralized Spark Connect Server.

---

## 🚀 Key Features

### ⚡ Spark Connect Server
- **Centralized Compute**: A dedicated Spark server running with 4 dynamic executors.
- **gRPC Endpoint**: Port 15002 for thin-client connections.
- **Resource Efficiency**: Notebooks no longer spawn individual executor pods.
- **Delta Lake + HMS**: Pre-configured with Delta extensions and Hive Metastore integration.

### 📚 Comprehensive Documentation
- **HOW_TO_DEBUG.md**: New 6-step debugging guide for Spark Connect with commands and expected outputs.
- **15+ Files Updated**: All documentation reflects current architecture.
- **Architecture Diagrams**: Updated for thin-client model.

### 🔧 Version Upgrades
| Component | Previous | Current |
|-----------|----------|---------|
| Spark | 3.5.3 | **4.0.1** |
| Delta Lake | 3.2.0 | **4.0.0** |
| Hive Metastore | 3.x | **4.0.0** |
| AWS SDK | v1 | **v2 (2.20.160)** |

### 🗂 Repository Cleanup
- **archive-v2/**: Created for legacy Unity Catalog configurations.
- **Moved Files**: `patch-uc-*.yaml`, `uc-*.yaml`, legacy scripts.

---

## 🛠️ Deployment Instructions

1. **Pull Latest Code**:
   ```bash
   git pull origin main
   ```

2. **Update Environment**:
   ```bash
   cp .env.example .env
   # Verify SPARK_IMAGE_VERSION=fix-v4
   ```

3. **Deploy**:
   ```bash
   ./deploy-gke.sh
   ```

4. **Verify Spark Connect**:
   ```bash
   kubectl get pods -l app=spark-connect-server
   kubectl logs -l app=spark-connect-server --tail=50
   ```

---

## 🐛 Bug Fixes
- Fixed legacy client-mode documentation that no longer applies.
- Fixed outdated version references in docker READMEs.
- Fixed namespace references in k8s-platform-v2 documentation.

---

## 📋 Roadmap (v0.4.0)

> [!IMPORTANT]
> The following features are planned for the next release:

1. **Apache Iceberg Integration**
   - Add Iceberg table format support alongside Delta Lake
   - Configure Iceberg REST Catalog

2. **Delta Lake UniForm**
   - Enable UniForm for cross-format compatibility
   - Test reading Delta tables as Iceberg from StarRocks

3. **Unity Catalog (OSS) Re-integration**
   - Deploy Unity Catalog with HMS fallback
   - Configure storage credentials API for MinIO

---

## 🏷️ How to Tag this Release

```bash
git tag -a v0.3.0 -m "Release v0.3.0: Spark Connect Revolution"
git push origin v0.3.0
```

---

# 🏷️ Release Notes: v0.2.0 (The HMS & StarRocks Lakehouse)

This release stabilizes the **Data Lakehouse** architecture by completing the migration from Unity Catalog (OSS) to a production-ready **Hive Metastore (HMS)** setup.

---

## 🚀 Key Features

### 🏰 Standalone Hive Metastore (HMS)
- **Centralized Catalog**: Replaced embedded Derby/UC with a standalone Thrift Metastore (`hive-metastore:9083`).
- **Persistence**: Backed by PostgreSQL for metadata durability.
- **Compatibility**: Verified support for both Spark 4.0.1 and StarRocks 3.x.

### ⚡ Confirmed StarRocks Integration
- **Native Delta Catalog**: Successfully verified reading Delta Lake tables directly from S3 (MinIO).
- **Performance**: Sub-second queries on Delta Lake data using the `deltalake` catalog type.

### 🛡️ Production-Grade Spark Configs
- **Integer Timeouts**: Hardened `spark-defaults.conf` to use integer milliseconds.
- **AWS SDK v2**: Unified dependencies in the `fix-v4` image.

---

## 🐛 Bug Fixes
- Fixed `NumberFormatException: For input string: "60s"` in S3A file system.
- Fixed `NoClassDefFoundError` for AWS SDK classes during Delta writes.
- Fixed `NameError: name 'spark' is not defined` in Notebooks.

---

# 🏷️ Release Notes: v0.1.0 (Initial Beta)

The first official beta release of the **Cloud-Native Big Data Platform on GKE**.

## 🚀 Key Features
- **Multi-Notebook Suite**: JupyterHub, Marimo, and Polynote.
- **Delta Lake Support**: ACID transactions on MinIO S3.
- **Prometheus/Grafana**: Enterprise observability.

## 🏷️ How to Tag
```bash
git tag -a v0.1.0 -m "Release v0.1.0: Initial Big Data Beta"
git push origin v0.1.0
```
