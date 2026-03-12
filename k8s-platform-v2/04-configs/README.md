# ⚙️ 04-Configs: Shared Configurations

This directory centralizes configuration files that are used by **multiple** applications. Instead of duplicating configs across Spark, Hive, and notebook folders, we define them here once and use Kustomize to inject them.

## 📄 Key Files

### 1. `global-config.env`
*   **Purpose**: The single source of truth for platform-wide variables.
*   **Key Variables**:
    *   `INGRESS_DOMAIN`: The base domain for all IngressRoutes (e.g., `44.203.26.241.sslip.io`).
    *   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: MinIO credentials.
    *   `MINIO_ENDPOINT`: The internal MinIO service URL.

### 2. `ingress.yaml`
*   **Purpose**: A ConfigMap holding the global `INGRESS_DOMAIN` variable.
*   **Usage**: The deployment script updates this with the dynamic LoadBalancer IP. All Ingress routes reference this ConfigMap to build their URLs.

### 3. `spark-defaults.yaml` / Spark Configs
*   **Purpose**: Spark configuration shared across JupyterHub, Spark Connect Server, and Spark Operator jobs.
*   **Key Settings**:
    *   S3A connection parameters (endpoint, path-style access, credentials).
    *   Delta Lake catalog configuration.
    *   Timeout values (integers only, to avoid `NumberFormatException`).
