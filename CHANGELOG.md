# 📜 CHANGELOG.md

All notable changes to this project will be documented in this file.

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
- **Ingress IP Updated**: Platform ingress IP changed to `3.228.1.250`.
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
