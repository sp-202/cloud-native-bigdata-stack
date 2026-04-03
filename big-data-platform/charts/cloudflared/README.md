# 📦 Cloudflared Sub-chart

Zero-Trust secure tunnel connecting the internal Traefik ingress to the Cloudflare edge.

## 🚀 Overview
- **Role**: Secure external access without open inbound ports.
- **Image**: `cloudflare/cloudflared:latest`.
- **Sync Wave**: `0` (concurrent with apps).

## 🔒 Security
No public LoadBalancer is required. The tunnel initiates an outbound connection to Cloudflare.

## 📂 Components
- **Deployment**: HA deployment of cloudflared replicas.
- **Secret**: Stores the Cloudflare Tunnel token.
- **ConfigMap**: Tunnel configuration and ingress rules mapping.

## 🛠 Configuration
```yaml
cloudflared:
  enabled: true
  tunnel_token: "YOUR_TOKEN"
```
