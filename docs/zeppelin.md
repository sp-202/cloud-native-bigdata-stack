# 📒 Apache Zeppelin - Detailed Guide

## 1. Overview
Zeppelin is the interactive notebook interface. In our setup, it runs **Spark on Kubernetes** in "Client Mode" (where the Zeppelin Pod acts as the Driver) or "Cluster Mode" via the Operator.

## 2. Configuration Analysis (`kubernetes/zeppelin.yaml`)

### Memory Tuning (Critical)
*   **Setting**: `ZEPPELIN_MEM: "-Xms1024m -Xmx4096m"`
*   **Effect**: Gives the Zeppelin JVM 4GB of RAM.
*   **Why?**: Without this, Zeppelin defaults to ~512MB. Loading a large Spark UI or autocomplete index causes it to crash or hang ("Slow Loading").

### Notebook Storage (S3/MinIO)
We do **not** use PVCs for notebooks. We use S3.
*   `ZEPPELIN_NOTEBOOK_STORAGE`: `org.apache.zeppelin.notebook.repo.S3NotebookRepo`
*   `ZEPPELIN_NOTEBOOK_S3_ENDPOINT`: `http://minio:9000`
*   **Effect**: All notes are saved to the `notebooks` bucket.
*   **Benefit**: You can delete the Zeppelin Pod (`kubectl delete pod zeppelin`) and **lose nothing**. Your code is safe in MinIO.

### Access Control
*   **Anonymous Access**: Enabled by default.
*   **Shiro Config**: `zeppelin-site.xml` controls authentication. To add users, you must edit `shiro.ini` inside the container or mount a Secret.

## 3. Interpreter Configuration
Each "Interpreter" (Spark, Python, JDBC) runs as a separate process (or Pod).
*   **K8s Mode**: configured to spawn executors dynamically.
*   **Image Pull Policy**: `Always`. ensures you get the latest code changes if you update the Spark image.

## 4. Common Issues
| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| **"Interpreter for Note not found"** | The interpreter process crashed or disconnected. | Click the "Restart" button in Zeppelin Interpreter settings. |
| **"Paragraph runs indefinitely"** | Spark Driver cannot talk to Executors. | Check `headless-service` and Security Groups/Network Policies. |
| **UI is sluggish** | Memory Pressure. | Increase `ZEPPELIN_MEM` and `resources.limits.memory` in `zeppelin.yaml`. |
