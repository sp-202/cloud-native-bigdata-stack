# 🩺 05-Monitoring: Observability Stack

This folder contains the manifests to deploy the Monitoring & Logging stack.

## 🛠 Deployment Strategy (Kustomize + Helm)

Unlike other folders which contain raw YAMLs, this folder relies heavily on `helmCharts` defined in `kustomization.yaml`. Kustomize dynamically downloads the specified Helm Charts (Prometheus, Loki) during the build process and renders them into YAML. Pre-rendered manifests are cached in `charts/gen/` for offline deployments.

## 📄 Components

### 1. `kube-prometheus-stack` (Helm)
*   **Role**: Metrics & Visualization.
*   **Contains**: Prometheus Operator, Grafana, AlertManager, NodeExporter.
*   **Customization**: Values are defined in `values-prometheus.yaml` to configure persistence, scrape intervals, and Grafana default passwords.

### 2. `loki-stack` (Helm)
*   **Role**: Log Aggregation.
*   **Components**:
    *   **Promtail**: Deployed as a DaemonSet (on every node). Reads `/var/log/containers`.
    *   **Loki**: The central server storing the logs.
    *   **Integration**: Automatically connected to Grafana as a Data Source.
*   **Customization**: Values are defined in `values-loki.yaml`.

### 3. Dashboards (Subfolder)
*   **Content**: JSON files (e.g., `spark-dashboard.json`).
*   **Mechanism**: `ConfigMapGenerator` in Kustomize turns these JSON files into ConfigMaps. A sidecar in the Grafana pod watches these ConfigMaps and auto-imports the dashboards.

### 4. Cilium Hubble (External)
*   **Note**: Cilium and Hubble are installed separately (via Helm during cluster bootstrap), not through this folder. The Hubble UI IngressRoute is defined in `01-networking/`.

## 📊 Access
| Service | URL |
| :--- | :--- |
| **Grafana** | `http://grafana.<INGRESS_DOMAIN>` |
| **Hubble UI** | `http://hubble.<INGRESS_DOMAIN>` |
