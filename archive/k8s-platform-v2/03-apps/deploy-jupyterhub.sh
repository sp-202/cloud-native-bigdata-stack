#!/bin/bash
# =============================================================================
# Deploy JupyterHub with Interactive Spark Support
# =============================================================================
# This script deploys JupyterHub with all necessary configurations for:
# - Interactive PySpark notebooks
# - SQL magic cells (%%sql)
# - MinIO S3 storage integration
# - Spark on Kubernetes with dynamic executor scaling
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "=============================================="
echo "🚀 Deploying JupyterHub with Interactive Spark"
echo "=============================================="

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi

# Default Spark image if not set
SPARK_IMAGE="${SPARK_IMAGE:-subhodeep2022/spark-bigdata:spark-3.5.3-uc-0.3.1-v3}"

# Create ConfigMap for Spark defaults (reuse existing)
if [ -f "$SCRIPT_DIR/configs/spark-defaults.conf" ]; then
    echo "📦 Creating/Updating ConfigMap 'spark-config'..."
    kubectl create configmap spark-config \
        --from-file=spark-defaults.conf="$SCRIPT_DIR/configs/spark-defaults.conf" \
        -n default --dry-run=client -o yaml | kubectl apply -f -
fi

# Apply the deployment with variable substitution
echo "📦 Applying JupyterHub deployment..."
sed -e "s|\${SPARK_IMAGE}|$SPARK_IMAGE|g" \
    -e "s|\${SPARK_DRIVER_HOST}|\$(hostname -i)|g" \
    "$SCRIPT_DIR/jupyterhub.yaml" | kubectl apply -f -

# Restart to pick up changes
echo "🔄 Restarting JupyterHub deployment..."
kubectl rollout restart deployment/jupyterhub -n default 2>/dev/null || true

# Wait for rollout
echo "⏳ Waiting for deployment to complete..."
kubectl rollout status deployment/jupyterhub -n default --timeout=180s

# Get the new pod name
echo "🔍 Getting pod details..."
POD_NAME=$(kubectl get pods -n default -l app=jupyterhub -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "pending")
echo "   Pod: $POD_NAME"

# Wait for pod to be ready
if [ "$POD_NAME" != "pending" ]; then
    echo "⏳ Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/$POD_NAME -n default --timeout=180s
fi

echo ""
echo "=============================================="
echo "✅ JupyterHub Deployment Complete!"
echo "=============================================="
echo ""
echo "📋 Summary:"
echo "   Spark Image: ${SPARK_IMAGE}"
echo "   Pod:         $POD_NAME"
echo ""
echo "🌐 Access JupyterHub:"
echo "   kubectl port-forward svc/jupyterhub 8888:8888 -n default"
echo "   Open: http://localhost:8888"
echo ""
echo "📊 Access Spark UI (when running a job):"
echo "   kubectl port-forward svc/jupyterhub 4040:4040 -n default"
echo "   Open: http://localhost:4040"
echo ""
echo "📝 Quick Start - Run this in first cell:"
echo '   from pyspark.sql import SparkSession'
echo '   spark = SparkSession.builder.appName("notebook").getOrCreate()'
echo '   spark.range(10).show()'
echo ""
