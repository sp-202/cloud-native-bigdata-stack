#!/bin/bash
set -e

# Image Tags
HIVE_IMAGE="subhodeep2022/spark-bigdata:hive-3.1.3-custom"
SPARK_IMAGE="subhodeep2022/spark-bigdata:spark-3.5.7-fixed-v2"

echo "=============================================="
echo "Building and Pushing Custom Images"
echo "=============================================="

# 1. Build Hive Image
if [ -f "./hive/Dockerfile" ]; then
    echo "[Hive] Building $HIVE_IMAGE..."
    sudo docker build -t $HIVE_IMAGE -f hive/Dockerfile .
    echo "[Hive] Pushing $HIVE_IMAGE..."
    sudo docker push $HIVE_IMAGE
else
    echo "[Hive] Warning: hive/Dockerfile not found. Skipping."
fi

# 2. Build Spark Image
if [ -f "./spark/Dockerfile" ]; then
    echo "[Spark] Building $SPARK_IMAGE..."
    # Configs are inside spark/ directory, so we set that as context
    sudo docker build -t $SPARK_IMAGE spark/
    echo "[Spark] Pushing $SPARK_IMAGE..."
    sudo docker push $SPARK_IMAGE
else
    echo "[Spark] Warning: spark/Dockerfile not found. Skipping."
fi

echo "=============================================="
echo "All images processed."
echo "=============================================="
