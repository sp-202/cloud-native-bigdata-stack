# 🔄 UPDATING.md

This document tracks breaking changes and significant updates to the platform that require manual intervention or specific migration steps.

## [2026-01-11] 🚀 The "Golden Stack" Migration (V2)

### ⚠️ Breaking Changes
- **Zeppelin Retired**: The Apache Zeppelin deployment has been removed. All notebooks should be migrated to JupyterHub or Marimo.
- **Python Alignment**: All Spark components (Driver and Executor) are now standardized on **Python 3.11**. If you have custom libraries, you must rebuild your images using the provided `docker/` build scripts.
- **Spark 3.5.3**: Upgraded from earlier Spark 3.x versions. Check your `SparkApplication` manifests for version compatibility.

### 📝 Update Instructions
1. **Build New Images**:
   ```bash
   docker/spark/build.sh
   docker/jupyterhub/build.sh
   docker/marimo/build.sh
   ```
2. **Re-apply Configs**:
   Run `./deploy-gke.sh` to update the ConfigMaps (specifically `spark-defaults.conf`).

---

## [Future] Plan for Unity Catalog (UC) High Availability
- **Upcoming**: Migration of UC from local storage to a persistent DB backend.
- **Impact**: Will require a schema migration for the catalog metadata.
