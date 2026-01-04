# 🩺 05-Monitoring: Observability Stack

This folder contains the manifest logic to deploy the Monitoring & Logging stack.

## 🛠 Deployment Strategy (Kustomize + Helm)

Unlike other folders which contain raw YAMLs, this folder relies heavily on `helmCharts` defined in `kustomization.yaml`.
Kustomize dynamically downloads the specified Helm Charts (Prometheus, Loki, Dashboard) during the build process and renders them into YAML.

## 📄 Components

### 1. `kube-prometheus-stack` (Helm)
*   **Role**: Metrics & Visualization.
*   **Contains**: Prometheus Operator, Grafana, AlertManager, NodeExporter.
*   **Customization**: We inject `valuesInline` in `kustomization.yaml` to configure persistence (10Gi PVC) and default passwords.

### 2. `loki-stack` (Helm)
*   **Role**: Log Aggregation.
*   **Components**:
    *   **Promtail**: Deployed as a DaemonSet (on every node). Reads `var/log/containers`.
    *   **Loki**: The central server storing the logs.
    *   **Integration**: Automatically connected to Grafana as a Data Source.

### 3. `dashboards/` (Subfolder)
*   **Content**: JSON files (e.g., `spark-dashboard.json`).
*   **Mechanism**: We use a `ConfigMapGenerator` in Kustomize to turn these JSON files into ConfigMaps. A "Sidecar" in the Grafana pod watches these ConfigMaps and auto-imports the dashboards.
