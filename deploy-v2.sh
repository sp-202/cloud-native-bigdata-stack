#!/bin/bash
# -------------------------------------------------------
# deploy-v2.sh — GitOps bootstrap helper
#
# This script does NOT apply manifests directly.
# ArgoCD owns all resources — it reads everything from git
# via kustomize (global-config.env is the single source of truth).
#
# What this script does:
#   1. Installs Traefik (CRDs must exist before ArgoCD first sync)
#   2. Pre-installs Prometheus Operator CRDs (same reason)
#   3. Pre-creates cloudflared-credentials Secret (cannot be in git)
#   4. Creates/updates the ArgoCD Application CR
#
# Run this once after the cluster is up (post-cluster-bootstrap.sh
# already does all of this — use deploy-v2.sh only for re-running
# against an existing cluster or for manual bootstrapping).
# -------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------
# Load secrets (.env.local takes precedence over .env)
# ---------------------------------------------------
if [ -f .env ]; then
  source .env
fi
if [ -f .env.local ]; then
  source .env.local
fi

# Connectivity check
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "ERROR: kubectl is not connected to a cluster."
  exit 1
fi
echo "Cluster connected."

# ---------------------------------------------------
# 1. Traefik — must be installed before ArgoCD sync
#    so IngressRoute/ServersTransport CRDs exist
# ---------------------------------------------------
echo "==> Installing Traefik..."
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update traefik
helm upgrade --install traefik traefik/traefik \
  --namespace kube-system \
  --timeout 10m \
  -f k8s-platform-v2/01-networking/values-traefik.yaml
kubectl patch svc traefik -n kube-system \
  -p '{"spec":{"ports":[{"name":"traefik","port":9000,"targetPort":8080}]}}' || true

# ---------------------------------------------------
# 2. Prometheus Operator CRDs — must exist before
#    ArgoCD sync so cloudflared-servicemonitor.yaml
#    (ServiceMonitor CRD) can be applied
# ---------------------------------------------------
echo "==> Pre-installing Prometheus Operator CRDs..."
PROM_CRD_BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.71.2/example/prometheus-operator-crd"
for crd in \
  monitoring.coreos.com_alertmanagerconfigs.yaml \
  monitoring.coreos.com_alertmanagers.yaml \
  monitoring.coreos.com_podmonitors.yaml \
  monitoring.coreos.com_probes.yaml \
  monitoring.coreos.com_prometheusagents.yaml \
  monitoring.coreos.com_prometheuses.yaml \
  monitoring.coreos.com_prometheusrules.yaml \
  monitoring.coreos.com_scrapeconfigs.yaml \
  monitoring.coreos.com_servicemonitors.yaml \
  monitoring.coreos.com_thanosrulers.yaml; do
  kubectl apply --server-side -f "${PROM_CRD_BASE}/${crd}" 2>/dev/null || true
done
echo "Waiting for CRD API registration..."
sleep 5

# ---------------------------------------------------
# 3. cloudflared-credentials Secret (cannot be in git)
# ---------------------------------------------------
if [ -z "${CF_TUNNEL_ID:-}" ] || [ -z "${CF_TUNNEL_CREDENTIALS:-}" ] || [ -z "${CF_DOMAIN:-}" ]; then
  echo "ERROR: CF_TUNNEL_ID, CF_TUNNEL_CREDENTIALS, and CF_DOMAIN must be set in .env or .env.local"
  exit 1
fi

echo "==> Pre-creating cloudflared-credentials Secret..."
kubectl create namespace cloudflare 2>/dev/null || true
CF_TUNNEL_CREDS_JSON=$(echo "$CF_TUNNEL_CREDENTIALS" | base64 -d)
kubectl create secret generic cloudflared-credentials \
  --namespace cloudflare \
  --from-literal=credentials.json="$CF_TUNNEL_CREDS_JSON" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "cloudflared-credentials Secret ready."

# ---------------------------------------------------
# 4. Patch argocd-cm to enable helm in kustomize builds
#    (needed for helmCharts: in sub-kustomizations)
# ---------------------------------------------------
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}' 2>/dev/null || true

# ---------------------------------------------------
# 5. ArgoCD Application CR
#    ArgoCD syncs everything from git — no kubectl apply needed.
# ---------------------------------------------------
echo "==> Applying ArgoCD Application (k8s-platform-v2)..."
kubectl apply -f - <<'ARGOEOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-platform-v2
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sp-202/cloud-native-bigdata-stack.git
    targetRevision: HEAD
    path: k8s-platform-v2
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
  ignoreDifferences:
    - group: ""
      kind: Secret
      name: cloudflared-credentials
      namespace: cloudflare
      jsonPointers:
        - /data
ARGOEOF

echo ""
echo "=================================================="
echo "Bootstrap complete! ArgoCD is now syncing from git."
echo "Watch: kubectl get application k8s-platform-v2 -n argocd -w"
echo "Logs:  kubectl logs -n argocd argocd-application-controller-0 --tail=50"
echo ""
echo "Services (once sync completes):"
echo "  ArgoCD:       https://argocd.${CF_DOMAIN}"
echo "  Grafana:      https://grafana.${CF_DOMAIN}"
echo "  Airflow:      https://airflow.${CF_DOMAIN}"
echo "  JupyterHub:   https://jupyterhub.${CF_DOMAIN}"
echo "  Superset:     https://superset.${CF_DOMAIN}"
echo "  MinIO:        https://minio.${CF_DOMAIN}"
echo "  Spark:        https://spark.${CF_DOMAIN}"
echo "  Hubble:       https://hubble.${CF_DOMAIN}"
echo "  Traefik:      https://traefik.${CF_DOMAIN}"
echo "=================================================="
