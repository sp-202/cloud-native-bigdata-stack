# 📒 Apache Zeppelin on GKE - Detailed Guide

Zeppelin serves as the **Interactive Development Environment (IDE)** for this platform, allowing users to write Spark (Scala/Python/SQL) code in a notebook interface.

---

## 1. How it Runs (Client Mode)
In our setup, Zeppelin acts as a **Spark Driver** in "Client Mode".
*   **The Zeppelin Pod** = The Spark Driver.
*   **Executors**: When you run a paragraph, Zeppelin requests Executor Pods from Kubernetes dynamically.

**Implication**: If the Zeppelin Pod dies, the Spark Context dies.

---

## 2. Notebook Persistence (S3/MinIO)

We do **not** store notebooks on the pod's disk. We use the **S3NotebookRepo** implementation.

### Configuration (`kubernetes/zeppelin.yaml`)
```yaml
env:
  - name: ZEPPELIN_NOTEBOOK_STORAGE
    value: "org.apache.zeppelin.notebook.repo.S3NotebookRepo"
  - name: ZEPPELIN_NOTEBOOK_S3_ENDPOINT
    value: "http://minio:9000"
  - name: ZEPPELIN_NOTEBOOK_S3_BUCKET
    value: "notebooks"
```

**Benefits**:
1.  **Stateless**: You can upgrade/delete the Zeppelin deployment without losing work.
2.  **Versioning**: MinIO supports object versioning (if enabled).

---

## 3. Memory & Resource Tuning

Zeppelin is memory-hungry. It runs a JVM for the server + a JVM for **each** interpreter.

*   **Server JVM**: Controls the UI and WebSocket logic.
    *   *Tuning*: `ZEPPELIN_MEM: "-Xms1024m -Xmx2048m"`
*   **Interpreter JVM**: The actual Spark process.
    *   *Tuning*: Configured via the `spark.driver.memory` setting in the Interpreter UI.

**Tip**: If the UI feels sluggish or "disconnects" often, check resource limits. WebSocket connections often drop if the Server JVM hits Garbage Collection pauses.

---

## 4. Common Issues

### ❌ "Interpreter Exception: ClassNotFound"
This usually happens if the Spark Interpreter allows dependencies that aren't in the Zeppelin image.
*   **Fix**: Ensure your Zeppelin image shares the compatible Spark version with the cluster.

### ❌ "Paragraph runs forever"
Zeppelin cannot talk to the Executor pods.
*   **Fix**: Check **Network Policies**. The Executors (in `big-data` namespace) must be able to reach the Driver (Zeppelin) on all ports.

### ❌ "Access Denied" on Notebook Save
*   **Fix**: Check the `AWS_ACCESS_KEY_ID` / `SECRET` passed to the Zeppelin pod. Ensure the `notebooks` bucket exists in MinIO.

---

[⬅ Back to README](../README.md)
