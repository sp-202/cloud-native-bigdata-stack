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

# Deploy using Kustomize V2, piping through sed to replace the IP/Domain
# We replace the full domain first, then the IP just in case
# We also replace $(INGRESS_DOMAIN) placeholder if it exists
echo "Building and Applying Manifests..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | \
  sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | \
  sed "s/$STATIC_DOMAIN_TO_REPLACE/$INGRESS_DOMAIN/g" | \
  sed "s/$STATIC_IP_TO_REPLACE/$EXTERNAL_IP/g" | \
  kubectl apply --server-side --force-conflicts -f - || echo "First apply failed (likely CRDs), retrying..."

echo "Waiting for CRDs to settle..."
sleep 10

echo "Re-applying manifests..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | \
  sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | \
  sed "s/$STATIC_DOMAIN_TO_REPLACE/$INGRESS_DOMAIN/g" | \
  sed "s/$STATIC_IP_TO_REPLACE/$EXTERNAL_IP/g" | \
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
echo "Zeppelin:          http://zeppelin.$INGRESS_DOMAIN"
echo "Superset:          http://superset.$INGRESS_DOMAIN"
echo "=============================================="
