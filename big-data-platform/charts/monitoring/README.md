# 📦 Monitoring Sub-chart

Comprehensive observability stack for metrics, logs, and network flows.

## 🚀 Overview
- **Tools**: Prometheus Operator, Grafana, Loki.
- **Sync Wave**: `0` (Application Layer).

## 📊 Features
- **ServiceMonitors**: Automated scraping for Spark, Airflow, and Cloudflared.
- **Dashboards**: Pre-configured Grafana boards for cluster health.
- **Loki Stack**: Centralized log aggregation for all pods.

## 📂 Components
- **ConfigMaps**: Grafana dashboards and Prometheus rules.
- **ServiceMonitors**: CRDs for target discovery.

## 🛠 Configuration
```yaml
monitoring:
  enabled: true
  grafana:
    adminPassword: "prom-operator"
```
