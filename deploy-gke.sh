#!/bin/bash
set -e

echo "=============================================="
echo "Starting GKE Deployment (V2 + Cloud Logic)"
echo "=============================================="

# Add current directory to PATH for local helm binary if needed
export PATH=$PWD:$PATH

# Check connectivity
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: kubectl is not connected to a cluster."
    exit 1
fi

echo "[1/4] Deploying Infrastructure (Traefik, Spark Operator)..."

# Install Traefik (Infrastructure Layer)
echo "Installing Traefik..."
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik
if helm list -n kube-system | grep -q traefik; then
  echo "Traefik is already installed. Skipping..."
else
  helm upgrade --install traefik traefik/traefik \
    --namespace kube-system \
    --set ports.web.nodePort=null \
    --set ports.websecure.nodePort=null \
    --set global.checkNewVersion=false \
    --set global.sendAnonymousUsage=false \
    --set "additionalArguments={--api.insecure=true,--api.dashboard=true}" \
    --timeout 10m
fi

# Manually expose Traefik API port 9000 -> 8080
kubectl patch svc traefik -n kube-system -p '{"spec":{"ports":[{"name":"traefik","port":9000,"targetPort":8080}]}}' || true

# Install Spark Operator
echo "Installing Spark Operator..."
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update spark-operator
if helm list -n default | grep -q spark-operator; then
  echo "Spark Operator is already installed. Skipping..."
else
  helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace default \
  --timeout 10m
fi

echo "[2/4] Waiting for LoadBalancer IP..."
EXTERNAL_IP=""
echo "Waiting for Traefik LoadBalancer IP..."
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Waiting for IP..."
    sleep 10
  fi
done
echo "Traefik IP Assigned: $EXTERNAL_IP"
INGRESS_DOMAIN="${EXTERNAL_IP}.sslip.io"
echo "Using Domain: $INGRESS_DOMAIN"

echo "[3/4] Deploying K8s Platform V2 (Injecting IP)..."

# Define the static IP found in the codebase to be replaced
STATIC_IP_TO_REPLACE="34.58.10.252"
STATIC_DOMAIN_TO_REPLACE="34.58.10.252.sslip.io"

# Pre-generate Helm charts to avoid Kustomize/Helm version issues
echo "Generating Helm manifests..."
mkdir -p k8s-platform-v2/03-apps/charts/gen

# 1. Spark Operator
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update spark-operator
helm template spark-operator spark-operator/spark-operator \
  --namespace default \
  --version 1.1.27 \
  --set webhook.enable=true \
  > k8s-platform-v2/03-apps/charts/gen/spark-operator.yaml

# 2. Superset
helm repo add superset https://apache.github.io/superset
helm repo update superset
helm template superset superset/superset \
  --namespace default \
  --version 0.12.0 \
  -f k8s-platform-v2/03-apps/superset-values.yaml \
  > k8s-platform-v2/03-apps/charts/gen/superset.yaml

# 3. Monitoring Stack
echo "Generating Monitoring manifests..."
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

# 4. Unity Catalog
echo "Generating Unity Catalog manifests..."
mkdir -p build/unitycatalog
if [ ! -d "build/unitycatalog/.git" ]; then
  git clone https://github.com/unitycatalog/unitycatalog.git build/unitycatalog
else
  # Update if exists
  (cd build/unitycatalog && git fetch --tags)
fi
# Checkout v0.3.1 tag for storage credentials API
(cd build/unitycatalog && git checkout v0.3.1)

mkdir -p k8s-platform-v2/04-catalog/charts/gen
helm template unity-catalog build/unitycatalog/helm \
  --namespace default \
  -f k8s-platform-v2/04-catalog/values-unity-catalog.yaml \
  > k8s-platform-v2/04-catalog/charts/gen/unity-catalog.yaml

# Deploy using Kustomize V2, piping through sed to replace the IP/Domain
# We replace the full domain first, then the IP just in case
# We also replace $(INGRESS_DOMAIN) placeholder if it exists
# Load environment variables
if [ -f .env ]; then
  source .env
fi

echo "Building and Applying Manifests..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | \
  sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | \
  sed "s|\$(SPARK_IMAGE)|$SPARK_IMAGE|g" | \
  sed "s|\$(JUPYTERHUB_IMAGE)|$JUPYTERHUB_IMAGE|g" | \
  sed "s|\$(MARIMO_IMAGE)|$MARIMO_IMAGE|g" | \
  sed "s|\$(POLYNOTE_IMAGE)|$POLYNOTE_IMAGE|g" | \
  sed "s|\$(MINIO_ENDPOINT)|$MINIO_ENDPOINT|g" | \
  sed "s|\$(AWS_ACCESS_KEY_ID)|$MINIO_ROOT_USER|g" | \
  sed "s|\$(AWS_SECRET_ACCESS_KEY)|$MINIO_ROOT_PASSWORD|g" | \
  sed "s/$STATIC_DOMAIN_TO_REPLACE/$INGRESS_DOMAIN/g" | \
  kubectl apply --server-side --force-conflicts -f - || echo "First apply failed (likely CRDs), retrying..."

echo "Waiting for CRDs to settle..."
sleep 10

echo "Re-applying manifests..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | \
  sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | \
  sed "s|\$(SPARK_IMAGE)|$SPARK_IMAGE|g" | \
  sed "s|\$(JUPYTERHUB_IMAGE)|$JUPYTERHUB_IMAGE|g" | \
  sed "s|\$(MARIMO_IMAGE)|$MARIMO_IMAGE|g" | \
  sed "s|\$(POLYNOTE_IMAGE)|$POLYNOTE_IMAGE|g" | \
  sed "s|\$(MINIO_ENDPOINT)|$MINIO_ENDPOINT|g" | \
  sed "s|\$(AWS_ACCESS_KEY_ID)|$MINIO_ROOT_USER|g" | \
  sed "s|\$(AWS_SECRET_ACCESS_KEY)|$MINIO_ROOT_PASSWORD|g" | \
  sed "s/$STATIC_DOMAIN_TO_REPLACE/$INGRESS_DOMAIN/g" | \
  kubectl apply --server-side --force-conflicts -f -

echo "[4/4] Post-Deployment Verification & Info"

echo "Waiting for critical deployments..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n default || echo "MinIO wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n default || echo "Postgres wait timed out"

# Dashboard Access
echo "=============================================="
echo "Deployment Complete!"
echo "Access URLs:"
echo "Traefik Dashboard: http://traefik.$INGRESS_DOMAIN/dashboard/"
echo "K8s Dashboard:     https://dashboard.$INGRESS_DOMAIN"
echo "Grafana:           http://grafana.$INGRESS_DOMAIN"
echo "Airflow:           http://airflow.$INGRESS_DOMAIN"
echo "MinIO Console:     http://minio.$INGRESS_DOMAIN"
echo "JupyterHub:        http://jupyterhub.$INGRESS_DOMAIN"
echo "Marimo:            http://marimo.$INGRESS_DOMAIN"
echo "Polynote:          http://polynote.$INGRESS_DOMAIN"
echo "Superset:          http://superset.$INGRESS_DOMAIN"
echo "=============================================="
