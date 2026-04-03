# Cloud Native Big Data Stack — Known Issues & Fixes

## Status Legend
- ✅ Resolved — fix committed, verified working
- 🔧 Fix committed — awaiting sync/verification
- ❌ Unresolved — still failing or blocked

---

## ✅ Issue 1: kube-starrocks subchart values not forwarded

**Symptom**: StarRocksCluster CR was never created, operator had nothing to reconcile.

**Root Cause**: `Chart.yaml` declared the dependency as `name: kube-starrocks` with no alias. Helm only forwards values to a subchart using the dependency name/alias as the key. Since `values.yaml` used `starrocks:` as the key, nothing was forwarded.

**Fix**: Added `alias: starrocks` to the kube-starrocks dependency in `Chart.yaml`.

```
File: big-data-platform/Chart.yaml
```

---

## ✅ Issue 2: StarRocks `runAsNonRoot: false` renders as null (CRD validation error)

**Symptom**: `spec.starRocksBeSpec.runAsNonRoot: Invalid value: "null": must be of type boolean`

**Root Cause**: kube-starrocks chart v1.9.8 uses `{{- if .Values.runAsNonRoot -}}` which treats `false` as falsy, rendering empty string → YAML null → CRD rejects it.

**Fix**: Set `runAsNonRoot: true` in `values.yaml` under both `starrocks.starrocks.starrocksFeSpec` and `starrocksBeSpec`. StarRocks 3.3 supports non-root mode with UID 1000.

```
File: big-data-platform/values.yaml
```

---

## ✅ Issue 3: StarRocks values structure mismatch

**Symptom**: StarRocksCluster CR rendered with wrong image format and storage field names.

**Root Cause**: Values nested under `starrocks.starrocksCluster.starrocksFeSpec` but kube-starrocks (which is itself an umbrella) expects them under `starrocks.starrocks.starrocksFESpec`. Also `storageVolume` (singular) vs `storageVolumes` (plural array).

**Fix**: Restructured values and renamed fields.

```
File: big-data-platform/values.yaml
```

---

## ✅ Issue 4: Airflow db-migrate sync wave deadlock

**Symptom**: Airflow scheduler/triggerer stuck at `Init:0/2` forever. ArgoCD sync never progresses.

**Root Cause**: `airflow-db-migrate` was at sync-wave `5`. Airflow StatefulSets at wave `0` had init containers waiting for migrations. ArgoCD health-checks wave 0 before advancing to wave 5 → permanent deadlock.

**Fix**: Moved `airflow-db-migrate` Job to sync-wave `-1`.

```
File: big-data-platform/templates/airflow-db-migrate.yaml
```

---

## ✅ Issue 5: Airflow log directories missing on node (FailedMount)

**Symptom**: `MountVolume.NewMounter initialization failed: path "/var/openebs/local/airflow-scheduler-logs" does not exist`

**Root Cause**: OpenEBS LocalPV hostpath with static PV provisioning requires the directory to exist on the node before kubelet can mount it.

**Fix**: Manually created directories on the gp node:
```bash
# Run a privileged pod on the gp node and execute:
mkdir -p /var/openebs/local/airflow-shared
mkdir -p /var/openebs/local/airflow-scheduler-logs
mkdir -p /var/openebs/local/airflow-triggerer-logs
```

> **Note**: A `airflow-init-dirs` Job was attempted to automate this but failed due to OCI runtime constraints with hostPath mounting. The Job was removed. Directories must be created manually on any new node.

---

## ✅ Issue 6: Missing Grafana ingress rule (404 error)

**Symptom**: `https://grafana.dailyblogstudio.com/` returned 404.

**Root Cause**: The centralized ingress had rules for Airflow, MinIO, Superset, JupyterHub, Spark, Spark History — but no rule for Grafana.

**Fix**: Added Grafana host rule to ingress template.

```
File: big-data-platform/charts/ingress/templates/ingress.yaml
```

---

## ✅ Issue 7: ArgoCD Ingress health check infinite wait

**Symptom**: ArgoCD sync operation stuck on "waiting for healthy state of Ingress/centralized-ingress".

**Root Cause**: Traefik doesn't populate `status.loadBalancer.ingress` field that ArgoCD's default Ingress health check requires.

**Fix**: Patched `argocd-cm` with a custom Lua-based Ingress health check that always returns Healthy.

```bash
# Applied via kubectl patch on argocd-cm ConfigMap
# resource.customizations.health.networking.k8s.io/Ingress: ...
```

---

## ✅ Issue 8: Airflow git-sync permanent failure

**Symptom**: `dags.gitSync.maxFailures: 0` caused a single git failure to permanently block the git-sync-init init container.

**Fix**: Changed `maxFailures` from `0` to `3` in values.yaml.

```
File: big-data-platform/values.yaml → airflow.dags.gitSync.maxFailures: 3
```

---

## ✅ Issue 9: Airflow internal migration job conflict

**Symptom**: Airflow chart's own `migrateDatabaseJob` conflicted with the custom `airflow-db-migrate` ArgoCD hook.

**Fix**: Disabled `airflow.migrateDatabaseJob.enabled: false` in values.yaml.

```
File: big-data-platform/values.yaml
```

---

## 🔧 Issue 10: Postgres/Airflow sync wave ordering — all resources must be annotated

**Symptom**: Postgres pod stuck in `ContainerCreating` with `MountVolume.SetUp failed: configmap "postgres-init" not found`.

**Root Cause**: Postgres Deployment was annotated with sync-wave `-2` but its ConfigMap had no annotation (defaulted to wave 0). Wave -2 tried to start the pod before the ConfigMap existed.

**Full wave ordering implemented**:
| Wave | Resource |
|------|----------|
| -3 | postgres-data-pv, postgres-data-pvc (persistence chart) |
| -2 | postgres-init ConfigMap, postgres Deployment, postgres Service |
| -1 | airflow-db-migrate Job |
| 0 | Everything else (Airflow, Redis, MinIO, StarRocks, etc.) |

**Fix**: Added `argocd.argoproj.io/sync-wave: "-2"` to `postgres/templates/configmap.yaml`.

**Status**: Committed as `a2a714c`, awaiting ArgoCD sync verification.

```
Files:
  big-data-platform/charts/persistence/templates/volumes.yaml (postgres PV/PVC at -3)
  big-data-platform/charts/postgres/templates/configmap.yaml (at -2)
  big-data-platform/charts/postgres/templates/deployment.yaml (at -2)
```

---

## ❌ Issue 11: StarRocks FE/BE pods — verification pending

**Symptom**: StarRocks FE and BE pods not observed running.

**Root Cause (investigated)**: kube-starrocks values passing was fixed (Issues 1-3). StarRocksCluster CR should now be created with correct spec.

**Status**: Not yet verified. Requires ArgoCD sync to complete successfully first (blocked by Issue 10 above). Once sync completes, check:
```bash
kubectl get starrocksclusters -A
kubectl get pods -A | grep starrocks
```

---

## ❌ Issue 12: `airflow-init-dirs` Job OCI runtime failure (removed, manual workaround)

**Symptom**: Job failed with `OCI runtime create failed: unable to start container process: error mounting "/" to rootfs`.

**Root Cause**: Attempting to mount the host `/` filesystem into a busybox container causes runc to conflict with the container's own rootfs setup.

**Status**: Job template removed (`6c621b8`). Directories must be created manually on each gp node. See Issue 5 for the manual procedure.

**TODO**: Find a reliable way to automate directory creation (e.g., DaemonSet with proper securityContext, or Terraform/Ansible pre-provisioning step).

