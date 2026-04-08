# 📜 CHANGELOG.md

All notable changes to this project will be documented in this file.

## [v1.0.1] - 2026-04-08 ✨ **Complete Gravitino Migration**

### 🚀 Major Milestone: Full Migration from Hive Metastore to Apache Gravitino

This release marks the **completion of the platform-wide migration** from Hive Metastore (HMS) to **Apache Gravitino 1.2.0** as the primary unified metadata catalog.

### ✨ What's New

#### 🏰 Gravitino as Primary Catalog
- **Replaced**: Hive Metastore is no longer the default catalog for new tables
- **Unified Metadata**: Single catalog interface for Iceberg, Delta, and Hive-format tables
- **Iceberg REST Catalog**: Gravitino IRC (port 9001) serves table metadata to downstream systems (StarRocks, Spark)
- **Spark Plugin**: All Spark applications now use `GravitinoSparkPlugin` for automatic catalog discovery

#### ⚡ Technical Improvements
- **Spark Version**: Downgrade from 4.0.1 → **3.5.8** for better stability and broader ecosystem compatibility
- **Iceberg Integration**: Upgraded to **Iceberg 1.10.1** for advanced table features (Z-ordering, partition evolution)
- **Gravitino Plugin**: Integrated `gravitino-spark-connector-runtime` for seamless Spark-Gravitino integration
- **Multi-Catalog Support**: Spark can now access multiple catalogs dynamically (lakehouse-iceberg, sales_catalog, etc.)

#### 🔄 StarRocks Catalog Access
- **Iceberg REST Integration**: StarRocks now accesses Iceberg tables directly through Gravitino IRC
- **No HMS Dependency**: Removed direct HMS dependency for StarRocks OLAP queries
- **Performance**: Sub-second queries on Delta/Iceberg tables via native catalog support

#### 📚 Documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Updated with Gravitino architecture, data flows, and catalog topology
- **[README.md](README.md)** — Updated component status and tech stack to reflect Gravitino
- **[big-data-platform/README.md](big-data-platform/README.md)** — Added Gravitino sub-chart documentation

### 🔧 Breaking Changes

- **Hive Metastore as Primary**: HMS is now a secondary/backward-compatibility catalog only
- **Spark Configuration**: Default catalog changed from `spark_catalog` (HMS) to Gravitino catalogs
- **StarRocks DSN**: Must use Gravitino IRC endpoint instead of direct HMS connection

### 🎯 Migration Path

If you have existing Hive tables:

1. **Read-Only Compatibility**: Legacy Hive tables remain queryable through HMS (backward compatible)
2. **Recommended**: Create new tables using Gravitino catalogs (Iceberg format preferred)
3. **Optional**: Migrate Hive tables to Iceberg using `CALL iceberg.system.migrate_hive_table()` if needed

### 🐛 Fixes
- Resolved Gravitino S3FileIO NoClassDefFoundError by adding AWS SDK bundle to catalog libs
- Fixed JDBC driver configuration for Gravitino's iceberg-rest catalog backend
- Enhanced Gravitino deployment with dynamic config provider for Web UI visibility

### 📋 Known Limitations (Resolved)
- ✅ CRD annotation limits (Spark Operator CRDs now copied locally)
- ✅ Airflow resource naming (`big-data-platform-*` prefix aligned with Ingress)
- ✅ Superset admin user creation (removed duplicate init jobs)

---

## [v1.0.0] - 2026-04-04 🎉

### 🚀 Production Release
**Status**: PRODUCTION READY  
**Stability**: Enterprise-grade, fully tested

This is the **first official production release** of the Cloud-Native Big Data Platform. The platform has reached maturity through comprehensive testing, bug fixes, and production hardening.

### ✨ Major Milestones
- ✅ **AWS EKS Migration Complete**: Full transition from GKE to self-managed Kubernetes on AWS EC2
- ✅ **Zero-Trust Networking**: Cloudflare Tunnel eliminates inbound firewall ports
- ✅ **Cilium CNI (ENI IPAM)**: Native AWS VPC networking for pods
- ✅ **All Critical Issues Fixed**: Spark Kryo, HMS SDK, admin user creation
- ✅ **Production Documentation**: DEBUG_GUIDE.md, DEPLOYMENT.md, ARCHITECTURE.md

### 🔄 What's Included
- **Spark 4.0.1** + **Delta Lake 4.0.1** + **Hive Metastore 4.1.0**
- **StarRocks 3.x** with native Delta Catalog
- **Airflow 2.10.x** with KubernetesExecutor
- **JupyterHub 4.0.7** + **Marimo** + **Polynote**
- **Prometheus/Grafana/Loki** observability stack
- **Helm Umbrella Chart** with Sync Waves orchestration
- **ArgoCD** for GitOps deployment management

### ⚙️ Technical Improvements (carried from v0.5.1)
- Fixed Spark Kryo registrator class name (core.serde not spark)
- Replaced HMS AWS SDK v1 → v2 (v2.29.52)
- Enhanced Superset init job for auto-user creation
- Added Airflow webserver.defaultUser configuration
- Cleaned up README.md for professional quality

### 📚 Documentation
All documentation is professional, comprehensive, and production-ready:
- [DEBUG_GUIDE.md](DEBUG_GUIDE.md) — Troubleshooting procedures
- [DEPLOYMENT.md](DEPLOYMENT.md) — Installation & verification
- [ISSUES.md](ISSUES.md) — Root cause analysis
- [ARCHITECTURE.md](ARCHITECTURE.md) — Technical deep-dive

### 🎯 Known Limitations
- UC OSS disabled (use Hive Metastore instead)
- Single-replica Spark Connect Server (no HA yet)
- Single-region deployment only

---

## [v0.5.1] - 2026-04-04

### 🐛 Fixed
- **Spark Kryo Serialization Error** (`[FAILED_REGISTER_CLASS_WITH_KRYO]`): Fixed incorrect Kryo registrator class name `org.apache.sedona.spark.SedonaKryoRegistrator` → `org.apache.sedona.core.serde.SedonaKryoRegistrator`. Updated in Dockerfile, configmap.yaml, and deployment.yaml. Root cause: Spark was trying to register a non-existent class when initializing Sedona extensions.
  
- **Superset 500 Internal Server Error on First Login**: Fixed missing `user_attribute` database table that caused "Sorry, something went wrong" errors. Root cause: The chart's built-in init job did not reliably run `superset init`. Solution: Enhanced `superset-init.yaml` PostSync job to always run `db upgrade && init && fab create-admin` after each ArgoCD sync, ensuring full database initialization.

- **Airflow Admin User Not Auto-Created**: Added `webserver.defaultUser` config to values.yaml so Airflow auto-creates the default admin user (`admin`/`admin`) on first pod startup. Prevents manual user creation via exec.

- **Hive Metastore ClassNotFoundException on S3 Operations** (`SdkException: software.amazon.awssdk.core.exception.SdkException`): Fixed by replacing AWS SDK v1 (`aws-java-sdk-bundle-1.12.367.jar`) with AWS SDK v2 (`bundle-2.29.52.jar` + `url-connection-client-2.29.52.jar`) in HMS Dockerfile. Root cause: `hadoop-aws-3.4.1` requires AWS SDK v2 classes which were missing; when creating databases (which triggers S3 operations), HMS failed with a Thrift socket close error. Bumped HMS image tag to `hive-4.1.0-custom-prod-v2`.

- **Spark `CREATE DATABASE` Command Failing**: Spark and Hive Metastore now properly synchronized with matching AWS SDK v2 versions. Previously, even creating a Hive database in Spark would fail with Thrift protocol mismatches.

### 🔄 Changed
- **Superset Admin User Creation**: Now uses `fab create-admin` via the PostSync job (idempotent via `|| true`), eliminating the need for manual `kubectl exec` user creation.

---

## [v0.5.0] - 2026-04-03

### 🚀 Added
- **Helm Umbrella Chart Architecture**: Migrated all standalone manifests into a modular, high-performance Umbrella Chart (`big-data-platform`).
- **ArgoCD Sync Wave Strategy**: Implemented a 4-tier sync-wave ordering system (-3 to 0) to ensure infrastructure (Postgres, MinIO) and secrets are fully ready before application pods (Airflow, JupyterHub) initialize.
- **Dynamic Local Storage Paths**: Automated host-path directory creation across EC2 nodes using privileged debug containers, resolving `MountVolume.SetUp` failures for Airflow and StarRocks.

### 🔄 Changed
- **Unified Configuration**: Centralized all platform variables into a single `values.yaml` file.
- **Networking Refactor**: Moved all Traefik Ingress and IngressRoute definitions from static manifests to the Helm `ingress` sub-chart and moved them to Sync Wave 0 for concurrent deployment with applications.

### 🐛 Fixed
- **Airflow Scheduler/Triggerer Init Deadlock**: Resolved volume mount failures by pre-provisioning `/var/openebs/local` directories on worker nodes.
- **Ingress 404 Discrepancy**: Fixed a Helm template bug where the `sync-wave` annotation was omitted if custom annotations were not provided.

## [v0.4.0] - 2026-03-26

### 🚀 Added
- **GitHub Actions CI/CD** (`.github/workflows/docker-build.yml`): Automatic multi-arch (`linux/amd64` + `linux/arm64`) Docker builds triggered on any `docker/*/Dockerfile` change pushed to `main`. Covers all 5 images: `hive`, `spark`, `jupyterhub`, `marimo`, `k8s-git-sync`. Supports `workflow_dispatch` for manual per-image builds.
- **Cloudflare Tunnel (`cloudflared`)**: Production-grade zero-trust ingress replacing the public LoadBalancer. 3-replica HA deployment in a dedicated `cloudflare` namespace with topology spread constraints, PodDisruptionBudget, NetworkPolicy, RBAC, Prometheus ServiceMonitor, and Cilium policy fix. No inbound firewall ports required.

### 🔄 Changed
- **Hive Metastore upgraded 3.1.3 → 4.1.0**: Resolves `exec format error` on ARM64 Graviton nodes. `apache/hive:4.1.0` is based on `eclipse-temurin:21-jre-ubi9-minimal` which ships native `linux/arm64` support.
- **Hive base image package manager**: Replaced `apt-get` with `microdnf` — UBI9-minimal does not include apt.
- **Hadoop AWS JARs bumped to 3.4.1**: Aligns Hive's S3 connector with Spark 4.1.1's Hadoop version (was 3.1.0 / 3.3.6).
- **AWS SDK bundle bumped to 1.12.367**: Consistent across Hive and HMS init-container (was 1.11.271).
- **Spark version 4.0.1 → 4.1.1**: Updated in `docker/spark/Dockerfile` and all references.
- **Custom Hive image tag**: `hive-3.1.3-custom-prod` → `hive-4.1.0-custom-prod` across `hive.yaml` and `hms.yaml`.
- **Traefik service type**: Changed from `LoadBalancer` to `ClusterIP` — external traffic now enters exclusively via Cloudflare Tunnel. Removes dependency on MetalLB for external exposure.

### 🐛 Fixed
- **`exec format error` on arm64 nodes**: Root cause was `apache/hive:3.1.3` having no `linux/arm64` layer. Fixed by upgrading to Hive 4.1.0.
- **CI/CD skipped jobs on re-run**: Replaced `github.event.commits[*].modified` array-concatenation logic (invalid `+` operator) with `git diff --name-only` in a `detect-changes` job for reliable change detection.

---

## [v0.3.1] - 2026-03-09
### 🚀 Added
- **Headlamp UI**: Integrated the modern Headlamp dashboard to replace the deprecated Kubernetes Dashboard.

### 🔄 Changed
- **ARM64 Compatibility**: Migrated Superset and Spark Operator init/cleanup containers to multi-arch images (`busybox` and `kubeflow/spark-operator`).
- **Startup Resilience**: Injected intelligent wait loops for Airflow DB initialization and tuned StarRocks liveness probes to handle slower ARM bootstrap times.
- **Hubble UI Routing**: Fixed a Traefik cross-namespace routing drop by moving the `IngressRoute` to `kube-system`.

### 🐛 Fixed
- **API Server Deadlock**: Hardcoded the local loopback routing for the master node IP to bypass Cilium's ENI policy drops, instantly restoring Kubernetes control-plane stability.
- **Helm GitHub Pages Outage**: Modified the deployment script to circumvent global 404 errors from `.github.io` Helm repositories by pulling Headlamp raw manifests directly.

---

## [v0.3.0] - 2026-03-07
### 🚀 Added
- **AWS Infrastructure**: Full migration from GKE to self-managed Kubernetes on AWS EC2 (kubeadm).
- **Cilium CNI (AWS ENI IPAM)**: Replaced default CNI with Cilium in AWS ENI mode for native VPC pod networking.
- **ARM64 Support**: All custom Docker images rebuilt for `linux/arm64` to run on AWS Graviton instances.
- **Spark Connect Server**: Introduced Spark Connect as a shared Spark gateway for JupyterHub and other clients.
- **Airflow Git-Sync**: DAGs are synchronized from a Git repository automatically.
- **Spark History Server**: Added for reviewing completed Spark job logs.
- **Hubble UI**: Cilium Hubble observability UI exposed via IngressRoute.

### 🔄 Changed
- **Traefik Refactor**: Removed `hostNetwork: true` binding; Traefik runs as `type: LoadBalancer` via MetalLB with dedicated Elastic IP.
- **Deploy Script**: Renamed `deploy-gke.sh` → `deploy-v2.sh` with K8s/kubeadm native support.
- **Ingress IP Updated**: Platform ingress IP changed to `44.203.26.241`.
- **Monitoring Charts Refreshed**: Regenerated kube-prometheus-stack Helm manifests.

### 🗑 Removed
- **Kubernetes Dashboard Chart**: Removed generated dashboard chart (using kubectl proxy instead).
- **Legacy Root Files**: Moved unused scripts and configs to `archive/`.

---

## [v0.2.0] - 2026-02-24
### 🚀 Added
- **MetalLB Integration**: Enabled Layer 2 LoadBalancing for bare-metal/raw K8s clusters.
- **OpenEBS Dynamic Provisioning**: Replaced manual Local PVs with `openebs-hostpath` for automated storage lifecycle.

### 🔄 Changed
- **Traefik Networking**: Switched from `hostNetwork` to `type: LoadBalancer` for improved isolation and static IP management via MetalLB.
- **Storage Strategy**: Migrated all stateful components (MinIO, Postgres, StarRocks, Prometheus, Airflow) to dynamic OpenEBS storage.

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
