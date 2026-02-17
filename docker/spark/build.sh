#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$0")"

# Load environment variables from .env file
ENV_FILE="../../.env"
if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "⚠️  Warning: $ENV_FILE not found, using default values"
    SPARK_VERSION="4.1.1"
    UNITY_CATALOG_VERSION="0.3.1"
    SPARK_IMAGE_VERSION="v4"
fi

# Construct image name from environment variables
IMAGE_NAME="subhodeep2022/spark-bigdata:spark-${SPARK_VERSION}-uc-${UNITY_CATALOG_VERSION}-${SPARK_IMAGE_VERSION}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Spark image from directory: $(pwd)"
echo "Spark Version: $SPARK_VERSION"
echo "Unity Catalog Version: $UNITY_CATALOG_VERSION"
echo "Image Tag: $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

echo "🔨 Building Docker image: $IMAGE_NAME (Platform: linux/amd64)"
docker build --platform linux/amd64 -t $IMAGE_NAME -f $DOCKERFILE_PATH .

echo "📤 Pushing Docker image: $IMAGE_NAME"
# Note: User must be logged in (docker login)
docker push $IMAGE_NAME

echo "✅ Build and Push Complete: $IMAGE_NAME"
