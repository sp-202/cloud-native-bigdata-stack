#!/bin/bash
set -e

echo "=============================================="
echo "Starting Cloud Infrastructure Deployment (Storage & Monitoring)"
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

echo "[3/3] Installing Infrastructure and Monitoring..."

# Traefik (Ingress Controller)
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik -n default --wait --set "additionalArguments={--serverstransport.insecureSkipVerify=true}"

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

# Spark Operator (Kubeflow)
helm repo list | grep -q spark-operator || helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm uninstall spark-operator --namespace default 2>/dev/null || true
helm upgrade --install spark-operator spark-operator/spark-operator --namespace default --create-namespace --set webhook.enable=true --timeout 10m

# Kubernetes Dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm uninstall kubernetes-dashboard --namespace kubernetes-dashboard 2>/dev/null || true
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --namespace kubernetes-dashboard --create-namespace --set kong.admin.ingress.enabled=false --set kong.proxy.http.enabled=true --set nginx.http.ipv6=false 

# Create Admin User for Dashboard
kubectl apply -f kubernetes/dashboard-admin.yaml
kubectl apply -f kubernetes/dashboard-admin-secret.yaml
# Apply dynamically updated Ingress for Dashboard
cat kubernetes/dashboard-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -
cat kubernetes/traefik-dashboard-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

# Monitoring (Prometheus & Grafana)
echo "Installing Prometheus & Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace default --set grafana.adminPassword=prom-operator --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=standard --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi --set prometheus.prometheusSpec.retention=168h

# Apply Grafana Ingress
cat kubernetes/grafana-ingress.yaml | sed "s/INGRESS_DOMAIN/$INGRESS_DOMAIN/g" | kubectl apply -f -

echo "Infrastructure Deployment Complete!"
echo "Now run ./deploy-apps.sh to deploy applications."
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
