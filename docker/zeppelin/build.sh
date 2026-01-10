#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$0")"

IMAGE_NAME="subhodeep2022/spark-bigdata:zeppelin-0.12.0-java17-v5"
DOCKERFILE_PATH="Dockerfile"

echo "Building Zeppelin image from directory: $(pwd)"
echo "Image Name: $IMAGE_NAME"
echo ""

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# Build the image
echo "🔨 Building Docker image..."
docker build --platform linux/amd64 -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .

if [ $? -eq 0 ]; then
    echo "✅ Build successful: $IMAGE_NAME"
else
    echo "❌ Build failed"
    exit 1
fi

echo "Pushing Docker image: $IMAGE_NAME"
# Note: User must be logged in (docker login)
docker push $IMAGE_NAME

echo "Build and Push Complete!"