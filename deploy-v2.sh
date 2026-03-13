#!/bin/bash
set -e

echo "Starting K8s Platform v2 Deployment..."

# ---------------------------------------------------
# Load Centralized Resource & Node Configuration
# ---------------------------------------------------
if [ -f "global-resource.env" ]; then
    source global-resource.env
    echo "Loaded global-resource.env (replicas, resources, node assignments)"
else
    echo "WARNING: global-resource.env not found in project root. Using hardcoded values."
fi

# Helper: resolve all $(VAR) placeholders from global-resource.env in a file.
# Usage: subst_vars <input_file>  →  outputs resolved content to stdout
subst_vars() {
  sed \
    -e "s|\$(GP_NODE_ROLE)|${GP_NODE_ROLE:-k8s-gp-node}|g" \
    -e "s|\$(SPARK_NODE_ROLE)|${SPARK_NODE_ROLE:-spark-node}|g" \
    -e "s|\$(MINIO_NODE_ROLE)|${MINIO_NODE_ROLE:-minio-worker}|g" \
    -e "s|\$(CONTROL_PLANE_NODE_ROLE)|${CONTROL_PLANE_NODE_ROLE:-control-plane}|g" \
    -e "s|\$(SUPERSET_NODE_REPLICAS)|${SUPERSET_NODE_REPLICAS:-2}|g" \
    -e "s|\$(SUPERSET_NODE_CPU_REQUEST)|${SUPERSET_NODE_CPU_REQUEST:-1000m}|g" \
    -e "s|\$(SUPERSET_NODE_CPU_LIMIT)|${SUPERSET_NODE_CPU_LIMIT:-2000m}|g" \
    -e "s|\$(SUPERSET_NODE_MEM_REQUEST)|${SUPERSET_NODE_MEM_REQUEST:-2Gi}|g" \
    -e "s|\$(SUPERSET_NODE_MEM_LIMIT)|${SUPERSET_NODE_MEM_LIMIT:-4Gi}|g" \
    -e "s|\$(SUPERSET_WORKER_REPLICAS)|${SUPERSET_WORKER_REPLICAS:-2}|g" \
    -e "s|\$(SUPERSET_WORKER_CPU_REQUEST)|${SUPERSET_WORKER_CPU_REQUEST:-1000m}|g" \
    -e "s|\$(SUPERSET_WORKER_CPU_LIMIT)|${SUPERSET_WORKER_CPU_LIMIT:-2000m}|g" \
    -e "s|\$(SUPERSET_WORKER_MEM_REQUEST)|${SUPERSET_WORKER_MEM_REQUEST:-2Gi}|g" \
    -e "s|\$(SUPERSET_WORKER_MEM_LIMIT)|${SUPERSET_WORKER_MEM_LIMIT:-4Gi}|g" \
    -e "s|\$(SUPERSET_BEAT_CPU_REQUEST)|${SUPERSET_BEAT_CPU_REQUEST:-250m}|g" \
    -e "s|\$(SUPERSET_BEAT_CPU_LIMIT)|${SUPERSET_BEAT_CPU_LIMIT:-500m}|g" \
    -e "s|\$(SUPERSET_BEAT_MEM_REQUEST)|${SUPERSET_BEAT_MEM_REQUEST:-256Mi}|g" \
    -e "s|\$(SUPERSET_BEAT_MEM_LIMIT)|${SUPERSET_BEAT_MEM_LIMIT:-512Mi}|g" \
    -e "s|\$(SUPERSET_INIT_CPU_REQUEST)|${SUPERSET_INIT_CPU_REQUEST:-500m}|g" \
    -e "s|\$(SUPERSET_INIT_CPU_LIMIT)|${SUPERSET_INIT_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(SUPERSET_INIT_MEM_REQUEST)|${SUPERSET_INIT_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(SUPERSET_INIT_MEM_LIMIT)|${SUPERSET_INIT_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(PROMETHEUS_STORAGE)|${PROMETHEUS_STORAGE:-10Gi}|g" \
    -e "s|\$(PROMETHEUS_RETENTION)|${PROMETHEUS_RETENTION:-168h}|g" \
    "$1"
}
export KUBECONFIG=/home/subhodeep/Documents/terraform-aws-k8s-ha/kubeconfig.yaml

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

# Clean up deprecated kubernetes-dashboard and potential stuck dashboards
kubectl delete namespace kubernetes-dashboard 2>/dev/null || true
kubectl delete svc kubernetes-dashboard-web kubernetes-dashboard-api -n default 2>/dev/null || true

# ---------------------------------------------------
# 2. Generate Helm Manifests (Adapted from deploy-gke.sh)
# ---------------------------------------------------
# Define the static IP found in the codebase to be replaced (Legacy GKE artifact, kept for safety)
STATIC_IP_TO_REPLACE="34.239.93.55"
STATIC_DOMAIN_TO_REPLACE="34.239.93.55.sslip.io"

echo "Generating Helm manifests..."
mkdir -p k8s-platform-v2/03-apps/charts/gen

# 2.1 Traefik Ingress Controller (pinned to control-plane, hostNetwork for bare-metal)
echo "Installing Traefik..."
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik
if helm list -n kube-system | grep -q traefik; then
  echo "Traefik is already installed. Upgrading..."
fi
helm upgrade --install traefik traefik/traefik \
  --namespace kube-system \
  -f k8s-platform-v2/01-networking/values-traefik.yaml \
  --timeout 10m

# No need to patch SVC for dashboard if on HostNetwork, but keeping for internal access if needed
kubectl patch svc traefik -n kube-system -p '{"spec":{"ports":[{"name":"traefik","port":9000,"targetPort":8080}]}}' || true

# 2.2 Spark Operator
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update spark-operator
_TMP_SPARK_OP=$(mktemp)
subst_vars k8s-platform-v2/03-apps/spark-operator-values.yaml > "$_TMP_SPARK_OP"
helm template spark-operator spark-operator/spark-operator \
  --namespace default \
  --version 2.4.0 \
  --include-crds \
  --api-versions="monitoring.coreos.com/v1/PodMonitor" \
  --set webhook.enable=true \
  -f "$_TMP_SPARK_OP" \
  > k8s-platform-v2/03-apps/charts/gen/spark-operator.yaml
rm -f "$_TMP_SPARK_OP"

# 2.2 Superset
echo "Generating secure SUPERSET_SECRET_KEY..."
SUPERSET_SECRET_KEY=$(openssl rand -base64 42)

helm repo add superset https://apache.github.io/superset
helm repo update superset
_TMP_SUPERSET=$(mktemp)
subst_vars k8s-platform-v2/03-apps/superset-values.yaml > "$_TMP_SUPERSET"
helm template superset superset/superset \
  --namespace default \
  --version 0.12.0 \
  -f "$_TMP_SUPERSET" | \
  sed "s|__SUPERSET_SECRET_KEY__|$SUPERSET_SECRET_KEY|g" \
  > k8s-platform-v2/03-apps/charts/gen/superset.yaml
rm -f "$_TMP_SUPERSET"

# 2.3 Monitoring Stack
mkdir -p k8s-platform-v2/05-monitoring/charts/gen

# kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
_TMP_PROM=$(mktemp)
subst_vars k8s-platform-v2/05-monitoring/values-prometheus.yaml > "$_TMP_PROM"
helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace default \
  --version 56.6.2 \
  --include-crds \
  -f "$_TMP_PROM" \
  > k8s-platform-v2/05-monitoring/charts/gen/kube-prometheus-stack.yaml
rm -f "$_TMP_PROM"

# loki-stack
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm template loki-stack grafana/loki-stack \
  --namespace default \
  --version 2.10.2 \
  -f k8s-platform-v2/05-monitoring/values-loki.yaml \
  > k8s-platform-v2/05-monitoring/charts/gen/loki-stack.yaml

# headlamp (Replacing deprecated kubernetes-dashboard)
echo "Generating headlamp manifests directly (Helm repo 404 bypass)..."
curl -sL https://raw.githubusercontent.com/headlamp-k8s/headlamp/main/kubernetes-headlamp.yaml > k8s-platform-v2/05-monitoring/charts/gen/headlamp.yaml
cat <<EOF >> k8s-platform-v2/05-monitoring/charts/gen/headlamp.yaml

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: headlamp
  namespace: kube-system
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: headlamp.\$(INGRESS_DOMAIN)
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: headlamp
                port:
                  number: 80
EOF

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
  sed "s|\$(INGRESS_DOMAIN)|$INGRESS_DOMAIN|g" | \
  sed "s|\$(SPARK_IMAGE)|$SPARK_IMAGE|g" | \
  sed "s|\$(JUPYTERHUB_IMAGE)|$JUPYTERHUB_IMAGE|g" | \
  sed "s|\$(MINIO_ENDPOINT)|$MINIO_ENDPOINT|g" | \
  sed "s|\$(AWS_ACCESS_KEY_ID)|$MINIO_ROOT_USER|g" | \
  sed "s|\$(AWS_SECRET_ACCESS_KEY)|$MINIO_ROOT_PASSWORD|g" | \
  sed "s|$STATIC_DOMAIN_TO_REPLACE|$INGRESS_DOMAIN|g" | \
  sed \
    -e "s|\$(GP_NODE_ROLE)|${GP_NODE_ROLE:-k8s-gp-node}|g" \
    -e "s|\$(SPARK_NODE_ROLE)|${SPARK_NODE_ROLE:-spark-node}|g" \
    -e "s|\$(MINIO_NODE_ROLE)|${MINIO_NODE_ROLE:-minio-worker}|g" \
    -e "s|\$(POSTGRES_REPLICAS)|${POSTGRES_REPLICAS:-1}|g" \
    -e "s|\$(POSTGRES_CPU_REQUEST)|${POSTGRES_CPU_REQUEST:-500m}|g" \
    -e "s|\$(POSTGRES_CPU_LIMIT)|${POSTGRES_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(POSTGRES_MEM_REQUEST)|${POSTGRES_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(POSTGRES_MEM_LIMIT)|${POSTGRES_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(MINIO_REPLICAS)|${MINIO_REPLICAS:-1}|g" \
    -e "s|\$(MINIO_CPU_REQUEST)|${MINIO_CPU_REQUEST:-500m}|g" \
    -e "s|\$(MINIO_CPU_LIMIT)|${MINIO_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(MINIO_MEM_REQUEST)|${MINIO_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(MINIO_MEM_LIMIT)|${MINIO_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(REDIS_REPLICAS)|${REDIS_REPLICAS:-1}|g" \
    -e "s|\$(REDIS_CPU_REQUEST)|${REDIS_CPU_REQUEST:-1000m}|g" \
    -e "s|\$(REDIS_CPU_LIMIT)|${REDIS_CPU_LIMIT:-1500m}|g" \
    -e "s|\$(REDIS_MEM_REQUEST)|${REDIS_MEM_REQUEST:-2048Mi}|g" \
    -e "s|\$(REDIS_MEM_LIMIT)|${REDIS_MEM_LIMIT:-3072Mi}|g" \
    -e "s|\$(AIRFLOW_WEBSERVER_REPLICAS)|${AIRFLOW_WEBSERVER_REPLICAS:-1}|g" \
    -e "s|\$(AIRFLOW_WEBSERVER_CPU_REQUEST)|${AIRFLOW_WEBSERVER_CPU_REQUEST:-500m}|g" \
    -e "s|\$(AIRFLOW_WEBSERVER_CPU_LIMIT)|${AIRFLOW_WEBSERVER_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(AIRFLOW_WEBSERVER_MEM_REQUEST)|${AIRFLOW_WEBSERVER_MEM_REQUEST:-0.5Gi}|g" \
    -e "s|\$(AIRFLOW_WEBSERVER_MEM_LIMIT)|${AIRFLOW_WEBSERVER_MEM_LIMIT:-1Gi}|g" \
    -e "s|\$(AIRFLOW_SCHEDULER_REPLICAS)|${AIRFLOW_SCHEDULER_REPLICAS:-1}|g" \
    -e "s|\$(AIRFLOW_SCHEDULER_CPU_REQUEST)|${AIRFLOW_SCHEDULER_CPU_REQUEST:-1000m}|g" \
    -e "s|\$(AIRFLOW_SCHEDULER_CPU_LIMIT)|${AIRFLOW_SCHEDULER_CPU_LIMIT:-2000m}|g" \
    -e "s|\$(AIRFLOW_SCHEDULER_MEM_REQUEST)|${AIRFLOW_SCHEDULER_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(AIRFLOW_SCHEDULER_MEM_LIMIT)|${AIRFLOW_SCHEDULER_MEM_LIMIT:-1.5Gi}|g" \
    -e "s|\$(SPARK_CONNECT_REPLICAS)|${SPARK_CONNECT_REPLICAS:-1}|g" \
    -e "s|\$(SPARK_CONNECT_CPU_REQUEST)|${SPARK_CONNECT_CPU_REQUEST:-500m}|g" \
    -e "s|\$(SPARK_CONNECT_CPU_LIMIT)|${SPARK_CONNECT_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(SPARK_CONNECT_MEM_REQUEST)|${SPARK_CONNECT_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(SPARK_CONNECT_MEM_LIMIT)|${SPARK_CONNECT_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(SPARK_HISTORY_REPLICAS)|${SPARK_HISTORY_REPLICAS:-1}|g" \
    -e "s|\$(SPARK_HISTORY_CPU_REQUEST)|${SPARK_HISTORY_CPU_REQUEST:-1000m}|g" \
    -e "s|\$(SPARK_HISTORY_CPU_LIMIT)|${SPARK_HISTORY_CPU_LIMIT:-1500m}|g" \
    -e "s|\$(SPARK_HISTORY_MEM_REQUEST)|${SPARK_HISTORY_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(SPARK_HISTORY_MEM_LIMIT)|${SPARK_HISTORY_MEM_LIMIT:-1.5Gi}|g" \
    -e "s|\$(JUPYTERHUB_REPLICAS)|${JUPYTERHUB_REPLICAS:-1}|g" \
    -e "s|\$(JUPYTERHUB_CPU_REQUEST)|${JUPYTERHUB_CPU_REQUEST:-500m}|g" \
    -e "s|\$(JUPYTERHUB_CPU_LIMIT)|${JUPYTERHUB_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(JUPYTERHUB_MEM_REQUEST)|${JUPYTERHUB_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(JUPYTERHUB_MEM_LIMIT)|${JUPYTERHUB_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(HIVE_REPLICAS)|${HIVE_REPLICAS:-1}|g" \
    -e "s|\$(HIVE_METASTORE_CPU_REQUEST)|${HIVE_METASTORE_CPU_REQUEST:-500m}|g" \
    -e "s|\$(HIVE_METASTORE_CPU_LIMIT)|${HIVE_METASTORE_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(HIVE_METASTORE_MEM_REQUEST)|${HIVE_METASTORE_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(HIVE_METASTORE_MEM_LIMIT)|${HIVE_METASTORE_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(HIVE_SERVER_CPU_REQUEST)|${HIVE_SERVER_CPU_REQUEST:-500m}|g" \
    -e "s|\$(HIVE_SERVER_CPU_LIMIT)|${HIVE_SERVER_CPU_LIMIT:-1000m}|g" \
    -e "s|\$(HIVE_SERVER_MEM_REQUEST)|${HIVE_SERVER_MEM_REQUEST:-1Gi}|g" \
    -e "s|\$(HIVE_SERVER_MEM_LIMIT)|${HIVE_SERVER_MEM_LIMIT:-2Gi}|g" \
    -e "s|\$(STARROCKS_FE_REPLICAS)|${STARROCKS_FE_REPLICAS:-1}|g" \
    -e "s|\$(STARROCKS_FE_CPU_REQUEST)|${STARROCKS_FE_CPU_REQUEST:-500m}|g" \
    -e "s|\$(STARROCKS_FE_CPU_LIMIT)|${STARROCKS_FE_CPU_LIMIT:-2000m}|g" \
    -e "s|\$(STARROCKS_FE_MEM_REQUEST)|${STARROCKS_FE_MEM_REQUEST:-2Gi}|g" \
    -e "s|\$(STARROCKS_FE_MEM_LIMIT)|${STARROCKS_FE_MEM_LIMIT:-4Gi}|g" \
    -e "s|\$(STARROCKS_BE_REPLICAS)|${STARROCKS_BE_REPLICAS:-1}|g" \
    -e "s|\$(STARROCKS_BE_CPU_REQUEST)|${STARROCKS_BE_CPU_REQUEST:-500m}|g" \
    -e "s|\$(STARROCKS_BE_CPU_LIMIT)|${STARROCKS_BE_CPU_LIMIT:-2000m}|g" \
    -e "s|\$(STARROCKS_BE_MEM_REQUEST)|${STARROCKS_BE_MEM_REQUEST:-2Gi}|g" \
    -e "s|\$(STARROCKS_BE_MEM_LIMIT)|${STARROCKS_BE_MEM_LIMIT:-4Gi}|g" \
  > generated-manifests.yaml

# Pre-cleanup to avoid immutable field errors
echo "Pre-cleaning immutable resources..."
kubectl delete job superset-init-db -n default --ignore-not-found=true
# Fix for "Forbidden: may not be specified when strategy type is Recreate"
kubectl delete deployment postgres -n default --ignore-not-found=true

echo "Pre-cleaning immutable RBAC..."
kubectl delete clusterrolebinding jupyterhub-spark --ignore-not-found=true
kubectl delete clusterrole jupyterhub-spark --ignore-not-found=true


# Pre-install Prometheus CRDs (they must exist before resources that reference them)
echo "Installing Prometheus Operator CRDs..."
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml 2>/dev/null || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml 2>/dev/null || true
echo "CRDs installed. Waiting for API registration..."
sleep 5

kubectl apply --server-side --force-conflicts -f generated-manifests.yaml

echo "Waiting for Resources..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n default || echo "MinIO wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n default || echo "Postgres wait timed out"

echo "Deployment Complete!"
echo "Superset: http://superset.$INGRESS_DOMAIN"
echo "Headlamp UI: http://headlamp.$INGRESS_DOMAIN"
echo "JupyterHub: http://jupyterhub.$INGRESS_DOMAIN"
echo "Minio: http://minio.$INGRESS_DOMAIN"
echo "Grafana: http://grafana.$INGRESS_DOMAIN"
echo "Spark: http://spark.$INGRESS_DOMAIN"
echo "Spark-History: http://spark-history.$INGRESS_DOMAIN"
echo "Hubble UI: http://hubble.$INGRESS_DOMAIN"

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
