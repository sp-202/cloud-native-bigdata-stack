# ⚡ Spark on Kubernetes: Deep Dive

This platform uses the **Spark on Kubernetes Operator** to manage the lifecycle of Spark applications, providing a truly cloud-native distributed compute experience.

## 🏗 Architecture
Our setup distinguishes between two primary execution modes:

### 1. Interactive Mode (Client Mode)
Used by **JupyterHub**, **Marimo**, and **Polynote**.
- **Driver**: Runs inside the notebook pod.
- **Executors**: Automatically spawned as temporary pods by the Spark Kubernetes backend.
- **Configuration**: Managed dynamically at startup via `setup-kernels.sh`, which detects the Driver's IP and injects it into `spark.driver.host`.

### 2. Batch Mode (Cluster Mode)
Used by **Airflow**.
- **Driver**: Runs in its own dedicated pod, managed by the Spark Operator.
- **Executors**: Spawned after the Driver starts.
- **Submission**: Controlled via `SparkApplication` Custom Resources.

---

## ⚙️ Key Configurations

| Property | Description |
| :--- | :--- |
| `spark.master` | `k8s://https://kubernetes.default.svc` |
| `spark.kubernetes.container.image` | The "Golden Stack" image containing your libraries. |
| `spark.kubernetes.namespace` | Set to `default` (standard for our platform). |
| `spark.driver.host` | **CRITICAL**: The IP of the driver pod, used by executors to connect back. |
| `spark.kubernetes.authenticate.driver.serviceAccountName` | `jupyterhub` (has permissions to create pods). |

---

## 📦 Python Version Alignment
A common pitfall in Spark-on-K8s is the "Python Version Mismatch" error.
- **Driver**: Must use the same Python minor version (e.g., 3.11) as the **Executor**.
- **Platform Fix**: We use a unified Docker image (`spark-bigdata`) for both the driver and the executors, ensuring `python3.11` is used across the entire cluster.

## 💾 S3/MinIO Integration (S3a)
Instead of local HDFS, we use the `s3a` connector:
- **Endpoint**: `http://minio.default.svc.cluster.local:9000`
- **Implementation**: `org.apache.hadoop.fs.s3a.S3AFileSystem`
- **Path Style**: `spark.hadoop.fs.s3a.path.style.access = true` (required for MinIO).

---

## 🛠 Troubleshooting common K8s issues

| Error | Root Cause | Solution |
| :--- | :--- | :--- |
| **`Pending`** pods | Cluster/Node full. | Increase node count or reduce executor memory/CPU. |
| **`ImagePullBackOff`** | Incorrect image tag. | Verify the image exists in DockerHub and matches your `.env`. |
| **`Python mismatch`** | Driver/Executor version gap. | Use the unified "Golden Stack" image for all components. |
| **`403 Forbidden`** | Bad S3 keys or IAM. | Check MinIO credentials in the Driver environment. |
| **`Class not found`** | Missing JARs in image. | Ensure your image was built with the required Spark/Hadoop JARs. |
