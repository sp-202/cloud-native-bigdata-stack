# Data Engineering Pipeline Infrastructure

This repository provides a comprehensive, Docker-based infrastructure for a modern data engineering pipeline. It integrates best-in-class open-source tools for data processing, orchestration, storage, and visualization.

## Overview

The pipeline is designed to support end-to-end data engineering workflows, from data ingestion and processing to analysis and visualization. It uses Docker Compose to orchestrate the services, making it easy to spin up a local development environment.

## Services & Architecture

The following services are included in this setup:

| Service | Description | URL | Credentials |
|---------|-------------|-----|-------------|
| **Spark Master** | Apache Spark Master node for cluster management | http://localhost:8080 | - |
| **Spark Worker** | Apache Spark Worker node for executing tasks | http://localhost:8081 | - |
| **Spark UI** | Spark job monitoring (when jobs are running) | http://localhost:4040 | - |
| **MinIO** | High-performance, S3-compatible object storage | http://localhost:9001 | minioadmin / minioadmin |
| **Hive Metastore** | Central repository of metadata for Hive tables | Port 9083 (Thrift) | - |
| **Airflow** | Workflow orchestration and scheduling | http://localhost:8083 | admin / admin |
| **Zeppelin** | Web-based notebook for interactive Spark analytics | http://localhost:8082 | - |
| **Superset** | Modern data exploration and visualization platform | http://localhost:8088 | admin / admin |
| **Code Server** | VS Code in the browser for editing DAG files | http://localhost:8084 | Password: admin |

### Additional Components
- **PostgreSQL (Hive Metastore)**: Backend database for Hive metadata
- **PostgreSQL (Airflow)**: Backend database for Airflow metadata
- **PostgreSQL (Superset)**: Backend database for Superset metadata
- **Redis**: Caching layer and message broker for Superset

## Use Cases

This infrastructure supports a wide range of data engineering and data science use cases:

1. **Distributed Data Processing**: Submit and execute distributed data processing jobs using Apache Spark
2. **Data Lake Management**: Store unstructured and structured data in MinIO, simulating a cloud-native S3 data lake
3. **Metadata Management**: Define and manage schemas and tables using Hive Metastore, enabling SQL-based access to data in the lake
4. **Workflow Orchestration**: Define, schedule, and monitor complex data pipelines and workflows using Apache Airflow
5. **Interactive Analysis**: Perform exploratory data analysis (EDA) and run Spark code interactively using Zeppelin notebooks
6. **Business Intelligence & Visualization**: Connect to your data sources and create interactive dashboards and charts using Apache Superset
7. **Web-Based Development**: Edit Airflow DAGs and Python scripts directly in the browser using Code Server

## Getting Started

### Prerequisites
- Docker
- Docker Compose
- At least 8GB RAM allocated to Docker

### Installation & Running

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd pipe-line
   ```

2. **Initialize Superset submodule:**
   ```bash
   git submodule update --init --recursive
   ```

3. **Start the Core Pipeline Services:**
   ```bash
   docker-compose up -d
   ```

4. **Start Superset:**
   ```bash
   cd superset
   docker-compose -f docker-compose-non-dev.yml up -d
   cd ..
   ```

5. **Access the Services:**
   - **MinIO Console**: http://localhost:9001 (minioadmin / minioadmin)
   - **Spark Master UI**: http://localhost:8080
   - **Spark Worker UI**: http://localhost:8081
   - **Airflow UI**: http://localhost:8083 (admin / admin)
   - **Zeppelin**: http://localhost:8082
   - **Superset**: http://localhost:8088 (admin / admin)
   - **Code Server**: http://localhost:8084 (Password: admin)

## Quick Start Guide

### 1. Writing Airflow DAGs

**Option A: Using Code Server (Web UI)**
1. Open http://localhost:8084 (Password: `admin`)
2. Navigate to `/home/coder/dags/`
3. Create a new Python file (e.g., `my_dag.py`)
4. Write your DAG code and save
5. DAG appears in Airflow UI within 30 seconds

**Option B: Using Local Editor**
1. Edit files in `./airflow/dags/` directory
2. Save and changes sync automatically

**Example DAG:**
```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def my_task():
    print("Hello from Airflow!")

with DAG('my_pipeline', start_date=datetime(2024, 1, 1), 
         schedule_interval='@daily', catchup=False) as dag:
    task = PythonOperator(task_id='hello', python_callable=my_task)
```

### 2. Running Spark Jobs in Zeppelin

1. Open http://localhost:8082
2. Create a new notebook
3. Write Spark SQL or PySpark code:
   ```python
   %pyspark
   df = spark.read.csv("s3a://data/myfile.csv", header=True)
   df.show()
   ```

### 3. Connecting Superset to Your Data

**Method 1: Via PostgreSQL (Recommended)**

1. In Zeppelin, write data to PostgreSQL:
   ```python
   df.write \
     .format("jdbc") \
     .option("url", "jdbc:postgresql://hive-metastore-postgresql:5432/metastore") \
     .option("dbtable", "public.my_table") \
     .option("user", "hive") \
     .option("password", "hive") \
     .option("driver", "org.postgresql.Driver") \
     .mode("overwrite") \
     .save()
   ```

2. In Superset, add database:
   - Host: `hive-metastore-postgresql`
   - Port: `5432`
   - Database: `metastore`
   - Username: `hive`
   - Password: `hive`

3. Query your data in SQL Lab:
   ```sql
   SELECT * FROM public.my_table LIMIT 100;
   ```

## Configuration

### Spark Configuration
- **Config files**: `./spark/conf/spark-defaults.conf`
- **Custom JARs**: `./spark/jars/` (PostgreSQL JDBC driver included)
- **Event logs**: `./data/spark-events/`

### Hive Configuration
- **Config files**: `./hive/conf/hive-site.xml`
- **Warehouse directory**: `/tmp/warehouse` (default)
- **S3 support**: Configured for MinIO

### Airflow Configuration
- **DAG folder**: `./airflow/dags/`
- **Logs**: `./data/airflow/logs/`
- **Plugins**: `./airflow/plugins/`

### MinIO Buckets
Pre-created buckets:
- `warehouse` - For Hive data
- `data` - For general data storage
- `test-bucket` - For testing

### Data Persistence
- `./data/` - All persistent data
- `./data/zeppelin/notebook/` - Zeppelin notebooks
- `./data/spark-events/` - Spark event logs

## Network Architecture

All services communicate via the `pipe-line_databricks-net` Docker network, enabling:
- Service discovery by container name
- Secure inter-service communication
- Isolated network environment

## Troubleshooting

### Services Not Starting
```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs <service-name>

# Restart specific service
docker-compose restart <service-name>
```

### Airflow DAG Not Appearing
- Wait 30 seconds for DAG refresh
- Check DAG syntax: `docker-compose exec airflow-webserver airflow dags list`
- View logs: `docker-compose logs airflow-scheduler`

### Superset Connection Issues
- Ensure Superset is on `pipe-line_databricks-net` network
- Use container names (e.g., `hive-metastore-postgresql`) not `localhost`
- Verify network: `docker network inspect pipe-line_databricks-net`

### Spark Job Failures
- Check Spark UI: http://localhost:4040 (when job is running)
- View driver logs in Zeppelin notebook
- Check worker logs: `docker-compose logs spark-worker`

## Resource Requirements

Recommended system resources:
- **CPU**: 4+ cores
- **RAM**: 16GB+ (8GB minimum)
- **Disk**: 20GB+ free space

## Notes

- All services use the `databricks-net` network for communication
- PostgreSQL JDBC driver is pre-installed in Spark for database connectivity
- Superset runs as a Git submodule - avoid modifying files in `./superset/`
- Code Server provides full VS Code experience in the browser

## Contributing

When contributing:
1. Create a new branch from `master`
2. Make your changes
3. Test all services
4. Submit a pull request

## License

[Your License Here]
