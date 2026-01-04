# 🔍 Prometheus & Grafana Guide

The platform uses the **Kube-Prometheus-Stack** (CoreOS) to provide comprehensive observability.

---

## 1. Architecture

### Prometheus Operator
We do not configure `prometheus.yaml` manually. Instead, we use Kubernetes **Custom Resources**:
*   **`ServiceMonitor`**: Tells Prometheus to scrape a Kubernetes Service (e.g., Zeppelin, Superset).
*   **`PodMonitor`**: Tells Prometheus to scrape Pods directly (crucial for **Spark**, which uses headless services or ephemeral executor pods).

### The Flow
1.  **Spark Pod** start up.
2.  **Prometheus Operator** detects the pod labels (`spark-role: driver`).
3.  **Prometheus Server** starts scraping `http://<pod-ip>:4040/metrics/prometheus`.
4.  **Grafana** queries Prometheus to draw charts.

---

## 2. Grafana Dashboards

We pre-inject standard dashboards via ConfigMaps.

### ⚡ Spark Dashboard
*   **Driver Heap usage**: Critical for OOM debugging.
*   **Executor Count**: Verifies dynamic allocation scaling.
*   **Active Tasks**: Shows concurrency.
*   **Shuffle I/O**: High shuffle read/write indicates inefficient joins/aggregations.

### 🪵 Loki / Logs Dashboard
*   Allows viewing logs side-by-side with metrics (Split view).

---

## 3. Alerting (AlertManager)

The stack includes **AlertManager**. By default, it contains standard K8s alerts (NodeDown, KubeletDown).
*   **Config**: `k8s-platform-v2/05-monitoring/charts/kube-prometheus-stack/values.yaml` (inside the Kustomize helmCharts block).
*   **Adding Alerts**: You can define `PrometheusRule` CRDs in the `05-monitoring` folder.

---

## 4. Troubleshooting

### "No Data" in Grafana
1.  **Check Targets**: Port-forward Prometheus and check the "Targets" page.
    ```bash
    kubectl port-forward svc/prometheus-operated 9090:9090
    # Open http://localhost:9090/targets
    ```
2.  **Check Labels**: The `PodMonitor` selects pods by **Label**. Ensure your Spark Application has the correct labels:
    ```yaml
    spark-role: driver
    ```
    (This is handled automatically by the Spark Operator, but good to verify).

---

[⬅ Back to README](../README.md)
