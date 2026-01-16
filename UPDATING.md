# 🔄 UPDATING.md

This document tracks breaking changes and significant updates that require manual intervention or specific migration steps.

---

## [2026-01-16] 🚀 v0.3.0: The Spark Connect Revolution

### ⚠️ Breaking Changes

- **JupyterHub Architecture Changed**: JupyterHub no longer spawns executor pods. It now connects to a centralized **Spark Connect Server** via gRPC.
- **Legacy Files Archived**: UC patch files and legacy scripts moved to `archive-v2/`.
- **New Environment Variable**: `SPARK_REMOTE` required in notebook pods.

### 📝 Update Instructions

1. **Pull Latest Code**:
   ```bash
   git pull origin main
   ```

2. **Verify Spark Connect Server**:
   After deployment, ensure the server is running:
   ```bash
   kubectl get pods -l app=spark-connect-server
   # Expected: spark-connect-server-xxxxx   Running
   ```

3. **Update JupyterHub Config** (if customized):
   Ensure your JupyterHub deployment has:
   ```yaml
   env:
     - name: SPARK_REMOTE
       value: "sc://spark-connect-server-driver-svc:15002"
   ```

4. **Re-deploy**:
   ```bash
   ./deploy-gke.sh
   ```

### 📖 Documentation Changes
- `JUPYTERHUB_GUIDE.md` - Complete rewrite for Spark Connect
- `HOW_TO_DEBUG.md` - New debugging guide added
- All `docs/*.md` files updated for thin-client architecture

---

## [2026-01-13] 🌟 v0.2.0: The HMS & StarRocks Lakehouse

### ⚠️ Breaking Changes

- **Unity Catalog Removed**: Replaced by **Hive Metastore (Standalone)** as the central catalog.
- **Spark Image Upgrade**: Now requires `fix-v4` tag (`hadoop-aws-3.3.4` + `aws-java-sdk-bundle-2.20.160`).
- **Config Updates**: `spark-defaults.conf` now enforces integer timeouts (e.g., `600000` instead of `600s`).

### 📝 Update Instructions

1. **Update `.env`**:
   ```bash
   SPARK_IMAGE_VERSION=fix-v4
   ```

2. **Re-deploy Configs**:
   ```bash
   ./deploy-gke.sh
   ```
   *(This updates the `spark-defaults` ConfigMap and `jupyterhub` deployment)*

---

## [2026-01-11] 🚀 v0.1.0: The "Golden Stack" Migration (V2)

### ⚠️ Breaking Changes

- **Zeppelin Retired**: All notebooks should be migrated to JupyterHub or Marimo.
- **Python Alignment**: All Spark components standardized on **Python 3.11**.
- **Spark Upgraded**: From earlier 3.x versions to 3.5.3 (now 4.0.1 in v0.3.0).

### 📝 Update Instructions

1. **Build New Images**:
   ```bash
   docker/spark/build.sh
   docker/jupyterhub/build.sh
   docker/marimo/build.sh
   ```

2. **Re-apply Configs**:
   Run `./deploy-gke.sh` to update ConfigMaps.

---

## [Future] v0.4.0: Table Format Interoperability

### 🔮 Planned Changes

- **Iceberg Support**: Adding Apache Iceberg alongside Delta Lake.
- **UniForm Testing**: Enabling Delta Lake UniForm for cross-format compatibility.
- **Unity Catalog Return**: Re-integration with HMS fallback support.

### 📋 See Also

- [PLAN.md](PLAN.md) - Detailed v0.4.0 roadmap
- [RELEASES.md](RELEASES.md) - Release notes and feature descriptions
