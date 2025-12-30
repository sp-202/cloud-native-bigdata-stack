# Monitoring Guide: Spark on Kubernetes

## 1. Logs vs. Metrics
It is important to distinguish between **Logs** and **Metrics**:
*   **Logs**: Text output (stdout/stderr) from your application. Useful for debugging errors (e.g., `Exception in thread "main"`).
    *   *Where to see them*: `kubectl logs`, Spark UI (Executors tab), or Zeppelin Interpreter UI.
*   **Metrics**: Numerical data over time (e.g., Heap Memory Used = 2GB, CPU Usage = 80%, GC Time = 200ms).
    *   *Where to see them*: **Grafana** (visualized graphs).

## 2. Accessing Grafana
*   **URL**: [http://grafana.35.222.246.255.nip.io](http://grafana.35.222.246.255.nip.io)
*   **Username**: `admin`
*   **Password**: `prom-operator`

## 3. Importing the Spark Dashboard
To visualize your metrics, you need to import the dashboard configuration I created.

1.  Download the dashboard file: `kubernetes/spark-dashboard.json`.
2.  Open **Grafana** in your browser.
3.  In the left sidebar, click the **+** (Plus) icon -> **Import**.
4.  Click **"Upload JSON file"**.
5.  Select the `spark-dashboard.json` file from your project folder.
6.  Select the **Prometheus** data source if asked.
7.  Click **Import**.

## 4. Viewing Metrics
Once imported, run a Spark job in Zeppelin. You should see:
*   **Active Drivers**: Number of running Spark applications.
*   **Active Executors**: Number of executor pods.
*   **JVM Heap Memory**: Memory usage graph.
*   **Garbage Collection Rate**: Frequency of GC events (spikes indicate memory pressure).

## 5. Viewing Text Logs
To see the actual text logs for debugging:
1.  **Kubectl**:
    ```bash
    kubectl get pods
    kubectl logs <zeppelin-pod-name>
    ```
2.  **Spark UI**:
    *   Go to [http://spark.35.222.246.255.nip.io](http://spark.35.222.246.255.nip.io) (only works when job is active).
    *   Click **Executors** tab -> **stderr/stdout**.
