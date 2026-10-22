# Networking-extras Sub-chart

Traefik IngressRoutes plus an optional NetworkPolicy for the `default` namespace.

## Components
- **ArgoCD IngressRoute**: `argocd.<global.domain>` -> `argocd-server` (namespace `argocd`).
- **Traefik dashboard IngressRoute**: `traefik.<global.domain>/dashboard/`.
- **default-namespace-boundary** (off by default): plain `networking.k8s.io/v1` NetworkPolicy,
  enforced by Canal. Needs `networkPolicy.nodeCIDRs` when enabled — see the template header.

## Configuration
```yaml
networking-extras:
  enabled: true
  networkPolicy:
    enabled: false
    nodeCIDRs: ["192.168.1.0/24"]
    podCIDR: "10.42.0.0/16"
```
