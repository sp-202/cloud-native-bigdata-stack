#!/bin/bash
set -e

echo "Starting K8s Platform v2 Deployment (K3s Production)..."

# K3s Configuration Setup
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    echo "Detected K3s config. Exporting KUBECONFIG..."
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    if [ ! -r "/etc/rancher/k3s/k3s.yaml" ]; then
        echo "Need sudo to read k3s.yaml... Attempting to change permissions."
        sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    fi
fi

# Connectivity Check
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: kubectl is not connected to a cluster."
    echo "Please ensure you have a valid KUBECONFIG or are running on the cluster node."
    exit 1
fi

echo "Cluster Connected!"

# ---------------------------------------------------
# 1. Cleanup Legacy Components (Zeppelin, Marimo, Polynote)
# ---------------------------------------------------
echo "Cleaning up legacy services..."
kubectl delete deployment zeppelin marimo polynote -n default 2>/dev/null || true
kubectl delete svc zeppelin zeppelin-server marimo polynote -n default 2>/dev/null || true
kubectl delete pvc zeppelin-notebook-pvc -n default 2>/dev/null || true

# Clean up potential stuck dashboards
kubectl delete svc kubernetes-dashboard-web kubernetes-dashboard-api -n default 2>/dev/null || true

# ---------------------------------------------------
# 2. Generate Helm Manifests (Adapted from deploy-gke.sh)
# ---------------------------------------------------
# Define the static IP found in the codebase to be replaced (Legacy GKE artifact, kept for safety)
STATIC_IP_TO_REPLACE="34.58.10.252"
STATIC_DOMAIN_TO_REPLACE="34.58.10.252.sslip.io"

echo "Generating Helm manifests..."
mkdir -p k8s-platform-v2/03-apps/charts/gen

# 2.1 Spark Operator
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update spark-operator
helm template spark-operator spark-operator/spark-operator \
  --namespace default \
  --version 1.1.27 \
  --set webhook.enable=true \
  > k8s-platform-v2/03-apps/charts/gen/spark-operator.yaml

# 2.2 Superset
helm repo add superset https://apache.github.io/superset
helm repo update superset
helm template superset superset/superset \
  --namespace default \
  --version 0.12.0 \
  -f k8s-platform-v2/03-apps/superset-values.yaml \
  > k8s-platform-v2/03-apps/charts/gen/superset.yaml

# 2.3 Monitoring Stack
mkdir -p k8s-platform-v2/05-monitoring/charts/gen

# kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace default \
  --version 56.6.2 \
  --include-crds \
  -f k8s-platform-v2/05-monitoring/values-prometheus.yaml \
  > k8s-platform-v2/05-monitoring/charts/gen/kube-prometheus-stack.yaml

# loki-stack
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm template loki-stack grafana/loki-stack \
  --namespace default \
  --version 2.10.2 \
  -f k8s-platform-v2/05-monitoring/values-loki.yaml \
  > k8s-platform-v2/05-monitoring/charts/gen/loki-stack.yaml

# kubernetes-dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm template kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace default \
  --version 7.5.0 \
  -f k8s-platform-v2/05-monitoring/values-dashboard.yaml \
  > k8s-platform-v2/05-monitoring/charts/gen/kubernetes-dashboard.yaml



# ---------------------------------------------------
# 3. Environment Setup & Deployment
# ---------------------------------------------------

# Determine Ingress Domain (K3s usually uses Node IP or sslip.io)
# If global-config.env exists, use it, otherwise try to detect or fallback
EXTERNAL_IP=""
if [ -f "k8s-platform-v2/04-configs/global-config.env" ]; then
    source k8s-platform-v2/04-configs/global-config.env
fi

if [ -z "$INGRESS_DOMAIN" ]; then
    # Try to detect Node IP for K3s
    NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if [ -n "$NODE_IP" ]; then
        INGRESS_DOMAIN="${NODE_IP}.sslip.io"
        echo "Auto-detected K3s Domain: $INGRESS_DOMAIN"
    else
        echo "Could not detect Ingress Domain. Please set INGRESS_DOMAIN in k8s-platform-v2/04-configs/global-config.env"
        exit 1
    fi
fi

# Load .env for substitution
if [ -f .env ]; then
  source .env
fi

# Set defaults if not present in .env
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.default.svc.cluster.local:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

echo "Deploying Stack to $INGRESS_DOMAIN..."

# Apply Manifests
# Note: piped through sed to replace variables using .env values
kubectl kustomize --enable-helm ./k8s-platform-v2 | \
  sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | \
  sed "s|\$(SPARK_IMAGE)|$SPARK_IMAGE|g" | \
  sed "s|\$(JUPYTERHUB_IMAGE)|$JUPYTERHUB_IMAGE|g" | \
  sed "s|\$(MINIO_ENDPOINT)|$MINIO_ENDPOINT|g" | \
  sed "s|\$(AWS_ACCESS_KEY_ID)|$MINIO_ROOT_USER|g" | \
  sed "s|\$(AWS_SECRET_ACCESS_KEY)|$MINIO_ROOT_PASSWORD|g" | \
  sed "s/$STATIC_DOMAIN_TO_REPLACE/$INGRESS_DOMAIN/g" > generated-manifests.yaml

# Pre-cleanup to avoid immutable field errors
echo "Pre-cleaning immutable resources..."
kubectl delete job superset-init-db -n default --ignore-not-found=true
# Fix for "Forbidden: may not be specified when strategy type is Recreate"
kubectl delete deployment postgres -n default --ignore-not-found=true

kubectl apply --server-side --force-conflicts -f generated-manifests.yaml

echo "Waiting for Resources..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n default || echo "MinIO wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n default || echo "Postgres wait timed out"

echo "Deployment Complete!"
echo "Superset: http://superset.$INGRESS_DOMAIN"
echo "JupyterHub: http://jupyterhub.$INGRESS_DOMAIN"

# ---------------------------------------------------
# 4. StarRocks Production Fix (Post-Deploy)
# ---------------------------------------------------
echo "---------------------------------------------------"
echo "Running StarRocks Production Fixer..."
echo "---------------------------------------------------"

# Wait for pods to be ready
echo "Waiting for StarRocks pods..."
kubectl wait --for=condition=ready pod starrocks-fe-0 -n default --timeout=300s || echo "FE wait timed out"
kubectl wait --for=condition=ready pod starrocks-be-0 -n default --timeout=300s || echo "BE wait timed out"

# Get BE IP (External/Host view is reliable)
BE_IP=$(kubectl get pod starrocks-be-0 -n default -o jsonpath='{.status.podIP}')
echo "Detected StarRocks BE IP: $BE_IP"

if [ -n "$BE_IP" ]; then
    echo "Force-Registering Backend..."
    kubectl exec -n default starrocks-fe-0 -- mysql -h 127.0.0.1 -P 9030 -u root -e "ALTER SYSTEM ADD BACKEND '${BE_IP}:9050';" 2>/dev/null || echo "Backend might already exist (warning ignored)."
    
    echo "Ensuring 'demo' Database..."
    kubectl exec -n default starrocks-fe-0 -- mysql -h 127.0.0.1 -P 9030 -u root -e "CREATE DATABASE IF NOT EXISTS demo;" || echo "Failed to create demo DB"
    
    echo "StarRocks Fix Complete."
else
    echo "ERROR: Could not detect StarRocks BE IP. Skipping fix."
fi
echo "---------------------------------------------------"
