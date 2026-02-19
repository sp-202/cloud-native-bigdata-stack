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

# Define custom image name
# Repo: subhodeep2022/spark-bigdata
# Tag: jupyterhub-<jupyter_version>-pyspark-scala-sql-<vN>
JUPYTER_VERSION_TAG="4.0.7"
VERSION_TAG="v2"
JUPYTERHUB_CUSTOM_IMAGE="subhodeep2022/spark-bigdata:jupyterhub-${JUPYTER_VERSION_TAG}-pyspark-scala-sql-${VERSION_TAG}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Custom JupyterHub image"
echo "Base Image: jupyter/pyspark-notebook:spark-3.5.0"
echo "Target Image: $JUPYTERHUB_CUSTOM_IMAGE"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

echo "🔨 Building Multi-Arch Docker image: $JUPYTERHUB_CUSTOM_IMAGE (Platforms: linux/amd64, linux/arm64)"
# Use buildx for multi-arch support
docker buildx build --platform linux/amd64,linux/arm64 -t $JUPYTERHUB_CUSTOM_IMAGE -f $DOCKERFILE_PATH --push .

echo "✅ Build and Push Complete: $JUPYTERHUB_CUSTOM_IMAGE"
echo ""
echo "Next step: Update .env with JUPYTERHUB_IMAGE=$JUPYTERHUB_CUSTOM_IMAGE"
