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
    ZEPPELIN_VERSION="0.12.0"
    ZEPPELIN_IMAGE_VERSION="v6"
fi

# Construct image name from environment variables
IMAGE_NAME="subhodeep2022/spark-bigdata:zeppelin-${ZEPPELIN_VERSION}-java17-${ZEPPELIN_IMAGE_VERSION}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Zeppelin image from directory: $(pwd)"
echo "Zeppelin Version: $ZEPPELIN_VERSION"
echo "Image Tag: $IMAGE_NAME"
echo "=============================================="

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# Build the image
echo "🔨 Building Docker image: $IMAGE_NAME (Platform: linux/amd64)"
docker build --platform linux/amd64 -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .

if [ $? -eq 0 ]; then
    echo "✅ Build successful: $IMAGE_NAME"
else
    echo "❌ Build failed"
    exit 1
fi

echo "📤 Pushing Docker image: $IMAGE_NAME"
# Note: User must be logged in (docker login)
docker push $IMAGE_NAME

echo "✅ Build and Push Complete: $IMAGE_NAME"