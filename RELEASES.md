# 🏷️ Release Notes: v0.1.0 (Initial Beta)

We are proud to announce the first official beta release of the **Cloud-Native Big Data Platform on GKE**. This release marks the transition from a legacy monolithic notebook setup to a scalable, multi-engine, and persistent Big Data architecture.

---

## 🚀 Key Features

### 🍱 The Multi-Notebook Suite
Deploy three industry-leading notebook environments with a single command:
- **JupyterHub**: Standardized for DE/DS teams with **Apache Toree** (Scala) and **SQL Magic**.
- **Marimo**: A reactive Python environment for the next generation of data exploration.
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
