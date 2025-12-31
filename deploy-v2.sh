#!/bin/bash
set -e

echo "Starting K8s Platform v2 Deployment..."

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

# Deploy
# Dynamic IP injection for Traefik Dashboard (User Request: No hardcoding)
echo "Resolving Traefik Internal IP..."
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.spec.clusterIP}')
if [ -z "$TRAEFIK_IP" ]; then
    echo "Error: Could not find Traefik service in kube-system!"
    exit 1
fi
echo "Found Traefik IP: $TRAEFIK_IP"
sed -i "s/TRAEFIK_IP_PLACEHOLDER/$TRAEFIK_IP/g" ./k8s-platform-v2/01-networking/traefik-endpoints.yaml

# Deploy
echo "Deploying Stack..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | kubectl apply -f -

# Revert placeholder to keep git clean (optional, but good practice if commited)
# sed -i "s/$TRAEFIK_IP/TRAEFIK_IP_PLACEHOLDER/g" ./k8s-platform-v2/01-networking/traefik-endpoints.yaml
echo "Waiting for Resources..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n default || echo "MinIO wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n default || echo "Postgres wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/traefik -n kube-system || echo "Traefik wait timed out (might be Helm managed or DaemonSet)"

echo "Deployment Complete!"
echo "Check status with: kubectl get pods"
