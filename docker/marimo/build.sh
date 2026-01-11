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
fi

IMAGE_NAME="subhodeep2022/spark-bigdata:marimo-v1"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Marimo image: $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running."
  exit 1
fi

echo "🔨 Building Docker image: $IMAGE_NAME"
docker build --platform linux/amd64 -t $IMAGE_NAME -f $DOCKERFILE_PATH .

echo "📤 Pushing Docker image: $IMAGE_NAME"
docker push $IMAGE_NAME

echo "✅ Build and Push Complete: $IMAGE_NAME"
