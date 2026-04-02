#!/bin/bash
# Wait for MinIO to be ready
echo "Waiting for MinIO..."
# Attempt to set alias until successful (serves as readiness check)
until /usr/bin/mc alias set myminio http://minio:9000 minioadmin minioadmin; do
  echo "MinIO not ready, retrying in 2s..."
  sleep 2
done

# Configure MC and Create Buckets
/usr/bin/mc mb myminio/warehouse;
/usr/bin/mc mb myminio/data;
/usr/bin/mc mb myminio/dags;
/usr/bin/mc mb myminio/notebooks;
/usr/bin/mc mb myminio/test-bucket;
/usr/bin/mc mb myminio/taxi-data;
/usr/bin/mc mb myminio/spark-logs;

# Set Public Policies
/usr/bin/mc policy set public myminio/warehouse;
/usr/bin/mc policy set public myminio/data;
/usr/bin/mc policy set public myminio/dags;
/usr/bin/mc policy set public myminio/notebooks;
/usr/bin/mc policy set public myminio/test-bucket;
/usr/bin/mc policy set public myminio/taxi-data;
/usr/bin/mc policy set public myminio/spark-logs;
# Create spark-events directory explicitly
echo "Creating spark-events directory..."
/usr/bin/mc pipe myminio/spark-logs/spark-events/.keep < /dev/null
echo "Buckets created."
exit 0
