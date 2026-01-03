#!/bin/bash
echo "=== Debugging Kubernetes Dashboard Connectivity ==="

# K3s Configuration Check (Match deploy-v2.sh logic)
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    echo "Detected K3s config. Exporting KUBECONFIG..."
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

echo "1. Checking Dashboard Services..."
# Check in default namespace first (where they currently seem to be)
if kubectl get svc -n default kubernetes-dashboard-web > /dev/null 2>&1; then
    echo "[OK] kubernetes-dashboard-web service exists in 'default' namespace."
    DASH_NS="default"
elif kubectl get svc -n kubernetes-dashboard kubernetes-dashboard-web > /dev/null 2>&1; then
    echo "[OK] kubernetes-dashboard-web service exists in 'kubernetes-dashboard' namespace."
    DASH_NS="kubernetes-dashboard"
else
    echo "[FAIL] kubernetes-dashboard-web service MISSING in both namespaces!"
    DASH_NS=""
fi

echo "2. Checking Traefik Dashboard..."
# Verify Traefik Dashboard accessibility
INGRESS_DOMAIN=$(kubectl get ingress -n default traefik-dashboard-ingress -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
if [ -z "$INGRESS_DOMAIN" ]; then
   echo "[WARN] Traefik Ingress not found or cannot parse host."
else
   echo "Traefik URL: http://$INGRESS_DOMAIN/dashboard/"
   echo "--- Curling /ping ---"
   RESP_PING=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_DOMAIN/ping")
   echo "Ping Response: $RESP_PING"
   
   echo "--- Curling /dashboard/ ---"
   curl -I "http://$INGRESS_DOMAIN/dashboard/"
   
   echo "--- Curling /api/rawdata ---"
   RESP_API=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_DOMAIN/api/rawdata")
   echo "API Response: $RESP_API"
   
   RESP=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_DOMAIN/dashboard/")
   if [ "$RESP" == "200" ] || [ "$RESP" == "302" ] || [ "$RESP" == "304" ]; then
       echo "[OK] Traefik Dashboard reachable (HTTP $RESP)."
   else
       echo "[FAIL] Traefik Dashboard returned HTTP $RESP."
       echo "--- Body Snippet (First 200 chars) ---"
       curl -s "http://$INGRESS_DOMAIN/dashboard/" | head -c 200
       echo ""
   fi
fi

echo "3. Checking Endpoints (Are pods backed?)..."
if [ ! -z "$DASH_NS" ]; then
    kubectl get endpoints -n $DASH_NS kubernetes-dashboard-web
fi
TRAEFIK_EP=$(kubectl get endpoints traefik-external -n default -o jsonpath='{.subsets[*].addresses[*].ip}')
echo "Traefik External Endpoint IP: $TRAEFIK_EP"
if [ -z "$TRAEFIK_EP" ]; then
    echo "[FAIL] Traefik external endpoint is EMPTY!"
fi

echo "4. Checking Pod Status..."
if [ ! -z "$DASH_NS" ]; then
    kubectl get pods -n $DASH_NS | grep dashboard
fi
kubectl get pods -n kubernetes-dashboard | grep kong

echo "5. Checking Kong Gateway Logs (Last 20 lines)..."
kubectl logs -n kubernetes-dashboard -l app.kubernetes.io/name=kong --tail=20

echo "5. Testing Internal DNS (if possible)..."
KONG_POD=$(kubectl get pod -n kubernetes-dashboard -l app.kubernetes.io/name=kong -o jsonpath='{.items[0].metadata.name}')
echo "Kong Pod: $KONG_POD"
# Try resolving short name
echo "Resolving 'kubernetes-dashboard-web.default.svc.cluster.local' inside Kong..."
if kubectl exec -n kubernetes-dashboard $KONG_POD -- getent hosts kubernetes-dashboard-web.default.svc.cluster.local > /dev/null 2>&1; then
   echo "[OK] DNS Resolution worked."
else
   echo "[FAIL] DNS Resolution FAILED inside Kong pod."
fi

echo "=== Debug Complete ==="
