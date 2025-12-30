# 🔍 Monitoring - Detailed Guide

## 1. The Stack: Prometheus Operator
We use the **Kube Prometheus Stack**. It installs:
*   **Prometheus**: Time-series database.
*   **Grafana**: Visualization.
*   **AlertManager**: Alerting (not fully configured).
*   **Operator**: Manages CRDs (`ServiceMonitor`, `PodMonitor`).

## 2. Custom Resource Definitions (CRDs)
This is how we scrape metrics without editing `prometheus.yaml` manually.

### PodMonitor (`kubernetes/monitor-spark.yaml`)
*   **What it does**: Tells Prometheus "Look for Pods with label `spark-role: driver`".
*   **Endpoint**: Scrapes port `4040` at path `/metrics/prometheus`.
*   **Why PodMonitor?**: Spark Pods spin up and down dynamically. A ServiceMonitor requires a Service, but Spark Executors don't always have one. PodMonitor directly watches the Pod List.

### ServiceMonitor
*   **Target**: `zeppelin`.
*   **Reason**: Zeppelin is a stable Deployment with a Service.

## 3. Data Retention
*   **Config**: `prometheus.prometheusSpec.storageSpec` in `deploy-infra.sh` (Helm values).
*   **Size**: `10Gi` PVC.
*   **Duration**: ~7 Days (depending on metric volume).
*   **Persistence**: If you delete the Prometheus Pod, the PVC remains, so data survives.

## 4. Grafana Dashboards
*   **Admin Password**: `prom-operator` (set in `deploy-infra.sh`).
*   **Data Source**: URL `http://prometheus-operated:9090`.
*   **Spark Dashboard**: Included JSON imports Metrics like `jvm_memory_bytes_used` and `spark_job_executor_active_tasks`.

## 5. Troubleshooting
*   **"No Data" in Grafana**:
    1.  Check Prometheus Targets: port-forward prometheus (`kubectl port-forward svc/prometheus-operated 9090`) and go to `Status` -> `Targets`.
    2.  Are the targets "UP"? If "Down", check network. If missing, check labels on the `PodMonitor`.
