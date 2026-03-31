#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$0")"

# Load environment variables from local .env.marimo file
ENV_FILE=".env.marimo"
if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "⚠️  Warning: $ENV_FILE not found, using default values"
    MARIMO_IMAGE_VERSION="v1"
fi

# Construct image name from environment variables
IMAGE_NAME="subhodeep2022/spark-bigdata:marimo-${MARIMO_IMAGE_VERSION}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Marimo image: $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running."
  exit 1
fi

echo "🔨 Building Multi-Arch Docker image: $IMAGE_NAME (Platforms: linux/amd64, linux/arm64)"
# Use buildx for multi-arch support
docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGE_NAME -f $DOCKERFILE_PATH --push .

echo "✅ Build and Push Complete: $IMAGE_NAME"
