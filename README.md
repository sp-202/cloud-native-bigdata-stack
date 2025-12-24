# Modern Data Engineering Pipeline Infrastructure

This repository hosts a comprehensive, containerized data engineering infrastructure designed to facilitate robust data processing, orchestration, and visualization workflows. It leverages industry-standard open-source technologies to create a scalable and reproducible local development environment.

## Architecture Overview

The pipeline integrates the following core components:

*   **Apache Spark**: A unified analytics engine for large-scale data processing.
*   **Delta Lake**: An open-source storage layer that brings reliability to data lakes.
*   **Apache Airflow**: A platform to programmatically author, schedule, and monitor workflows.
*   **Apache Superset**: A modern data exploration and visualization platform.
*   **Apache Zeppelin**: A web-based notebook that enables data-driven, interactive data analytics.
*   **MinIO**: High-performance, S3-compatible object storage.
*   **Hive Metastore**: A central repository for metadata storage.

## Service Configuration & Port Mapping

The infrastructure exposes the following services and ports for interaction:

| Service | Description | URL / Endpoint | Credentials |
| :--- | :--- | :--- | :--- |
| **Spark Master** | Cluster management UI | `http://localhost:8080` | - |
| **Spark Worker** | Worker node UI | `http://localhost:8081` | - |
| **Spark UI** | Job monitoring (active jobs) | `http://localhost:4040` | - |
| **MinIO Console** | Object storage management | `http://localhost:9001` | `minioadmin` / `minioadmin` |
| **MinIO API** | S3-compatible API endpoint | `http://localhost:9000` | `minioadmin` / `minioadmin` |
| **Airflow UI** | Workflow orchestration | `http://localhost:8083` | `admin` / `admin` |
| **Zeppelin** | Interactive notebooks | `http://localhost:8082` | - |
| **Superset** | Data visualization | `http://localhost:8088` | `admin` / `admin` |
| **Code Server** | Browser-based IDE | `http://localhost:8084` | Password: `admin` |
| **Hive Metastore** | Metadata service (Thrift) | `localhost:9083` | - |

## Getting Started

Follow these steps to initialize and run the pipeline infrastructure.

### Prerequisites

*   **Docker Engine** (v20.10+)
*   **Docker Compose** (v1.29+)
*   **Git**
*   **Hardware**: Minimum 8GB RAM (16GB recommended) allocated to Docker.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone <repository-url>
    cd spark-delta-lake
    ```

2.  **Initialize Submodules**
    This project includes Apache Superset as a submodule. Initialize it to ensure all dependencies are present.
    ```bash
    git submodule update --init --recursive
    ```

3.  **Launch the Infrastructure**
    Start the core services using Docker Compose.
    ```bash
    docker-compose up -d
    ```

4.  **Initialize Superset (First Run Only)**
    If this is your first time running the stack, you must initialize Superset.
    ```bash
    cd superset
    docker-compose -f docker-compose-non-dev.yml up -d
    # Note: Superset initialization may take several minutes.
    ```

## Usage Guide

### Workflow Orchestration with Airflow
*   Access the Airflow UI at `http://localhost:8083`.
*   DAGs are located in the `airflow/dags/` directory.
*   You can edit DAGs directly using the integrated Code Server at `http://localhost:8084`.

### Interactive Analytics with Zeppelin
*   Access Zeppelin at `http://localhost:8082`.
*   Spark is pre-configured. You can run Spark SQL or PySpark code directly in notebooks.
*   The environment includes Delta Lake support out-of-the-box.

### Data Visualization with Superset
*   Access Superset at `http://localhost:8088`.
*   Connect to the Hive Metastore or other data sources to visualize your datasets.
*   Refer to `SUPERSET_CONNECTION_GUIDE.md` for detailed connection instructions.

## Network Architecture

All services communicate over a dedicated Docker bridge network (`databricks-net`), ensuring secure and isolated inter-service communication. Service discovery is enabled via container hostnames (e.g., `spark-master`, `minio`, `hive-metastore`).

## Contributing

Contributions are welcome. Please fork the repository and submit a pull request for any enhancements or bug fixes. Ensure that all changes are tested against the local environment.



## Docker Images & Configuration

For production and Kubernetes deployment, we use custom Docker images that bake in necessary configurations and dependencies.

### Spark Image (`subhodeep2022/spark-bigdata:spark-3.5.7`)
- **Base**: `spark/Dockerfile`
- **Included Config**: `conf/spark-defaults.conf` (pre-configured for MinIO/S3, Hive Metastore, and Delta Lake).
- **Included Jars**: AWS SDK, Hadoop AWS, Postgres, Delta Lake (in `/opt/spark/jars` and `/opt/spark/custom-jars`).
- **Runtime Overrides**:
  - **Kubernetes ConfigMap**: Mount your own `spark-defaults.conf` to `/opt/spark/conf/spark-defaults.conf`.
  - **Environment Variables**:
    - `SPARK_MASTER_URL`: URL of the Spark Master.
    - `SPARK_MODE`: `master` or `worker`.
    - `SPARK_RPC_AUTHENTICATION_ENABLED`: Default `no`. Set to `yes` if needed (requires keys).
    - `SPARK_WORKER_MEMORY` / `SPARK_WORKER_CORES`: Resource limits.

### Zeppelin Image (`subhodeep2022/spark-bigdata:zeppelin-0.12.0`)
- **Base**: `zeppelin/Dockerfile` (builds on `apache/zeppelin:0.12.0`).
- **Included**: Spark 3.5.7 client, same Jars as Spark image, and same `spark-defaults.conf`.
- **Runtime Overrides**:
  - **Spark Connection**: Set `SPARK_MASTER` env var (e.g., `spark://spark-master:7077`).
  - **Configuration**:
    - `ZEPPELIN_ADDR`: Default `0.0.0.0`.
    - `ZEPPELIN_SPARK_ENABLESUPPORTEDVERSIONCHECK`: Default `false` (required for newer Spark versions).
    - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: Credentials for MinIO/S3 access.

### Building the Images
To build and push the images:
```bash
# Build Spark
docker build -t subhodeep2022/spark-bigdata:spark-3.5.7 ./spark
docker push subhodeep2022/spark-bigdata:spark-3.5.7

# Build Zeppelin (from project root)
docker build -f zeppelin/Dockerfile -t subhodeep2022/spark-bigdata:zeppelin-0.12.0 .
docker push subhodeep2022/spark-bigdata:zeppelin-0.12.0
```
