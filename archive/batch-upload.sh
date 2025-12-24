#!/bin/bash

# Batch upload script - uploads files in smaller groups for reliability
# Target: test-bucket/taxi-data/ folder

echo "Starting batch upload to test-bucket/taxi-data/..."

# Upload 2018 data (12 files, ~1.4 GB)
echo "[1/6] Uploading 2018 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2018-*.parquet myminio/test-bucket/taxi-data/"

echo "[2/6] Uploading 2019 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2019-*.parquet myminio/test-bucket/taxi-data/"

echo "[3/6] Uploading 2020 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2020-*.parquet myminio/test-bucket/taxi-data/"

echo "[4/6] Uploading 2021 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2021-*.parquet myminio/test-bucket/taxi-data/"

echo "[5/6] Uploading 2022 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2022-*.parquet myminio/test-bucket/taxi-data/"

# Note: 2023 and 2024 files are already in test-bucket root, will move them later
echo "[6/6] Uploading 2023-2024 data..."
sudo docker run --rm --network databricks-net -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc cp /data/yellow_tripdata_2023-*.parquet myminio/test-bucket/taxi-data/ && mc cp /data/yellow_tripdata_2024-*.parquet myminio/test-bucket/taxi-data/"

echo ""
echo "Upload complete! Verifying..."
sudo docker run --rm --network databricks-net --entrypoint= minio/mc sh -c \
  "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>&1 >/dev/null && mc ls myminio/test-bucket/taxi-data/ | wc -l"
