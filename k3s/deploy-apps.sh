#!/bin/bash
set -e

echo "=============================================="
echo "Starting Application Layer Deployment (Stateless)"
echo "=============================================="

# Add current directory to PATH for local helm binary
export PATH=$PWD:$PATH

# K3s Auto-Context Fix (Run in every script)
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    if [ ! -r "/etc/rancher/k3s/k3s.yaml" ]; then
        sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    fi
fi

# Auto-Alias for K3s (if kubectl is missing but k3s exists)
if ! command -v kubectl &> /dev/null; then
    if command -v k3s &> /dev/null; then
        echo "⚠️  'kubectl' not found, but 'k3s' detected. using 'k3s kubectl'..."
        function kubectl() {
            k3s kubectl "$@"
        }
        export -f kubectl
    else
        echo "❌ Error: Neither 'kubectl' nor 'k3s' found in PATH."
        exit 1
    fi
fi

# Check if kubectl is connected
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Error: kubectl is NOT connected to a cluster."
    echo "Diagnostics:"
    echo "  - KUBECONFIG: ${KUBECONFIG:-'Not Set'}"
    echo "  - Host: $(hostname)"
    echo ""
    echo "Fix:"
    echo "  1. If running on the K3s Server: Ensure '/etc/rancher/k3s/k3s.yaml' exists and is readable."
    echo "  2. If running remotely (Mac/PC): Copy the kubeconfig from the server and run:"
    echo "     export KUBECONFIG=/path/to/k3s.yaml"
    exit 1
fi

# Fetch Traefik IP for Ingress Rules
# Fetch Traefik IP for Ingress Rules (Check default first, then kube-system for K3s)
EXTERNAL_IP=$(kubectl get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
fi
if [ -z "$EXTERNAL_IP" ]; then
    # Fallback to Node IP for HostPath/NodePort setups
    EXTERNAL_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi
if [ -z "$EXTERNAL_IP" ]; then
  echo "Error: Traefik IP not found. Is Infrastructure deployed?"
  exit 1
fi
INGRESS_DOMAIN="${EXTERNAL_IP}.sslip.io"
echo "Using Domain: $INGRESS_DOMAIN"

# [1/3] Preparing Configurations...
echo "[1/3] Preparing Configurations..."
# Create Namespaces if needed (though Infra should handle it)
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

# Apply ConfigMaps & Secrets (Safe to update)
# kubectl apply -f kubernetes/configmaps.yaml

# Generate Spark Configs
cat kubernetes/spark-configmap.yaml | sed "s/LOG_BUCKET/spark-logs/g" | kubectl apply -f -
# Enable Zeppelin to use MinIO/S3
kubectl create configmap zeppelin-site --from-file=zeppelin-site.xml=kubernetes/zeppelin-site.xml --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap zeppelin-interpreter-spec --from-file=interpreter-spec.yaml=kubernetes/100-interpreter-spec.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap spark-templates --from-file=interpreter-template.yaml=kubernetes/interpreter-template.yaml --from-file=executor-template.yaml=kubernetes/executor-template.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap spark-config --from-file=spark-defaults.conf=kubernetes/spark-defaults.conf --dry-run=client -o yaml | kubectl apply -f -

# [2/3] Deploying Applications...
echo "[2/3] Deploying Applications..."
kubectl apply -f kubernetes/hive-metastore.yaml
kubectl apply -f kubernetes/airflow.yaml

echo "[4/6] Deploying Compute (Zeppelin)..."
kubectl apply -f kubernetes/zeppelin.yaml

echo "[5/6] Installing Infrastructure (Traefik, Spark Operator, Dashboard)..."
# Skipping Traefik Install (Using K3s Bundled Traefik)
# helm upgrade --install traefik ...

# Wait for Traefik LoadBalancer IP
echo "Waiting for Traefik LoadBalancer IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  # Check default first
  EXTERNAL_IP=$(kubectl get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  
  # Check kube-system (K3s default)
  if [ -z "$EXTERNAL_IP" ]; then
      EXTERNAL_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  fi
  
  # Fallback: Node IP
  if [ -z "$EXTERNAL_IP" ]; then
       EXTERNAL_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  fi
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Waiting for IP..."
    sleep 10
  fi
done
echo "Traefik IP Assigned: $EXTERNAL_IP"
INGRESS_DOMAIN="${EXTERNAL_IP}.sslip.io"
echo "Using Domain: $INGRESS_DOMAIN"

# Apply dynamically updated Ingress for Traefik Dashboard
cat kubernetes/traefik-dashboard-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

# Install Spark Operator (in default namespace)
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm upgrade --install spark-operator spark-operator/spark-operator --timeout 10m

# Apply transport for SSL Bypass
kubectl apply -f kubernetes/traefik-transport.yaml

# Airflow
kubectl apply -f kubernetes/airflow.yaml
# Zeppelin
kubectl apply -f kubernetes/zeppelin.yaml

# Superset (Helm Upgrade is safe for Apps)
echo "Installing/Updating Superset..."
if [ ! -d "superset" ]; then
    echo "Cloning Superset repository..."
    git clone --depth 1 https://github.com/apache/superset.git
fi
echo "Updating Chart Dependencies..."
helm dependency update ./superset/helm/superset
# helm repo add superset https://apache.github.io/superset
helm upgrade --install superset ./superset/helm/superset --namespace default -f kubernetes/superset-values.yaml

# Apply Ingress Rules for Apps (Update Domain)
echo "Updating Ingress Rules..."
cat kubernetes/ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

echo "Application Deployment Complete!"
echo "=============================================="
echo "Deployment Complete!"
echo "Access URLs:"
echo "Traefik Dashboard: http://traefik.$INGRESS_DOMAIN/dashboard/"
echo "K8s Dashboard:     http://dashboard.$INGRESS_DOMAIN"
echo "Grafana:           http://grafana.$INGRESS_DOMAIN"
echo "Airflow:           http://airflow.$INGRESS_DOMAIN"
echo "MinIO Console:     http://minio.$INGRESS_DOMAIN"
echo "Zeppelin:          http://zeppelin.$INGRESS_DOMAIN"
echo "Superset:          http://superset.$INGRESS_DOMAIN"
echo "=============================================="
echo "Fetching Kubernetes Dashboard Token..."
kubectl get secret admin-user-secret -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
echo ""
echo "=============================================="
