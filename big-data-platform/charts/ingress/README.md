# 📦 Ingress Sub-chart

Centralized routing layer managing all external and internal traffic via Traefik.

## 🚀 Overview
- **Role**: HTTP(S) routing, SSL termination (via Cloudflare), and load balancing.
- **Sync Wave**: `0` (Application Layer - deployed concurrently with apps).

## 📂 Components
- **Ingress / IngressRoute**: Definitions for all platform services:
  - Airflow
  - JupyterHub
  - MinIO (Console & API)
  - Spark History
  - Hubble / Headlamp

## 🛠 Configuration
Managed under the `ingress` key in `values.yaml`.
```yaml
ingress:
  enabled: true
  domain: "sslip.io"
```
