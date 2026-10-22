# Ingress Sub-chart

One `networking.k8s.io/v1` Ingress (class `traefik`) for the platform UIs, each at
`<name>.<global.domain>` — on RKE2 the domain is `<node-ip>.sslip.io`.

- **Sync Wave**: `0`
- **Hosts**: airflow, grafana, prometheus, spark-history, gravitino, plus superset /
  jupyterhub / spark when their charts are enabled (flip `ingress.<name>.enabled` together
  with the real chart).
- Traefik dashboard and ArgoCD routes live in `networking-extras`.
