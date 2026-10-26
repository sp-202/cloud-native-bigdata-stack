#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Step 2 of 2: install the platform on the RKE2 cluster, GitOps-style.
# Replaces terraform-aws-k8s-ha's argocd.tf / helm-addons.tf / k8s-secrets.tf
# / post-apply-crds.sh. Run from this machine after rke2/install-cluster.sh.
# Idempotent — re-run any time (upgrades the Helm releases, never rotates
# existing secrets).
#
#   1. OpenEBS local PV + StorageClass `local-storage` (default)   helm
#   2. Traefik DaemonSet on :80/:443                               helm
#   3. Argo CD                                                     helm
#   4. Secrets (generated once, kept in the cluster only)          kubectl
#   5. AppProject + SeaweedFS Application, wait Healthy            Argo CD
#   6. S3 buckets in SeaweedFS                                     Job
#   7. CRDs the platform's first sync needs                        scripts/apply-crds.sh
#   8. big-data-platform Application (this repo, GIT_REVISION)     Argo CD
#
# Everything after step 3 is reconciled by Argo CD from git; edit
# big-data-platform/values.yaml, push, and Argo CD syncs it.
#
# Env overrides: CLUSTER_ENV (path to cluster.env), WAIT_PLATFORM=0 (don't
# wait for the platform sync at the end).
# -----------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
load_env
need_cmd kubectl helm openssl jq
use_kubeconfig

OPENEBS_VERSION="4.3.3"
TRAEFIK_VERSION="26.1.0"
# Argo CD v3.4.6. 3.x is needed for its bundled Helm >= 3.17 (fromToml, used
# by the seaweedfs chart); 2.14 ships Helm 3.16.
ARGOCD_VERSION="10.2.2"
NS=default
S3_ENDPOINT="http://seaweedfs-filer.storage.svc.cluster.local:8333"
S3_ENDPOINT_HOST="seaweedfs-filer.storage.svc.cluster.local:8333"
S3_REGION="us-east-1"
BUCKETS=(lakehouse loki)

# Profile: "full" = big-data-platform/values.yaml as-is (4 nodes);
# "2node" = + values-2node.yaml (test subset) and the 2-node SeaweedFS layout.
PLATFORM_PROFILE="${PLATFORM_PROFILE:-full}"
case "$PLATFORM_PROFILE" in
  full)  VALUE_FILES=(values.yaml);                   SEAWEEDFS_APP="$RKE2_DIR/argocd/seaweedfs.yaml" ;;
  2node) VALUE_FILES=(values.yaml values-2node.yaml); SEAWEEDFS_APP="$RKE2_DIR/argocd/seaweedfs-2node.yaml" ;;
  *) die "PLATFORM_PROFILE must be full or 2node" ;;
esac

# ---------------------------------------------------------------- preflight
log "preflight"
kubectl get nodes >/dev/null || die "cannot reach the cluster with $KUBECONFIG"
archs=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.nodeInfo.architecture}{"\n"}{end}' | sort -u)
[ "$archs" = "amd64" ] || die "expected only amd64 nodes, got: $(echo "$archs" | tr '\n' ' ')"
notready=$(kubectl get nodes --no-headers | awk '$2 !~ /^Ready/ {print $1}')
[ -z "$notready" ] || die "nodes not Ready: $notready"
log "nodes: $(kubectl get nodes --no-headers | wc -l) Ready, amd64. Domain: *.${DOMAIN}. Profile: ${PLATFORM_PROFILE}"

# ---------------------------------------------------------------- 1. storage
log "OpenEBS $OPENEBS_VERSION (local PV: hostpath$( [ "$STORAGE_BACKEND" = lvm ] && echo ' + LVM'))"
helm upgrade --install openebs openebs --repo https://openebs.github.io/openebs --version "$OPENEBS_VERSION" \
  --namespace openebs --create-namespace \
  -f "$RKE2_DIR/helm-values/openebs.yaml" \
  --set "engines.local.lvm.enabled=$( [ "$STORAGE_BACKEND" = lvm ] && echo true || echo false)" \
  --set "localpv-provisioner.localpv.basePath=${HOSTPATH_BASE:-/var/openebs/local}" \
  --wait --timeout 10m

if [ "$STORAGE_BACKEND" = lvm ]; then
  WANT_PROVISIONER="local.csi.openebs.io"
  SC_YAML=$(cat <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: local.csi.openebs.io
parameters:
  storage: lvm
  volgroup: "${LVM_VG:-openebs-vg}"
  fsType: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
)
else
  WANT_PROVISIONER="openebs.io/local"
  SC_YAML=$(cat <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    openebs.io/cas-type: local
    cas.openebs.io/config: |
      - name: StorageType
        value: hostpath
      - name: BasePath
        value: "${HOSTPATH_BASE:-/var/openebs/local}"
provisioner: openebs.io/local
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
)
fi
have=$(kubectl get storageclass local-storage -o jsonpath='{.provisioner}' 2>/dev/null || true)
if [ -n "$have" ] && [ "$have" != "$WANT_PROVISIONER" ]; then
  die "StorageClass local-storage already uses $have, but STORAGE_BACKEND=$STORAGE_BACKEND wants $WANT_PROVISIONER. StorageClasses are immutable and existing PVCs depend on it — keep the old backend, or delete every PVC and the StorageClass first."
fi
log "StorageClass local-storage -> $WANT_PROVISIONER (default)"
# Nothing else may stay default, or PVCs without a class pick at random.
for sc in $(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}' | awk '$2=="true" && $1!="local-storage" {print $1}'); do
  kubectl annotate storageclass "$sc" storageclass.kubernetes.io/is-default-class=false --overwrite
done
echo "$SC_YAML" | kubectl apply -f -

# ---------------------------------------------------------------- 2. ingress
log "Traefik $TRAEFIK_VERSION (DaemonSet, hostPorts 80/443)"
helm upgrade --install traefik traefik --repo https://traefik.github.io/charts --version "$TRAEFIK_VERSION" \
  --namespace kube-system -f "$RKE2_DIR/helm-values/traefik.yaml" --wait --timeout 10m

# ---------------------------------------------------------------- 3. Argo CD
log "Argo CD (chart $ARGOCD_VERSION)"
helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version "$ARGOCD_VERSION" \
  --namespace argocd --create-namespace -f "$RKE2_DIR/helm-values/argocd.yaml" --wait --timeout 15m

# ---------------------------------------------------------------- 4. secrets
# Generated once; an existing Secret is never regenerated (rotating a DB
# password under a live Postgres locks the app out). Hex/urlsafe values only,
# so they are safe inside URLs, JSON and sed replacements.
log "platform secrets (create-if-missing)"
gen_hex() { openssl rand -hex "${1:-24}"; }
secret_get() {  # secret_get <ns> <name> <key>  -> value or empty
  kubectl get secret -n "$1" "$2" -o json 2>/dev/null | jq -r --arg k "$3" '.data[$k] // empty | @base64d'
}
secret_exists() { kubectl get secret -n "$1" "$2" >/dev/null 2>&1; }
create_secret() {  # create_secret <ns> <name> <type> <key=value>...  (only if missing)
  local ns="$1" name="$2" type="$3"; shift 3
  if secret_exists "$ns" "$name"; then echo "  keep   $ns/$name"; return; fi
  local args=(); for kv in "$@"; do args+=(--from-literal="$kv"); done
  kubectl create secret generic "$name" -n "$ns" --type="$type" "${args[@]}" >/dev/null
  echo "  create $ns/$name"
}
sync_secret() {  # sync_secret <ns> <name> <key=value>...  (always reconciled from the source)
  local ns="$1" name="$2"; shift 2
  local args=(); for kv in "$@"; do args+=(--from-literal="$kv"); done
  kubectl create secret generic "$name" -n "$ns" "${args[@]}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "  sync   $ns/$name"
}
kubectl create namespace storage --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# CNPG superuser + managed roles (basic-auth shape: username/password).
create_secret $NS postgres-superuser kubernetes.io/basic-auth username=postgres "password=$(gen_hex)"
for role in airflow superset gravitino; do
  create_secret $NS "${role}-db-role" kubernetes.io/basic-auth "username=${role}" "password=$(gen_hex)"
done
AIRFLOW_DB_PW=$(secret_get $NS airflow-db-role password)
SUPERSET_DB_PW=$(secret_get $NS superset-db-role password)
GRAVITINO_DB_PW=$(secret_get $NS gravitino-db-role password)

create_secret $NS airflow-credentials Opaque \
  "fernet-key=$(openssl rand -base64 32 | tr '+/' '-_')" \
  "webserver-secret-key=$(gen_hex 32)" \
  "admin-password=$(gen_hex 12)" \
  "connection=postgresql+psycopg2://airflow:${AIRFLOW_DB_PW}@postgres-rw.${NS}.svc.cluster.local:5432/airflow"
create_secret $NS airflow-api-secrets Opaque "api-secret-key=$(gen_hex 32)" "jwt-secret=$(gen_hex 32)"
create_secret $NS superset-credentials Opaque \
  "db-password=${SUPERSET_DB_PW}" "secret-key=$(gen_hex 32)" "admin-password=$(gen_hex 12)"
create_secret $NS grafana-credentials Opaque "admin-user=admin" "admin-password=$(gen_hex 12)"
# MQTT users (charts/iiot): `dcs` for the DCS-side bridge, `telegraf` for both
# Telegraf pipelines. Hashed into Mosquitto's password file at pod start.
create_secret $NS mosquitto-credentials Opaque "dcs-password=$(gen_hex 16)" "telegraf-password=$(gen_hex 16)"

# S3: lakehouse-s3 in `default` is the source of truth for the keys; the
# kube-system copy, the SeaweedFS identity config and the Airflow connection
# are re-derived from it on every run.
create_secret $NS lakehouse-s3 Opaque \
  "AWS_ACCESS_KEY_ID=$(openssl rand -hex 10 | tr 'a-f' 'A-F')" \
  "AWS_SECRET_ACCESS_KEY=$(gen_hex 20)" \
  "AWS_REGION=${S3_REGION}" \
  "AWS_ENDPOINT_URL=${S3_ENDPOINT}" \
  "S3_ENDPOINT=${S3_ENDPOINT_HOST}" \
  "bucket=lakehouse"
AK=$(secret_get $NS lakehouse-s3 AWS_ACCESS_KEY_ID)
SK=$(secret_get $NS lakehouse-s3 AWS_SECRET_ACCESS_KEY)
sync_secret kube-system lakehouse-s3 \
  "AWS_ACCESS_KEY_ID=$AK" "AWS_SECRET_ACCESS_KEY=$SK" "AWS_REGION=${S3_REGION}" \
  "AWS_ENDPOINT_URL=${S3_ENDPOINT}" "S3_ENDPOINT=${S3_ENDPOINT_HOST}" "bucket=lakehouse"
sync_secret storage seaweedfs-s3-config "seaweedfs_s3_config=$(jq -nc --arg ak "$AK" --arg sk "$SK" \
  '{identities:[{name:"platform",credentials:[{accessKey:$ak,secretKey:$sk}],actions:["Admin","Read","List","Tagging","Write"]}]}')"
sync_secret $NS airflow-s3-connection "connection=$(jq -nc --arg ak "$AK" --arg sk "$SK" --arg ep "$S3_ENDPOINT" --arg rg "$S3_REGION" \
  '{conn_type:"aws",login:$ak,password:$sk,extra:{endpoint_url:$ep,region_name:$rg,config_kwargs:{s3:{addressing_style:"path"}}}}')"

# ---------------------------------------------------------------- 5. SeaweedFS
log "Argo CD AppProject + SeaweedFS Application"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: big-data-platform
  namespace: argocd
spec:
  description: Cloud-Native Big Data Platform on RKE2 (scoped project, not 'default')
  sourceRepos:
    - ${GIT_REPO}
    - https://seaweedfs.github.io/seaweedfs/helm
  destinations:
    - { server: https://kubernetes.default.svc, namespace: default }
    - { server: https://kubernetes.default.svc, namespace: kube-system }
    - { server: https://kubernetes.default.svc, namespace: argocd }
    - { server: https://kubernetes.default.svc, namespace: cert-manager }
    - { server: https://kubernetes.default.svc, namespace: storage }
  # Operators (CNPG, cert-manager, Spark, StarRocks, prometheus-operator)
  # need ClusterRoles, webhooks, etc. Tighten once the set is observed.
  clusterResourceWhitelist:
    - { group: "*", kind: "*" }
EOF
kubectl apply -f "$SEAWEEDFS_APP"

wait_app() {  # wait_app <name> <minutes>
  local app="$1" mins="$2" st=""
  log "waiting for Argo CD app '$app' (Synced/Healthy, up to ${mins}m)"
  for _ in $(seq 1 $((mins * 6))); do
    st=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
    [ "$st" = "Synced/Healthy" ] && { echo "  $app: $st"; return 0; }
    sleep 10
  done
  warn "$app is '$st' after ${mins}m — inspect: kubectl -n argocd get application $app -o yaml"
  return 1
}
wait_app seaweedfs 15 || die "SeaweedFS must be healthy before the platform (its S3 holds every bucket)"

# ---------------------------------------------------------------- 6. buckets
log "S3 buckets: ${BUCKETS[*]}"
kubectl -n $NS delete job seaweedfs-buckets --ignore-not-found >/dev/null
kubectl -n $NS apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: seaweedfs-buckets
spec:
  backoffLimit: 6
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: aws
          image: amazon/aws-cli:2.37.4
          envFrom:
            - secretRef:
                name: lakehouse-s3
          env:
            - { name: HOME, value: /tmp }
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -e
              # AWS_ENDPOINT_URL (from the Secret) points every call at SeaweedFS.
              for i in \$(seq 1 30); do aws s3 ls >/dev/null 2>&1 && break; echo "waiting for S3..."; sleep 5; done
              for b in ${BUCKETS[*]}; do
                aws s3api head-bucket --bucket "\$b" 2>/dev/null || aws s3 mb "s3://\$b"
              done
              # Spark History Server refuses to start on a log dir that does not exist.
              echo keep | aws s3 cp - s3://lakehouse/spark-events/.keep
              aws s3 ls
EOF
kubectl -n $NS wait --for=condition=complete job/seaweedfs-buckets --timeout=10m \
  || { kubectl -n $NS logs job/seaweedfs-buckets --tail=50 || true; die "bucket job failed"; }
kubectl -n $NS logs job/seaweedfs-buckets --tail=10

# ---------------------------------------------------------------- 7. CRDs
log "CRDs for the platform's first sync"
PLATFORM_NAMESPACE=$NS bash "$RKE2_DIR/scripts/apply-crds.sh"

# ---------------------------------------------------------------- 8. platform
log "big-data-platform Application (${GIT_REPO} @ ${GIT_REVISION}, domain ${DOMAIN})"
# Two Helm parameters only: the domain (cluster-specific, not in git) and
# Gravitino's entity-store JDBC password — the official chart renders that
# into a ConfigMap and has no Secret reference, so it can't be envFrom'd.
# Everything else reads Secrets at runtime.
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: big-data-platform
  namespace: argocd
  # Deleting the Application cascades to everything it manages (PVCs
  # included) instead of orphaning it.
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: big-data-platform
  source:
    repoURL: ${GIT_REPO}
    targetRevision: ${GIT_REVISION}
    path: big-data-platform
    helm:
      valueFiles:
$(for f in "${VALUE_FILES[@]}"; do echo "        - $f"; done)
      parameters:
        - name: global.domain
          value: "${DOMAIN}"
        - name: gravitino.entity.jdbcPassword
          value: "${GRAVITINO_DB_PW}"
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NS}
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
      limit: 10
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 10m
  ignoreDifferences:
    # Traefik never fills Ingress .status.loadBalancer.
    - group: networking.k8s.io
      kind: Ingress
      jsonPointers: ["/status/loadBalancer"]
    # scripts/apply-crds.sh raises CNPG webhook timeouts to 30s; keep selfHeal
    # from reverting them to the chart's 10s.
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      name: cnpg-validating-webhook-configuration
      jqPathExpressions: [".webhooks[].timeoutSeconds"]
    - group: admissionregistration.k8s.io
      kind: MutatingWebhookConfiguration
      name: cnpg-mutating-webhook-configuration
      jqPathExpressions: [".webhooks[].timeoutSeconds"]
EOF

if [ "${WAIT_PLATFORM:-1}" = 1 ]; then
  wait_app big-data-platform 45 || warn "the first sync can take a while (image pulls); re-check with: kubectl -n argocd get applications"
fi

# ---------------------------------------------------------------- summary
log "done"
cat <<EOF
  Argo CD      http://argocd.${DOMAIN}         admin / kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  Airflow      http://airflow.${DOMAIN}        admin / kubectl get secret airflow-credentials -o jsonpath='{.data.admin-password}' | base64 -d
  Grafana      http://grafana.${DOMAIN}        admin / kubectl get secret grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
  Gravitino    http://gravitino.${DOMAIN}
$( [ "$PLATFORM_PROFILE" = full ] && echo "  Spark Hist.  http://spark-history.${DOMAIN}")
  Prometheus   http://prometheus.${DOMAIN}
  Traefik      http://traefik.${DOMAIN}/dashboard/
$( [ "$PLATFORM_PROFILE" = full ] && cat <<FULL
  VictoriaM.   http://victoriametrics.${DOMAIN}/vmui
  StarRocks    http://starrocks.${DOMAIN}        SQL: mysql -h ${INGRESS_IP} -P 30930 -uroot
  MQTT (DCS)   mqtt://${INGRESS_IP}:1883         user dcs / kubectl get secret mosquitto-credentials -o jsonpath='{.data.dcs-password}' | base64 -d
  Kafka (in-cluster) iiot-kafka-bootstrap.${NS}.svc:9092   topic dcs.raw
FULL
)
  S3 (in-cluster) ${S3_ENDPOINT}   keys: kubectl get secret lakehouse-s3 -o yaml

  export KUBECONFIG=${KUBECONFIG}
EOF
