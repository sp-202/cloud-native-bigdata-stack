# Data Engineering Pipeline Infrastructure

This repository provides a comprehensive, Docker-based infrastructure for a modern data engineering pipeline. It integrates best-in-class open-source tools for data processing, orchestration, storage, and visualization.

## Overview

The pipeline is designed to support end-to-end data engineering workflows, from data ingestion and processing to analysis and visualization. It uses Docker Compose to orchestrate the services, making it easy to spin up a local development environment.

## Services & Architecture

The following services are included in this setup:

| Service | Description | Port (Host) | Internal Port |
|---------|-------------|-------------|---------------|
| **Spark Master** | Apache Spark Master node for cluster management | `8080` (Web UI), `7077` | `8080`, `7077` |
| **Spark Worker** | Apache Spark Worker node for executing tasks | `8081` (Web UI) | `8081` |
| **Minio** | High-performance, S3-compatible object storage | `9000` (API), `9001` (Console) | `9000`, `9001` |
| **Hive Metastore** | Central repository of metadata for Hive tables | `9083` | `9083` |
| **Airflow Webserver** | Workflow orchestration and scheduling UI | `8083` | `8080` |
| **Zeppelin** | Web-based notebook for interactive data analytics | `8082` | `8080` |
| **Superset** | Modern data exploration and visualization platform | `8088` | `8088` |

### Additional Components
- **PostgreSQL**: Used as the backend database for Hive Metastore, Airflow, and Superset.
- **Redis**: Used as a caching layer and message broker for Superset.

## Use Cases

This infrastructure supports a wide range of data engineering and data science use cases:

1.  **Distributed Data Processing**: Submit and execute distributed data processing jobs using Apache Spark.
2.  **Data Lake Management**: Store unstructured and structured data in Minio, simulating a cloud-native S3 data lake.
3.  **Metadata Management**: Define and manage schemas and tables using Hive Metastore, enabling SQL-based access to data in the lake.
4.  **Workflow Orchestration**: Define, schedule, and monitor complex data pipelines and workflows using Apache Airflow.
5.  **Interactive Analysis**: Perform exploratory data analysis (EDA) and run Spark code interactively using Zeppelin notebooks.
6.  **Business Intelligence & Visualization**: Connect to your data sources and create interactive dashboards and charts using Apache Superset.

## Getting Started

### Prerequisites
- Docker
- Docker Compose

### Installation & Running

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Start the Core Pipeline Services:**
    This command starts Spark, Hive, Minio, Airflow, and Zeppelin.
    ```bash
    docker-compose up -d
    ```

3.  **Start Superset:**
    Superset is defined in a separate compose file to keep the setup modular.
    ```bash
    docker-compose -f docker-compose-superset.yml up -d
    ```

4.  **Access the Services:**
    - **Minio Console**: [http://localhost:9001](http://localhost:9001) (User/Pass: `minioadmin` / `minioadmin`)
    - **Spark Master UI**: [http://localhost:8080](http://localhost:8080)
    - **Airflow UI**: [http://localhost:8083](http://localhost:8083) (User/Pass: `admin` / `admin`)
    - **Zeppelin**: [http://localhost:8082](http://localhost:8082)
    - **Superset**: [http://localhost:8088](http://localhost:8088) (User/Pass: `admin` / `admin`)

## Configuration

- **Spark**: Configuration files are located in `./spark/conf`.
- **Hive**: Configuration files are located in `./hive/conf`.
- **Airflow**: DAGs should be placed in `./airflow/dags`.
- **Data**: Persistent data is stored in the `./data` directory.

## Notes
- The network `databricks-net` is used to connect all services.
- Ensure you have sufficient memory allocated to Docker, as running all services simultaneously requires significant resources.
