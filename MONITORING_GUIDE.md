# 📊 Kubernetes Big Data Monitoring Guide

This guide explains how to observe, debug, and monitor your Spark & Airflow workloads running on GKE.

---

## 1. Architecture Overview
We use the **Kube-Prometheus-Stack**, essentially the industry standard for Kubernetes monitoring.

*   **Prometheus**: Time-series database that "scrapes" (pulls) metrics from pods every 30s.
*   **ServiceMonitor**: A Custom Resource Definition (CRD) that tells Prometheus *which* pods to scrape. We have ServiceMonitors configured for:
    *   Spark Drivers (port 4040 metrics)
    *   Spark Executors
    *   Airflow StatsD
*   **Grafana**: Visualization UI that queries Prometheus.

---

## 2. Accessing Grafana

1.  Get your **LoadBalancer IP** (run `./deploy-gke.sh` to see it in the output, or check `kubectl get svc -n traefik`).
2.  Navigate to: `http://grafana.<YOUR_LB_IP>.sslip.io`
3.  **Default Credentials**:
    *   **User**: `admin`
    *   **Password**: `prom-operator`

---

## 3. Importing the Spark Dashboard

A custom Spark dashboard is likely located in `k8s-platform-v2/05-monitoring/dashboards/` (or similar path in your repo).

**Steps:**
1.  Open Grafana.
2.  Click the **Dashboards** icon (four squares) in the left sidebar -> **New** -> **Import**.
3.  Either upload the JSON file or paste the JSON content.
4.  Select **Prometheus** as the data source.
5.  Click **Import**.

---

## 4. Key Metrics to Watch

### 🟢 Cluster Health
*   **CPU / Memory Saturation**: Are nodes running out of capacity?
*   **PVC Usage**: Is MinIO or Postgres running out of disk space?

### ⚡ Spark Applications
*   **Active Executors**:
    *   *What it tells you*: Is dynamic allocation working? Are pods scaling up when a job starts?
    *   *Good sign*: Count goes from 0 -> N when job submits.
*   **JVM Heap Memory**:
    *   *What it tells you*: Are your executors running out of RAM (OOM)?
    *   *Warning sign*: Usage hits 90%+ and stays there.
*   **Garbage Collection (GC) Time**:
    *   *What it tells you*: How much time is wasted cleaning up memory instead of processing data.
    *   *Warning sign*: Major GC time spikes or frequent minor GCs slowing down the job.
*   **Shuffle Read/Write**:
    *   *What it tells you*: How much data is moving between nodes. High shuffle = network bottleneck.

---

## 5. Troubleshooting with Logs (The "Why")

Metrics tell you *something* is wrong. Logs tell you *why*.

### Method A: Spark UI (Live)
While a job is running, access the Spark UI through the Ingress:
`http://spark-ui.<YOUR_LB_IP>.sslip.io` (Check your specific ingress route)

### Method B: Kubectl (Post-Mortem)
If a pod crashes, the UI dies with it. Use `kubectl`:

**1. Find the Driver Pod:**
```bash
kubectl get pods -n big-data
# Look for pods like "zeppelin-server-..." or "spark-pi-driver..."
```

**2. Check Logs:**
```bash
# Recent logs
kubectl logs <pod-name> -n big-data

# Previous instance (if it crashed and restarted)
kubectl logs <pod-name> -n big-data --previous
```

**3. Describe Pod (For Startup Errors):**
If a pod is in `Pending` or `ImagePullBackOff` state:
```bash
kubectl describe pod <pod-name> -n big-data
# Look at the "Events" section at the bottom
```
