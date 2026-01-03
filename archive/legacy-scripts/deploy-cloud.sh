#!/bin/bash
set -e

echo "=============================================="
echo "Starting Cloud/General Deployment"
echo "=============================================="

# Add current directory to PATH for local helm binary
export PATH=$PWD:$PATH

# Check if kubectl is connected
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: kubectl is not connected to a cluster."
    exit 1
fi

# Cleanup Previous Deployment
if [ -f "cleanup.sh" ]; then
    echo "Running Cleanup..."
    # Ensure executable
    chmod +x cleanup.sh
    ./cleanup.sh
    echo "Waiting 60s for full termination..."
    sleep 60
fi

echo "[1/6] Preparing Configurations..."

# Create Zeppelin ConfigMaps
echo "Creating Zeppelin ConfigMaps..."
kubectl create configmap zeppelin-site --from-file=kubernetes/zeppelin-site.xml --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap zeppelin-interpreter-spec --from-file=interpreter-spec.yaml=kubernetes/100-interpreter-spec.yaml --dry-run=client -o yaml | kubectl apply -f -
# Create spark-templates ConfigMap for Zeppelin
kubectl create configmap spark-templates --from-file=interpreter-template.yaml=kubernetes/interpreter-template.yaml --from-file=executor-template.yaml=kubernetes/executor-template.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f kubernetes/spark-configmap.yaml

echo "[2/6] Deploying Storage and Databases..."
kubectl apply -f kubernetes/persistence.yaml
kubectl apply -f kubernetes/postgres.yaml
kubectl apply -f kubernetes/minio.yaml

echo "Waiting 30s for Databases to initialize..."
sleep 30

echo "[3/6] Deploying Core Services (Hive, Airflow)..."
kubectl apply -f kubernetes/hive-metastore.yaml
kubectl apply -f kubernetes/airflow.yaml

echo "[4/6] Deploying Compute (Zeppelin)..."
kubectl apply -f kubernetes/zeppelin.yaml

echo "[5/6] Installing Infrastructure (Traefik, Spark Operator, Dashboard)..."
# Install Traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set global.checkNewVersion=false \
  --set global.sendAnonymousUsage=false \
  --set "additionalArguments={--api.insecure=true,--api.dashboard=true}" \
  --timeout 10m
# Manually expose Traefik API port 9000 -> 8080 (Traefik internal)
kubectl patch svc traefik -p '{"spec":{"ports":[{"name":"traefik","port":9000,"targetPort":8080}]}}' || true

# Wait for Traefik LoadBalancer IP
echo "Waiting for Traefik LoadBalancer IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
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

# Install Kubernetes Dashboard
echo "Installing Kubernetes Dashboard..."
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# Disable IPv6 to fix Kong bind crash
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace --namespace kubernetes-dashboard \
  --set congress.enabled=false \
  --set app.ingress.enabled=false \
  --set kong.env.proxy_listen="0.0.0.0:8000\, 0.0.0.0:8443 ssl" \
  --set kong.env.admin_listen="0.0.0.0:8001\, 0.0.0.0:8444 ssl" \
  --set kong.env.status_listen="0.0.0.0:8100" \
  --timeout 10m
# Manually expose Kubernets Dashboard HTTP port 80 -> 8000
kubectl patch svc -n kubernetes-dashboard kubernetes-dashboard-kong-proxy --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "kong-proxy-http", "port": 80, "targetPort": 8000, "protocol": "TCP"}}]' || true
# Create Admin User
kubectl apply -f kubernetes/dashboard-admin.yaml
# Create Long-Lived Secret for Admin User (Avoids Auth Issues)
kubectl apply -f kubernetes/dashboard-admin-secret.yaml

# Apply transport for SSL Bypass
kubectl apply -f kubernetes/traefik-transport.yaml

# Apply dynamically updated Ingress for Kubernetes Dashboard
cat kubernetes/dashboard-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

echo "[6/6] Installing Monitoring & Superset..."

# Install Prometheus Stack (Monitor Spark)
echo "Installing Prometheus & Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --set grafana.adminPassword=prom-operator \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set prometheus.prometheusSpec.retention=168h \
  --timeout 10m

# Apply Grafana Ingress
cat kubernetes/grafana-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

echo "Installing Superset..."
helm repo add superset https://apache.github.io/superset
helm upgrade --install superset superset \
  --repo https://apache.github.io/superset \
  --values kubernetes/superset-values.yaml \
  --timeout 10m

# Apply Ingress (Dynamic)
echo "Applying Ingress Routes..."
cat kubernetes/ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

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
