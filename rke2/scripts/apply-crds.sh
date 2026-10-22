#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Pre-installs the CRDs (and two bootstrap objects) the big-data-platform
# Application needs on its first sync. Ported from terraform-aws-k8s-ha
# scripts/post-apply-crds.sh; called by bootstrap-platform.sh, safe to re-run.
#
# Why outside Argo CD: argocd-cm excludes CustomResourceDefinition from
# management (helm-values/argocd.yaml), because the Spark Operator CRDs
# (~800 KB each) exceed the 262 KB last-applied annotation limit and only
# server-side apply can install them. Versions MUST track
# big-data-platform/Chart.yaml — whatever lands here is what the cluster
# keeps until this script is re-run.
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/lib.sh"

SPARK_OPERATOR_VERSION="2.4.0"
CNPG_CHART_VERSION="0.29.0"
CERT_MANAGER_VERSION="v1.16.2"
STARROCKS_VERSION="1.9.8"
KPS_VERSION="56.6.2"
STRIMZI_VERSION="0.48.0"
NS="${PLATFORM_NAMESPACE:-default}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ssa() { kubectl apply --server-side --force-conflicts "$@"; }

pull() {  # pull <chart> <version> <repo>
  helm pull "$1" --version "$2" --repo "$3" --untar --untardir "$WORK/$1" \
    || die "helm pull $1 $2 failed"
}
apply_crd_dirs() {  # every */crds/*.yaml under a pulled chart, minus chart metadata
  find "$1" -name "*.yaml" -path "*/crds/*" -not -name Chart.yaml -not -name values.yaml -print0 \
    | xargs -0 -r -n1 kubectl apply --server-side --force-conflicts -f
}

log "Spark Operator $SPARK_OPERATOR_VERSION CRDs"
pull spark-operator "$SPARK_OPERATOR_VERSION" https://kubeflow.github.io/spark-operator
ssa -f "$WORK/spark-operator/spark-operator/crds/"

log "CloudNativePG chart $CNPG_CHART_VERSION CRDs"
# 0.23+: CRDs live in templates/crds/crds.yaml behind .Values.crds.create —
# render, don't kubectl the raw template.
pull cloudnative-pg "$CNPG_CHART_VERSION" https://cloudnative-pg.github.io/charts
helm template cloudnative-pg "$WORK/cloudnative-pg/cloudnative-pg" -s templates/crds/crds.yaml | ssa -f -

# The operator only PATCHES its CA bundle onto these two objects and exits
# ("unable to setup PKI infrastructure") if they don't exist; Argo CD applies
# them after the Deployment, which never gets healthy without them. Pre-create
# them (Argo CD adopts them afterwards).
log "CloudNativePG webhook configurations (first-boot deadlock breaker)"
helm template cloudnative-pg "$WORK/cloudnative-pg/cloudnative-pg" --namespace "$NS" \
  --set fullnameOverride=cloudnative-pg \
  -s templates/validatingwebhookconfiguration.yaml -s templates/mutatingwebhookconfiguration.yaml | ssa -f -
# timeoutSeconds 10 -> 30 (the K8s max). A JSON patch, not a re-apply of the
# fetched object: server-side apply rejects objects carrying managedFields.
# The Application's ignoreDifferences keeps Argo CD from reverting it.
for kind in validatingwebhookconfiguration mutatingwebhookconfiguration; do
  name="cnpg-${kind%webhookconfiguration}-webhook-configuration"
  n=$(kubectl get "$kind" "$name" -o json | jq '.webhooks | length')
  ops=$(jq -nc --argjson n "$n" '[range(0;$n) | {op:"replace", path:"/webhooks/\(.)/timeoutSeconds", value:30}]')
  kubectl patch "$kind" "$name" --type=json -p "$ops" >/dev/null
done

log "cert-manager $CERT_MANAGER_VERSION CRDs"
ssa -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml"

log "StarRocks operator $STARROCKS_VERSION CRDs"
pull kube-starrocks "$STARROCKS_VERSION" https://starrocks.github.io/starrocks-kubernetes-operator
apply_crd_dirs "$WORK/kube-starrocks"

log "kube-prometheus-stack $KPS_VERSION (Prometheus Operator) CRDs"
pull kube-prometheus-stack "$KPS_VERSION" https://prometheus-community.github.io/helm-charts
apply_crd_dirs "$WORK/kube-prometheus-stack"
kubectl wait --for=condition=Established --timeout=120s crd/servicemonitors.monitoring.coreos.com >/dev/null

log "Strimzi $STRIMZI_VERSION CRDs (Kafka, KafkaNodePool, KafkaTopic, ...)"
helm pull oci://quay.io/strimzi-helm/strimzi-kafka-operator --version "$STRIMZI_VERSION" \
  --untar --untardir "$WORK/strimzi" || die "helm pull strimzi-kafka-operator $STRIMZI_VERSION failed"
ssa -f "$WORK/strimzi/strimzi-kafka-operator/crds/"

# prometheus-operator's pod mounts this Secret, which cert-manager only
# creates once its own webhook is up and the Issuer chain has reconciled —
# the operator sits in ContainerCreating until then. A self-signed cert
# breaks the deadlock; cert-manager/Argo CD take over afterwards. Only
# created when missing.
if ! kubectl get secret kube-prometheus-stack-admission -n "$NS" >/dev/null 2>&1; then
  log "kube-prometheus-stack-admission bootstrap TLS Secret"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/tls.key" -out "$WORK/tls.crt" -days 3650 \
    -subj "/CN=kube-prometheus-stack-operator" \
    -addext "subjectAltName=DNS:kube-prometheus-stack-operator,DNS:kube-prometheus-stack-operator.${NS}.svc" 2>/dev/null
  kubectl create secret tls kube-prometheus-stack-admission -n "$NS" --cert="$WORK/tls.crt" --key="$WORK/tls.key"
fi

log "CRDs ready"
