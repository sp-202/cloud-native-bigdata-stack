#!/bin/bash
set -e

IMAGE_NAME="subhodeep2022/spark-bigdata:spark-3.5.7-rocksdb"

echo "Building Spark Docker Image: $IMAGE_NAME"
docker build -t $IMAGE_NAME -f docker/spark/Dockerfile .

echo "Pushing Image to Docker Hub..."
docker push $IMAGE_NAME

echo "Build and Push Complete!"
