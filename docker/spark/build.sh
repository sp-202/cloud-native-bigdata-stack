#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$0")"

IMAGE_NAME="subhodeep2022/spark-bigdata:spark-4.0.1-uc-0.3.1-v4"
DOCKERFILE_PATH="Dockerfile"

echo "Building Spark image from directory: $(pwd)"
echo "Using Dockerfile: $DOCKERFILE_PATH"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

echo "Building Docker image: $IMAGE_NAME (Platform: linux/amd64)"
docker build --platform linux/amd64 -t $IMAGE_NAME -f $DOCKERFILE_PATH .

echo "Pushing Docker image: $IMAGE_NAME"
# Note: User must be logged in (docker login)
docker push $IMAGE_NAME

echo "Build and Push Complete!"
