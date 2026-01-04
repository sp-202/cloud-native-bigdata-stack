# ⚡ Apache Spark on Kubernetes - Detailed Guide

This project leverages the **Kubeflow Spark Operator** for native Kubernetes integration, allowing Spark to run as a first-class citizen on GKE.

---

## 1. Architecture Overview

### The Spark Operator
Instead of manually managing Driver/Executor pods, we submit a **Custom Resource** called `SparkApplication` (YAML).
1.  **User** submits YAML to K8s API.
2.  **Operator** sees the YAML and spawns a **Driver Pod**.
3.  **Driver Pod** requests **Executor Pods** directly from K8s.
4.  **Executors** run tasks and report back to Driver.
5.  **Driver** persists logs to MinIO (for History Server) and shuts down.

---

## 2. Configuration Analysis

We use a global `spark-defaults.conf` ConfigMap to streamline settings across all jobs.

### Critical S3/MinIO Settings
Most complexity comes from connecting Spark to Object Storage (S3/MinIO).

| Config Key                              | Value                                          | Explanation                                                                        |
| :-------------------------------------- | :--------------------------------------------- | :--------------------------------------------------------------------------------- |
| `spark.hadoop.fs.s3a.impl`              | `org.apache.hadoop.fs.s3a.S3AFileSystem`       | Uses AWS SDK to talk to storage.                                                   |
| `spark.hadoop.fs.s3a.path.style.access` | `true`                                         | **Vital for MinIO**. Forces `host/bucket` URL format instead of AWS `bucket.host`. |
| `spark.hadoop.fs.s3a.endpoint`          | `http://minio.big-data.svc.cluster.local:9000` | Points to our internal MinIO service.                                              |
| `spark.eventLog.dir`                    | `s3a://spark-logs/`                            | Where "History" files are written.                                                 |

### Kubernetes Settings
| Config Key                         | Value           | Explanation                                           |
| :--------------------------------- | :-------------- | :---------------------------------------------------- |
| `spark.kubernetes.container.image` | `docker.io/...` | The base image. Must contain Spark + Hadoop AWS JARs. |
| `spark.kubernetes.namespace`       | `big-data`      | Namespace for executors.                              |
| `spark.ui.prometheus.enabled`      | `true`          | Exposes metrics for Grafana.                          |

---

## 3. Pod Templates: The "Sidecar" Injector

We use **Pod Templates** (`kubernetes/interpreter-template.yaml`) to "patch" Spark pods at runtime.
*   **Why?**: Spark's native submit flags don't support everything (like sidecars or fancy volume mounts).
*   **Our Use Case**: We do not currently use complex sidecars for Spark, but the template structure is in place for mounting specific ConfigMaps or Secrets if needed in the future.

---

## 4. Troubleshooting

| Error                                | Root Cause                | Solution                                                                   |
| :----------------------------------- | :------------------------ | :------------------------------------------------------------------------- |
| **`Pending`** (Indefinitely)         | Cluster full.             | Run `kubectl top nodes`. Add nodes or reduce executor count.               |
| **`Class not found: S3AFileSystem`** | Missing JARs.             | Ensure you are using the correct Docker image with `hadoop-aws` shaded in. |
| **`403 Forbidden` (S3)**             | Bad Keys.                 | Check `AWS_ACCESS_KEY` env vars in the Driver.                             |
| **`Connection Refused` on Driver**   | Headless Service missing. | Ensure the Operator created a service named `spark-app-driver-svc`.        |

---

[⬅ Back to README](../README.md)
