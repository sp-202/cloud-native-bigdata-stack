# ⚡ Apache Spark on Kubernetes - Detailed Guide

## 1. Architecture
We use the **Kubeflow Spark Operator** to manage Spark Applications in a cloud-native way.
*   **Submission**: You submit a YAML CRD (`SparkApplication`) or use Zeppelin/Airflow which acts as the generic submission client.
*   **Execution**: The Operator spawns a **Driver Pod**, which then requests **Executor Pods**.
*   **Networking**: Driver and Executors communicate via Headless Services.

## 2. Configuration (`kubernetes/spark-defaults.conf`)
This file is mounted into every Spark container. Here is what every config does:

| Configuration | Value | Effect / "Why?" |
| :--- | :--- | :--- |
| `spark.master` | `k8s://https://kubernetes.default.svc` | Tells Spark to talk to the K8s API Server |
| `spark.submit.deployMode` | `cluster` | Driver runs inside the cluster (not on your laptop) |
| `spark.kubernetes.container.image` | `subhodeep2022/spark-bigdata...` | The Docker image containing Spark binaries |
| `spark.eventLog.enabled` | `true` | **Critical**: Enables history. Without this, you lose logs after pod deletion. |
| `spark.eventLog.dir` | `s3a://spark-logs/spark-events` | Writes event logs to MinIO. allows History Server to replay them. |
| `spark.hadoop.fs.s3a.impl` | `org.apache.hadoop.fs.s3a.S3AFileSystem` | Uses the AWS SDK for S3 access (required for MinIO) |
| `spark.hadoop.fs.s3a.path.style.access` | `true` | **Required for MinIO**. Forces URLs like `server/bucket` instead of `bucket.server` |
| `spark.ui.prometheus.enabled` | `true` | Exposes `/metrics/prometheus` endpoint for Grafana |

## 3. Pod Templates (`kubernetes/interpreter-template.yaml`)
These YAML templates control the **shape** of the Spark pods.
*   **Why use templates?**: To inject "non-Spark" things like Sidecars, Persistent Volumes, or Node Selectors.
*   **Current Usage**: We use it to mount the `spark-defaults.conf` ConfigMap so we don't have to rebuild the Docker image for config changes.

## 4. Troubleshooting
*   **"Class Not Found: S3AFileSystem"**: You represent missing JARs (`hadoop-aws`, `aws-java-sdk`). Our image includes these.
*   **"403 Forbidden" on S3**: Check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` env vars in `zeppelin.yaml`.
*   **"Driver Pod stuck in Pending"**: Cluster is out of RAM. Check `kubectl top nodes`.
