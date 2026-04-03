# 🔄 UPDATING.md

This document tracks breaking changes and significant updates to the platform.

## [2026-04-03] 🌐 v0.5.0: The Umbrella Chart Refactor

### ⚠️ Breaking Changes
- **Manifest Move**: All standalone YAML manifests in `k8s-platform-v2/` have been consolidated into the Helm Umbrella Chart `big-data-platform/`.
- **Sync Wave Logic**: The platform now enforces strict ArgoCD Sync Waves. Resources in Wave 0 will stay in "Degraded" if Wave -1 jobs (migrations) fail.
- **Ingress Consolidation**: All Ingress and IngressRoute definitions are now managed by the `ingress` sub-chart. Ad-hoc ingresses should be moved there.

### 📝 Update Instructions
1.  **Switch to Helm**: If you were using `kubectl apply -k`, delete those resources and redeploy using the `big-data-platform` Helm chart.
2.  **Verify Values**: Copy your custom configurations from `.env` or legacy manifests into `big-data-platform/values.yaml`.

---

## [2026-03-26] 🚀 v0.4.0: Zero-Trust Ingress (Cloudflare)

### ⚠️ Breaking Changes
- **Traefik Public IP removed**: External access via MetalLB Elastic IP is deprecated. Access must now go through Cloudflare Tunnel.
- **Port 80/443 closed**: You may now close inbound firewall ports on EC2 instances.

### 📝 Update Instructions
1. **Enable cloudflared**: Set `cloudflared.enabled: true` in `values.yaml`.
2. **Configure Tunnel**: Add your `tunnel_token` to the cloudflared secret.

---

## [2026-01-13] 🌟 v0.2.0: The HMS & StarRocks Lakehouse
... [rest of file] ...
