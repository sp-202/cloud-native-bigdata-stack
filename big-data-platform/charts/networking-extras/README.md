# 📦 Networking-extras Sub-chart

Additional networking resources for advanced routing and observability.

## 🚀 Overview
- **Role**: IngressRoute extensions and specialized load-balancing rules.
- **Sync Wave**: `0` (Concurrent with apps).

## 📂 Components
- **ArgoCD IngressRoute**: Secure access to the ArgoCD dashboard.
- **Hubble UI IngressRoute**: Visibility into Cilium network flows.
- **S3 Redirects**: Specialized routing for internal S3-compatible API calls.

## 🛠 Configuration
```yaml
networking-extras:
  enabled: true
```
