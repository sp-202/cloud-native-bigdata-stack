# 📦 JupyterHub Sub-chart

The primary interactive development environment for Data Engineers and Scientists.

## 🚀 Overview
- **Role**: Multi-user Jupyter notebook server with Spark integration.
- **Image**: `subhodeep2022/spark-bigdata:jupyterhub-...`
- **Sync Wave**: `0` (Application Layer).

## 🌟 Features
- **Pyspark & Scala**: Built-in support for multiple kernels.
- **Zeppelin Compatibility**: Includes `%sql` magic and `z.show()` display functions.
- **Direct Spark-on-K8s**: Spawns Spark executors dynamically in the cluster.

## 📂 Components
- **Deployment**: JupyterHub proxy and hub.
- **Service**: Load-balanced service for the hub.
- **ConfigMap**: Hub configuration and user environment settings.

## 🛠 Configuration
```yaml
jupyterhub:
  enabled: true
  hub:
    image: ...
```
