# 📜 Logging Guide (Loki & Spark History)

This platform provides three layers of logging:
1.  **Loki (Aggregated)**: Searchable logs from all pods in Grafana.
2.  **Spark History (Persistent)**: Post-mortem analysis of finished Spark jobs.
3.  **Kubectl (Live)**: Low-level debugging.

---

## 1. Aggregated Logging (Loki + Grafana)

We employ the **Loki Stack**.
*   **Promtail**: Runs on every node, tails container logs, and sends them to Loki.
*   **Loki**: Stores the logs efficiently.
*   **Grafana**: The UI to query Loki.

### How to Access
1.  Open **Grafana**.
2.  Click **Explore** (Compass Icon on left sidebar).
3.  Ensure data source is set to **Loki** (top left dropdown).

### Querying Logs (LogQL)
Loki uses labels to filter logs.

**Examples:**
*   **See all logs for Airflow**:
    ```
    {app="airflow"}
    ```
*   **See logs for a specific Spark Driver**:
    ```
    {spark_role="driver"}
    ```
*   **Search for errors**:
    ```
    {namespace="big-data"} |= "error"
    ```

---

## 2. Spark History Server (Persistent Logs)

When a Spark Application finishes (or crashes), the pods disappear. `kubectl logs` won't work.
For this, we enabled **Spark Event Logging** to MinIO.

1.  **Logs Location**: `s3a://spark-logs/` (in MinIO).
2.  **Viewing**:
    *   Currently, you can view the raw files in **MinIO Console** (`http://minio...`).
    *   These logs can be replayed by a Spark History Server (if deployed separately) or downloaded and viewed in a local Spark History instance.

---

## 3. Real-time Debugging (Kubectl)

For "tailing" logs while developing:

```bash
# Follow logs of the Airflow Scheduler
kubectl logs -f -n big-data -l app=airflow-scheduler -c airflow-scheduler

# Check previous crash logs
kubectl logs --previous -n big-data <pod-name>
```

---

[⬅ Back to README](../README.md)
