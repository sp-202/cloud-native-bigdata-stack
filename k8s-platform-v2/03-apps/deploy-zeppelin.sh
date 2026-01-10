#!/bin/bash
# =============================================================================
# Deploy Zeppelin with Unity Catalog S3 Support
# =============================================================================
# This script deploys Zeppelin with all necessary configurations for:
# - Unity Catalog integration
# - MinIO S3 storage (with static credentials - no STS)
# - Spark 4.0.1 with AWS SDK v2
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "=============================================="
echo "🚀 Deploying Zeppelin with Unity Catalog S3"
echo "=============================================="

# Load environment variables (optional - for display purposes)
if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi

# Create ConfigMap for Spark defaults
if [ -f "$SCRIPT_DIR/configs/spark-defaults.conf" ]; then
    echo "📦 Creating ConfigMap 'spark-config'..."
    kubectl create configmap spark-config \
        --from-file=spark-defaults.conf="$SCRIPT_DIR/configs/spark-defaults.conf" \
        -n default --dry-run=client -o yaml | kubectl apply -f -
else
    echo "⚠️  Warning: spark-defaults.conf not found at $SCRIPT_DIR/configs/spark-defaults.conf"
fi

# Apply the deployment
echo "📦 Applying Kubernetes deployment..."
kubectl apply -f "$SCRIPT_DIR/zeppelin.yaml"

# Restart to pick up changes
echo "🔄 Restarting Zeppelin deployment..."
kubectl rollout restart deployment/zeppelin -n default

# Wait for rollout
echo "⏳ Waiting for deployment to complete..."
kubectl rollout status deployment/zeppelin -n default

# Get the new pod name
echo "🔍 Getting new pod details..."
POD_NAME=$(kubectl get pods -n default -l app=zeppelin -o jsonpath='{.items[0].metadata.name}')
echo "   Pod: $POD_NAME"

# Wait for pod to be ready
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/$POD_NAME -n default --timeout=120s

# Verify JARs
echo "🔍 Verifying required JARs..."
kubectl exec -n default $POD_NAME -- sh -c 'ls -la /spark/jars/ | grep -E "(hadoop-aws|bundle-2)" | head -5' 2>/dev/null || echo "⚠️  Could not verify JARs"

echo ""
echo "=============================================="
echo "✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "📋 Summary:"
echo "   Spark Image:    ${SPARK_IMAGE:-subhodeep2022/spark-bigdata:spark-4.0.1-uc-0.3.1-v4}"
echo "   Zeppelin Image: ${ZEPPELIN_IMAGE:-subhodeep2022/spark-bigdata:zeppelin-0.12.0-java17-v6}"
echo "   Pod:            $POD_NAME"
echo ""
echo "🌐 Access Zeppelin:"
echo "   kubectl port-forward svc/zeppelin 8082:8080 -n default"
echo "   Open: http://localhost:8082"
echo ""
echo "📝 Test SQL:"
echo "   CREATE SCHEMA IF NOT EXISTS unity.demo;"
echo "   CREATE TABLE unity.demo.test_table (...) USING delta LOCATION 's3://test-bucket/...';"
echo ""
