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

# Safe Cleanup (Network & Dashboard only)
echo "Performing Network Cleanup (Preserving DB/MinIO)..."
kubectl delete service traefik-external -n default 2>/dev/null || true
kubectl delete endpoints traefik-external -n default 2>/dev/null || true
kubectl delete ingress traefik-dashboard-ingress -n default 2>/dev/null || true
kubectl delete ingress kubernetes-dashboard -n kubernetes-dashboard 2>/dev/null || true
# Aggressive Dashboard Service Cleanup (User request: fresh start)
kubectl delete svc kubernetes-dashboard-web kubernetes-dashboard-api kubernetes-dashboard-auth kubernetes-dashboard-metrics-scraper -n default 2>/dev/null || true
kubectl delete svc kubernetes-dashboard-web kubernetes-dashboard-api kubernetes-dashboard-auth kubernetes-dashboard-metrics-scraper -n kubernetes-dashboard 2>/dev/null || true
# Optional: Clear dashboard namespace if it's stuck or broken
# kubectl delete ns kubernetes-dashboard 2>/dev/null || true

# Dynamic IP injection for Traefik Dashboard (User Request: No hardcoding)
echo "Resolving Traefik Internal IP..."
# CRITICAL: Get the POD IP, not the Service ClusterIP.
TRAEFIK_IP=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].status.podIP}')
if [ -z "$TRAEFIK_IP" ]; then
    echo "Error: Could not find Traefik pod in kube-system!"
    exit 1
fi
echo "Found Traefik Pod IP: $TRAEFIK_IP"
# Inject Pod IP
sed -i "s/ip: .*/ip: $TRAEFIK_IP/" ./k8s-platform-v2/01-networking/traefik-endpoints.yaml
# Update Port to 8080 (Container Port) inside the generated endpoints because we are hitting Pod direct
sed -i "s/port: 9000/port: 8080/g" ./k8s-platform-v2/01-networking/traefik-endpoints.yaml



# Verify Domain
if [ -f "k8s-platform-v2/04-configs/global-config.env" ]; then
    source k8s-platform-v2/04-configs/global-config.env
    echo "---------------------------------------------------"
    echo "DEPLOYMENT TARGET: $INGRESS_DOMAIN"
    echo "TRAEFIK INTERNAL IP: $TRAEFIK_IP"
    echo "---------------------------------------------------"
    read -p "Is this specific configuration correct for this server? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 1
    fi
else
    echo "Warning: global-config.env not found!"
fi

# Deploy
echo "Deploying Stack..."
kubectl kustomize --enable-helm ./k8s-platform-v2 | sed "s/\$(INGRESS_DOMAIN)/$INGRESS_DOMAIN/g" | kubectl apply -f -

# Revert placeholder to keep git clean (optional, but good practice if commited)
# sed -i "s/$TRAEFIK_IP/TRAEFIK_IP_PLACEHOLDER/g" ./k8s-platform-v2/01-networking/traefik-endpoints.yaml
echo "Waiting for Resources..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n default || echo "MinIO wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n default || echo "Postgres wait timed out"
kubectl wait --for=condition=available --timeout=300s deployment/traefik -n kube-system || echo "Traefik wait timed out (might be Helm managed or DaemonSet)"

echo "Restarting Dashboard Gateway to apply configurations..."
kubectl rollout restart deployment kubernetes-dashboard-kong -n kubernetes-dashboard || true

echo "Deployment Complete!"
echo "Check status with: kubectl get pods"
