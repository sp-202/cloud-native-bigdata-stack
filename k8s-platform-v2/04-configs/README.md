# ⚙️ 04-Configs: Shared Configurations

This directory centralizes configuration files that are used by **multiple** applications. Instead of copying `core-site.xml` into Spark, Hive, and Zeppelin folders separately, we define it here once and use Kustomize to inject it.

## 📄 Key Files

### 1. `core-site.xml` (Hadoop Config)
*   **Purpose**: Defines how to talk to S3/MinIO.
*   **Used By**: Spark, Hive, Zeppelin.
*   **Critical Settings**:
    *   `fs.s3a.endpoint`: The MinIO URL.
    *   `fs.s3a.access.key`: Credentials.
    *   `fs.s3a.path.style.access`: "True" (Required for MinIO).

### 2. `hive-site.xml` (Metastore Config)
*   **Purpose**: Defines where the Metastore is.
*   **Used By**: Spark (to find Hive), Hive Server (to start up).
*   **Critical Settings**:
    *   `hive.metastore.uris`: `thrift://hive-metastore:9083`.

### 3. `ingress-domain.yaml`
*   **Purpose**: A ConfigMap holding the global variable `INGRESS_DOMAIN`.
*   **Usage**: The deployment script updates this file with the dynamic LoadBalancer IP. All Ingress routes reference this ConfigMap to build their URLs.
