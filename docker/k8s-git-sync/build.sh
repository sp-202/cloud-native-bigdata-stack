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
    SPARK_VERSION="4.0.1"
    UNITY_CATALOG_VERSION="0.3.1"
    SPARK_IMAGE_VERSION="v4"
fi

# Image name as requested
IMAGE_NAME="subhodeep2022/k8s-git-sync:v2"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building k8s-git-sync image (Optimized)"
echo "Target Image: $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

echo "🔨 Building Multi-Arch Docker image: $IMAGE_NAME (Platforms: linux/amd64, linux/arm64)"
# Use buildx for multi-arch support
docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGE_NAME -f $DOCKERFILE_PATH --push .

echo "✅ Build and Push Complete: $IMAGE_NAME"
