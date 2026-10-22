#!/bin/bash
set -euo pipefail

# Navigate to the directory containing this script
cd "$(dirname "$0")"

# Load environment variables from local .env.spark file
ENV_FILE=".env.spark"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ $ENV_FILE not found" >&2
    exit 1
fi
echo "📦 Loading configuration from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

PLATFORMS="${SPARK_PLATFORMS:-linux/amd64}"
IMAGE_NAME="subhodeep2022/spark-bigdata:spark-${SPARK_VERSION}-${SPARK_IMAGE_VERSION}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Spark image from directory: $(pwd)"
echo "Spark Version:     $SPARK_VERSION"
echo "Gravitino Version: $GRAVITINO_VERSION"
echo "Platforms:         $PLATFORMS"
echo "Image Tag:         $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

echo "🔨 Building Docker image: $IMAGE_NAME"
docker buildx build --platform "$PLATFORMS" -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" --push .

echo "✅ Build and Push Complete: $IMAGE_NAME"
