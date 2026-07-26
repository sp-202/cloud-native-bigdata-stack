#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$0")"

# Load environment variables from local .env.spark file
ENV_FILE=".env.spark"
if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "⚠️  Warning: $ENV_FILE not found, using default values"
    SPARK_VERSION="3.5.8"
    SPARK_IMAGE_VERSION="v11-iceberg-gravitino"
fi

# Construct image name from environment variables
IMAGE_NAME="subhodeep2022/spark-bigdata:spark-${SPARK_VERSION}-${SPARK_IMAGE_VERSION}"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "Building Spark image from directory: $(pwd)"
echo "Spark Version: $SPARK_VERSION"
echo "Gravitino Version: $GRAVITINO_VERSION"
echo "Image Tag: $IMAGE_NAME"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# Dockerfile expects the base Spark tarball in this directory
COMET_TARBALL="spark-3.5.8-comet-v1.tar.gz"
if [ ! -f "$COMET_TARBALL" ]; then
    echo "📥 $COMET_TARBALL not found locally, pulling from S3..."
    aws s3 cp s3://spark-3.5.8-scala-2.13-custom/spark-arm64/spark-3.5.8-comet-v1.tar.gz "$COMET_TARBALL"
fi

# Dockerfile also expects the Comet acceleration jar in this directory (separate from the tarball above)
COMET_JAR="comet-spark-spark3.5_2.13-0.17.0-SNAPSHOT.jar"
if [ ! -f "$COMET_JAR" ]; then
    echo "📥 $COMET_JAR not found locally, pulling from S3..."
    aws s3 cp s3://spark-3.5.8-scala-2.13-custom/comet-arm/comet-spark-spark3.5_2.13-0.17.0-SNAPSHOT.jar "$COMET_JAR"
fi

echo "🔨 Building Docker image: $IMAGE_NAME (Platform: linux/arm64)"
# arm64 only — the Comet-accelerated Spark build is arm64-only
docker buildx build --platform linux/arm64 -t $IMAGE_NAME -f $DOCKERFILE_PATH --push .

echo "✅ Build and Push Complete: $IMAGE_NAME"
