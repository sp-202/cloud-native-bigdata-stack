#!/bin/bash
# =============================================================================
# Deploy Superset 6.x via the Apache Superset Kubernetes Operator (Production mode)
# =============================================================================
# - Operator (OCI chart superset-operator) in "superset-operator-system", watching only "superset"
# - Redis (superset/valkey.yaml) + Superset CR (superset/superset.yaml) in namespace "superset"
# - Image: official apache/superset; DB drivers installed at startup by spec.bootstrapScript
#
# Secrets in namespace "superset" (Production mode rejects inline secrets):
#   valkey-connection  created here if missing (random password)
#   superset-secret    key "secret-key"  - MUST be the existing SECRET_KEY, never generated here:
#                      a different key makes every saved database password undecryptable
#   superset-db        keys host, port, dbname, username, password
#
# Safe to re-run. With lifecycle.upgradeMode=Supervised an image change waits for approval:
#   TOKEN=$(kubectl -n superset get superset superset -o jsonpath='{.status.lifecycle.upgrade.approvalToken}')
#   kubectl -n superset annotate superset superset superset.apache.org/approve-upgrade="$TOKEN" --overwrite
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

NAMESPACE="superset"
OPERATOR_NAMESPACE="superset-operator-system"
OPERATOR_VERSION="0.3.0"

echo "=============================================="
echo "🚀 Deploying Superset (Operator)"
echo "=============================================="

if [ -f "$ENV_FILE" ]; then
    echo "📦 Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi
if [ -z "$INGRESS_DOMAIN" ] && [ -f "$PROJECT_ROOT/k8s-platform-v2/04-configs/global-config.env" ]; then
    source "$PROJECT_ROOT/k8s-platform-v2/04-configs/global-config.env"
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

for s in superset-secret superset-db; do
    if ! kubectl -n "$NAMESPACE" get secret "$s" >/dev/null 2>&1; then
        echo "❌ Secret $NAMESPACE/$s is missing. Create it first (see header of this script)."
        exit 1
    fi
done
if ! kubectl -n "$NAMESPACE" get secret valkey-connection >/dev/null 2>&1; then
    echo "🔑 Creating Redis secret..."
    kubectl -n "$NAMESPACE" create secret generic valkey-connection \
        --from-literal=endpoint="superset-valkey.$NAMESPACE.svc.cluster.local" \
        --from-literal=port=6379 \
        --from-literal=password="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)"
fi

echo "📦 helm upgrade --install superset-operator ($OPERATOR_VERSION)..."
helm upgrade --install superset-operator \
    oci://ghcr.io/apache/superset-kubernetes-operator/charts/superset-operator \
    --version "$OPERATOR_VERSION" \
    -n "$OPERATOR_NAMESPACE" --create-namespace \
    -f "$SCRIPT_DIR/superset/operator-values.yaml" \
    --wait --timeout 5m

echo "📦 Applying Redis..."
kubectl apply -f "$SCRIPT_DIR/superset/valkey.yaml"
kubectl -n "$NAMESPACE" rollout status deploy/superset-valkey --timeout=180s

echo "📦 Applying Superset CR..."
sed "s|\$(INGRESS_DOMAIN)|$INGRESS_DOMAIN|g" "$SCRIPT_DIR/superset/superset.yaml" | kubectl apply -f -

echo "⏳ Waiting for Superset to be Running (first run executes db upgrade + init)..."
if ! timeout 1800 bash -c "until kubectl -n $NAMESPACE get superset superset -o jsonpath='{.status.phase}' 2>/dev/null | grep -qx Running; do sleep 15; done"; then
    PHASE=$(kubectl -n "$NAMESPACE" get superset superset -o jsonpath='{.status.phase}')
    echo "⚠️  Superset phase: $PHASE"
    [ "$PHASE" = "AwaitingApproval" ] && echo "   Approve the upgrade (see header of this script)."
    echo "   Check: kubectl -n $NAMESPACE get superset,jobs,pods"
    exit 1
fi

echo "=============================================="
echo "✅ Superset ready: http://superset.$INGRESS_DOMAIN"
echo "=============================================="
