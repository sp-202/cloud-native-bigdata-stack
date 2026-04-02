#!/bin/bash
set -e
echo "Creating databases for Hive and Airflow..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER hive WITH PASSWORD 'hive';
    CREATE DATABASE metastore OWNER hive;
    CREATE USER airflow WITH PASSWORD 'airflow';
    CREATE DATABASE airflow OWNER airflow;
    CREATE USER superset WITH PASSWORD 'superset';
    CREATE DATABASE superset OWNER superset;
    GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;
    GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
    GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOSQL
echo "Databases created."
