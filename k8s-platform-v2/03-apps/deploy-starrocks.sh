#!/bin/bash
# =============================================================================
# Deploy StarRocks via the official operator Helm chart (kube-starrocks)
# =============================================================================
# - Operator + StarRocksCluster (1 FE, 1 BE) in namespace "starrocks"
# - FE meta / BE data on PVCs (see starrocks-values.yaml)
# - root password from secret "starrocks-root-password" (created once, never overwritten)
# - External catalogs from configs/starrocks-catalogs.sql (idempotent)
#
# Safe to re-run: helm upgrade only rolls pods when values/version change.
# Read the root password:
#   kubectl -n starrocks get secret starrocks-root-password -o jsonpath='{.data.password}' | base64 -d
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

NAMESPACE="starrocks"
RELEASE="starrocks"
CHART_VERSION="1.11.8"          # kube-starrocks chart; StarRocks image tag is pinned in starrocks-values.yaml
FE_POD="kube-starrocks-fe-0"

echo "=============================================="
echo "🚀 Deploying StarRocks (Helm + Operator)"
echo "=============================================="

if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
if [ -z "$INGRESS_DOMAIN" ] && [ -f "$PROJECT_ROOT/k8s-platform-v2/04-configs/global-config.env" ]; then
    source "$PROJECT_ROOT/k8s-platform-v2/04-configs/global-config.env"
fi

helm repo add starrocks https://starrocks.github.io/starrocks-kubernetes-operator >/dev/null 2>&1 || true
helm repo update starrocks

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Root password secret: create only if missing. initPassword only applies on first install,
# so regenerating it later would lock clients out.
if ! kubectl -n "$NAMESPACE" get secret starrocks-root-password >/dev/null 2>&1; then
    echo "🔑 Creating root password secret..."
    kubectl -n "$NAMESPACE" create secret generic starrocks-root-password \
        --from-literal=password="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)"
fi

echo "📦 helm upgrade --install $RELEASE (chart $CHART_VERSION)..."
helm upgrade --install "$RELEASE" starrocks/kube-starrocks \
    --version "$CHART_VERSION" \
    -n "$NAMESPACE" \
    -f "$SCRIPT_DIR/starrocks-values.yaml"

echo "⏳ Waiting for StarRocksCluster to be running (first install pulls ~2.5GB of images)..."
if ! timeout 900 bash -c "until kubectl -n $NAMESPACE get starrockscluster kube-starrocks -o jsonpath='{.status.phase}' 2>/dev/null | grep -qx running; do sleep 10; done"; then
    echo "❌ StarRocks did not become ready. Check: kubectl -n $NAMESPACE get starrockscluster,pods"
    exit 1
fi

# The operator injects MYSQL_PWD into the FE container, so mysql inside it is authenticated.
echo "📦 Applying catalogs and databases..."
envsubst '${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}' < "$SCRIPT_DIR/configs/starrocks-catalogs.sql" | \
    kubectl -n "$NAMESPACE" exec -i "$FE_POD" -- mysql -h 127.0.0.1 -P 9030 -u root
kubectl -n "$NAMESPACE" exec "$FE_POD" -- mysql -h 127.0.0.1 -P 9030 -u root -e "SHOW CATALOGS;"

if [ -n "$INGRESS_DOMAIN" ]; then
    echo "📦 Applying FE web UI ingress..."
    sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" "$SCRIPT_DIR/starrocks-ingress.yaml" | kubectl apply -f -
fi

echo "=============================================="
echo "✅ StarRocks ready"
echo "   MySQL: kube-starrocks-fe-service.$NAMESPACE.svc.cluster.local:9030 (user root)"
echo "   HTTP:  kube-starrocks-fe-service.$NAMESPACE.svc.cluster.local:8030"
echo "   External: <node-ip>:30930 (MySQL), <node-ip>:30830 (HTTP), http://starrocks.$INGRESS_DOMAIN"
echo "=============================================="
