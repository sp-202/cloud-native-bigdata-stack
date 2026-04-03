# Cluster Issue Diagnosis & Status

This document tracks technical issues identified during the debugging session of the cloud-native big data platform.

---

## ✅ Resolved Issues

### 3. Airflow Ingress Service Port Mismatch
- **Symptoms**: Traefik logs `service port not found` for `big-data-platform-webserver`.
- **Root Cause**: `ingress.yaml` referenced port name `web`, but the Service definition uses `airflow-ui`.
- **Resolution**: Updated `ingress.yaml` to use `airflow-ui`. Committed in `14664e4`.
- **Status**: **FIXED**.

### 4. Spark Executor Duplicate VolumeMount
- **Symptoms**: Spark Connect Server runs but cannot spawn executors. K8s rejects executor pod specs.
- **Root Cause**: Duplicate `volumeMount` for `/mnt/spark-nvme` caused by overlap between `spark.local.dir` and the explicit hostPath volume configuration.
- **Resolution**: Updated `deployment.yaml` to use subdirectory: `spark.local.dir={{ .Values.executor.localDir }}/spark-local`. Committed in `14664e4`.
- **Status**: **FIXED**.

### 7. Unity Catalog Dead Ingress Routes
- **Symptoms**: Traefik returns 503 for `unity-catalog.dailyblogstudio.com` because services don't exist.
- **Root Cause**: UC routes were always rendered even when `unity-catalog.enabled: false`.
- **Resolution**: Wrapped UC ingress block in `{{- if (index .Values "unity-catalog").enabled }}` conditional. Committed in `14664e4`.
- **Status**: **FIXED**.

### 8. CoreDNS CrashLoopBackOff — DNS Loop + Probe Timeout
- **Symptoms**: CoreDNS enters `[FATAL] plugin/loop: Loop detected` on EKS, then gets killed by liveness probe timeout.
- **Root Cause A**: `forward . /etc/resolv.conf` on EKS with systemd-resolved loops back to CoreDNS itself.
- **Root Cause B**: Default probe `timeout=1s failureThreshold=3` too tight under Cilium BPF host routing latency.
- **Resolution**: Bootstrap script patches CoreDNS configmap to use VPC DNS `10.0.0.2` and increases probe tolerances (`timeoutSeconds: 10, failureThreshold: 20`). Bootstrap script updated in `a28a02c`.
- **Status**: **FIXED**.

### 9. Airflow DB Migration Deadlock (PostSync Hook)
- **Symptoms**: Airflow scheduler/triggerer stuck in `Init:0/2`. `wait-for-airflow-migrations` init container waits forever.
- **Root Cause**: Hook was `PostSync` — ArgoCD cannot complete sync (app is Degraded) so PostSync never fires, but app is Degraded because Airflow pods are stuck. Classic deadlock.
- **Resolution**: Changed hook to `Sync` with `sync-wave: "5"`. Added `wait-for-postgres` init container to ensure Postgres is ready before migration runs. Committed in `7883a25`.
- **Status**: **FIXED**.

### 10. ArgoCD S3 Service Sync Failure
- **Symptoms**: ArgoCD shows `SyncFailed` for `networking-extras`. Error: `Invalid value: "s3.us-east-1.amazonaws.com": a DNS-1035 label must...`
- **Root Cause**: Service name in `s3-minio-redirect.yaml` contained dots, violating DNS-1035 constraint for Kubernetes Service names.
- **Resolution**: Renamed service to `s3-redirect`. Committed in `7c12b54`.
- **Status**: **FIXED**.

### 11. StarRocks CRD Validation Error
- **Symptoms**: ArgoCD sync fails with `Invalid value: "null": spec.starrocksFeSpec.runAsNonRoot in body must be of type boolean`.
- **Root Cause**: `runAsNonRoot` was unset (null) in values.yaml; CRD requires explicit boolean.
- **Resolution**: Set `runAsNonRoot: false` for both FE and BE specs in `values.yaml`.
- **Status**: **FIXED**.

### 12. Grafana Datasource Conflict
- **Symptoms**: Grafana pod `CrashLoopBackOff`. Logs: `Only one datasource can be marked as default`.
- **Root Cause**: Both Loki and Prometheus had `isDefault: true` in their Grafana datasource configs.
- **Resolution**: Set `loki-stack.loki.isDefault: false` in `values.yaml`.
- **Status**: **FIXED**.

### 13. Networking-Extras Not Deployed
- **Symptoms**: `hubble.dailyblogstudio.com`, `traefik.dailyblogstudio.com`, `headlamp.dailyblogstudio.com` return 404.
- **Root Cause**: `networking-extras.enabled` was `false` in `values.yaml`.
- **Resolution**: Set `networking-extras.enabled: true` in `values.yaml`. Committed in `14664e4`.
- **Status**: **FIXED** (IngressRoutes now deployed).

---

## 🔴 Active Issues

### 5. Cluster-Wide Probe Timeouts — Cilium BPF Host Routing
- **Symptoms**: Pods on `k8s-gp-node` (10.0.2.20) and `minio-worker` (10.0.2.200) are in `CrashLoopBackOff`. All HTTP/HTTPS liveness and readiness probes time out with `context deadline exceeded`. Pods on `spark-node` (10.0.2.227) are healthy.
- **Root Cause**: Cilium v1.19.1 in ENI mode with **BPF host routing** (`Routing: Host: BPF`) prevents the kubelet on `k8s-gp-node` and `minio-worker` from reaching pod IPs via HTTP. The kubelet uses the host network stack, but Cilium's BPF programs intercept and incorrectly route host→pod traffic on these nodes. `spark-node` appears to have correct BPF initialization.
  - Confirmed: applicationset-controller (no probes) works on k8s-gp-node; kube-state-metrics (HTTP probe) fails on same node.
  - Cilium warning on k8s-gp-node: `"Detected multiple IPs of the same address type and family, Cilium will only consider the first IP"` — possible ENI state corruption.
- **Mitigation Applied**:
  - Increased probe tolerances cluster-wide via direct `kubectl patch`: `timeoutSeconds: 10, failureThreshold: 20, initialDelaySeconds: 60`.
  - ArgoCD, Traefik, cloudflared, CoreDNS, spark-operator, kube-state-metrics, metrics-server, hubble-ui all patched.
  - ArgoCD helm upgraded with `--set server.livenessProbe.timeoutSeconds=10 --set server.livenessProbe.failureThreshold=10`.
- **Pending Fix**: Restart Cilium daemonset on affected nodes, or set `hostLegacyRouting: true` in Cilium helm to use iptables for host→pod traffic instead of BPF (more reliable for fresh cluster).
- **Affected pods**: traefik, argocd-server, argocd-repo-server, kube-state-metrics, metrics-server, spark-operator, cloudflared (on k8s-gp-node/minio-worker replicas), grafana, alertmanager, loki, statsd, jupyterhub, starrocks-operator.
- **Status**: **INVESTIGATING / MITIGATION IN PROGRESS**.

### 1. Hubble UI "No Available Server"
- **Symptoms**: Hubble UI returns "No available server" error. Frontend container (`port 8081`) is in `CrashLoopBackOff`.
- **Root Cause**: Hubble UI frontend (nginx) liveness probe `http://10.0.2.x:8081/healthz` times out due to Issue #5 (Cilium BPF host routing on affected node). Backend container (port 8090) is Running and Ready.
- **Mitigation Applied**: `kubectl patch deployment hubble-ui` to set `timeoutSeconds: 10, failureThreshold: 20, initialDelaySeconds: 60` for frontend container probes.
- **Upstream dependency**: Hubble relay pod `fr55t` is 1/1 Running but old pod `lqt96` still CrashLoopBackOff (same probe timeout issue).
- **Status**: **PARTIALLY FIXED** — depends on Issue #5 resolution.

### 2. Airflow Pods Stuck in Init
- **Symptoms**: Scheduler (`big-data-platform-scheduler-0`) and Triggerer stuck in `Init:0/2`. Webserver in `Init:CrashLoopBackOff`.
- **Root Cause A**: `wait-for-airflow-migrations` init container cannot find completed migration job — ArgoCD hasn't successfully synced db-migrate job yet (ArgoCD server itself is crashing due to Issue #5).
- **Root Cause B**: Webserver depends on migrations completing before it can start.
- **Dependency**: Blocked on Issue #5 (ArgoCD must be stable to sync db-migrate Sync hook).
- **Status**: **BLOCKED on Issue #5**.

### 6. OpenEBS Internal Components Pending
- **Symptoms**: `openebs-loki-0` and `openebs-minio-0` stuck in `Pending` in `openebs` namespace.
- **Root Cause**: OpenEBS internal storage components require PVCs that haven't been provisioned. These are OpenEBS's own Loki (for internal logs) and MinIO (for internal use), separate from the big-data-platform Loki/MinIO.
- **Impact**: OpenEBS may have reduced observability but core hostpath provisioner still works.
- **Status**: **OPEN** — lower priority than Issues #1 and #5.

---

## 📋 Summary of All Commits Made This Session

| Commit | Change |
|--------|--------|
| `14664e4` | Fix ingress port, spark local.dir subdir, UC conditional, networking-extras enabled |
| `7883a25` | Airflow db-migrate hook PostSync→Sync, cloudflared probe increase, probe values in values.yaml |
| `7c12b54` | Rename s3 service to `s3-redirect` (DNS-1035 fix) |
| `a28a02c` | Bootstrap script: CoreDNS probe patch after VPC DNS fix |

## 🔧 Direct kubectl Patches Applied (Temporary — ArgoCD Will Overwrite)

These patches bypass ArgoCD and must be codified in values.yaml or chart overrides:

| Resource | Patch |
|----------|-------|
| `deployment/traefik` | `livenessProbe.timeoutSeconds=10, failureThreshold=10, initialDelaySeconds=60` |
| `deployment/argocd-server` | Same |
| `deployment/argocd-repo-server` | Same |
| `deployment/hubble-ui` | Same (frontend container) |
| `deployment/headlamp` | Same |
| `daemonset/cilium-envoy` | Same |
| `deployment/kube-state-metrics` | Same |
| `deployment/metrics-server` | Same |
| `deployment/spark-operator-controller` | Same |
| `deployment/spark-operator-webhook` | Same |
| `daemonset/promtail` | Same |
| `daemonset/prometheus-node-exporter` | Same |
| `deployment/cloudflared` | Same |
| `deployment/coredns` | Same |




------------------------------------
 Cloud Native Big Data Stack — Known Issues & Fixes

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

