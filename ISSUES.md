# Project Issues & Resolutions Log

## 1. Spark Auto-Initialization Failure (`NameError: name 'spark' is not defined`)

**Issue:**
JupyterHub users (IPython/Notebooks) found that `spark` was not defined on startup, despite `00-pyspark-setup.py` being present.

**Root Cause:**
Spark running in **Client Mode** on Kubernetes requires the Driver Pod to have a resolvable name that matches `spark.kubernetes.driver.pod.name`.
*   The default Pod name is random (e.g., `jupyterhub-78dd...`).
*   Spark failed silently during initialization with `SparkException: No pod was found named spark-driver`, causing the startup script to abort without defining `spark`.

**Resolution:**
Updated `k8s-platform-v2/03-apps/jupyterhub.yaml` (inside `setup-kernels.sh`) to dynamically set the property at runtime:
```bash
echo "spark.kubernetes.driver.pod.name    ${HOSTNAME}" >> "${FINAL_CONF}"
```
This ensures the driver name always matches the actual pod hostname.

---

## 2. Missing AWS SDK (`NoClassDefFoundError: software/amazon/awssdk/...`)

**Issue:**
Writing to S3 (MinIO) failed with `NoClassDefFoundError` for AWS SDK v2 classes, preventing Delta Lake operations.

**Root Cause:**
The Spark 4.0 / Hadoop 3.3.4 combination requires specific AWS SDK v2 bundles that were missing from the generic Spark image.

**Resolution:**
1.  **Rebuilt Spark Image**: Created `spark-4.0.1-uc-0.3.1-fix-v4`.
2.  **Dockerfile Updates**:
    *   `HADOOP_AWS_VERSION=3.3.4`
    *   `AWS_SDK_V2_VERSION=2.20.160` (Explicitly added `software.amazon.awssdk:bundle:2.20.160`)
3.  **Deployment**: Updated `.env` to `SPARK_IMAGE_VERSION=fix-v4` and redeployed all services.

**Working Dependency Set:**
*   `io.delta:delta-spark_2.13:4.0.0`
*   `org.apache.hadoop:hadoop-aws:3.3.4`
*   `software.amazon.awssdk:bundle:2.20.160`

---

## 3. Configuration Parsing Error (`NumberFormatException: For input string: "60s"`)

**Issue:**
Spark operations failed with `NumberFormatException: "60s"` or `"24h"`.

**Root Cause:**
Default settings in `hadoop-aws` (specifically `fs.s3a.threads.keepalivetime` and `fs.s3a.multipart.purge.age`) use time suffixes (e.g., "60s"), but the Spark/Delta S3A integration path strictly expects **integer milliseconds** or seconds.

**Resolution:**
Hardened `k8s-platform-v2/04-configs/spark-defaults.yaml` to override these defaults with integers:
```yaml
# Timeouts (Milliseconds)
spark.dynamicAllocation.executorIdleTimeout 600000   # Was 600s
spark.dynamicAllocation.schedulerBacklogTimeout 5000 # Was 5s
spark.hadoop.fs.s3a.connection.timeout 200000

# S3A Specifics (Seconds/Integers)
spark.hadoop.fs.s3a.threads.keepalivetime 60         # Was 60s
spark.hadoop.fs.s3a.multipart.purge.age 86400        # Was 24h
spark.hadoop.fs.s3a.connection.estimated.ttl 300
```

---

## 4. StarRocks Empty Results (`type='hive'`)

**Issue:**
Querying the Delta table in StarRocks using a `hive` catalog returned 0 rows, even though Spark confirmed data existed.

**Root Cause:**
The `hive` catalog in StarRocks expects standard Hive tables (Parquet files in folders). For Delta Lake tables, it relies on `symlink_format_manifest` files, which Spark does not generate by default. Without them, StarRocks sees the folder but no valid data files.

**Resolution:**
Switched to the **Native Delta Lake Catalog** (`type='deltalake'`), which reads the `_delta_log` directly.

**Correct SQL:**
```sql
CREATE EXTERNAL CATALOG delta_test
PROPERTIES (
    "type" = "deltalake",
    "hive.metastore.uris" = "thrift://hive-metastore:9083",
    "aws.s3.use_instance_profile" = "false",
    "aws.s3.access_key" = "minioadmin",
    "aws.s3.secret_key" = "minioadmin",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.enable_path_style_access" = "true"
);
```

---

## 5. Manual Storage Burden & HostNetwork Security Risks ✅ Resolved

**Issue:**
The platform relied on manually defined `PersistentVolumes` bound to specific node paths and `hostNetwork: true` for Traefik, creating several problems:
*   **Operational Overhead**: Adding new services required manual PV/PVC pairing.
*   **Security Risks**: `hostNetwork` exposed the ingress controller directly to the host's network stack.
*   **Port Conflicts**: Potential conflicts on the host for port 80/443.

**Optimization & Resolution:**
Migrated to a modern, dynamic infrastructure stack:
1.  **OpenEBS Integration**: Replaced static PVs with the `openebs-hostpath` storage class. This enables **dynamic provisioning**, where Kubernetes automatically handles the lifecycle of local storage on nodes.
2.  **MetalLB Integration**: Installed MetalLB to handle `type: LoadBalancer` services on raw K8s. This provides a clean abstraction for external access.
3.  **Traefik Refactor**: Switched Traefik to `type: LoadBalancer` and disabled `hostNetwork`. It now receives a dedicated static IP (`3.228.1.250`) from MetalLB, improving isolation and scalability.

**Benefits:**
*   **Zero-Touch Storage**: No more manual YAML for individual disks.
*   **Network Isolation**: Traefik runs in its own network namespace.
*   **Cloud-Like UX**: Bare-metal cluster now behaves like a cloud provider with automated LB/Storage.

---

## 6. Cilium CNI — AWS IPAM Mode ✅ Resolved

**Issue:**
The default Cilium CNI configuration used its own internal IPAM, which caused IP address conflicts and routing issues when running on AWS EC2 instances. Pods were assigned IPs outside the VPC CIDR range, breaking connectivity to AWS services and cross-node pod communication.

**Resolution:**
Enabled **Cilium AWS ENI IPAM mode** (`ipam.mode=eni`), which delegates IP address management to AWS. Each pod now receives a real VPC IP from the node's Elastic Network Interface (ENI), ensuring full compatibility with AWS networking (Security Groups, VPC routing, NLB target groups).

---

## 7. Traefik Binding to Host Ports 80/443 ✅ Resolved

**Issue:**
Traefik was configured with `hostNetwork: true` to bind directly to ports 80 and 443 on the master node. This created security risks (full host network access), port conflicts with other services, and made the ingress controller non-portable across nodes.

**Resolution:**
Refactored Traefik to run as a standard `type: LoadBalancer` service. MetalLB assigns a dedicated Elastic IP to the Traefik service, and Traefik listens on ports 80/443 within its own isolated network namespace. This eliminates host-level port binding entirely while preserving external accessibility via the MetalLB-managed IP.

---

## 8. Kubernetes Control Plane Deadlock (API Server / Etcd Crashloop)

**Issue:**
The Kubernetes API server and `etcd` were completely unresponsive, blocking all `kubectl` commands and crashing internal pod networking. Logs showed `etcd` failing with `transport: Error while dialing: dial tcp 10.0.1.188:2379: i/o timeout`. The master node could not even `ping` its own physical internal IP.

**Root Cause:**
A severe routing conflict caused by **Cilium in AWS ENI IPAM mode**. Cilium attaches secondary pod IPs to the primary network interface (`ens5`). The Linux kernel arbitrarily selected a secondary pod IP (e.g., `10.0.1.109`) as the source IP for local traffic targeting the master node's primary IP (`10.0.1.188`). Because this traffic originated from a "pod IP", it collided with Cilium's strict policy routing tables, causing all traffic from `localhost` to the `apiserver/etcd` endpoints to drop into a black hole.

**Resolution:**
Forced the kernel to unequivocally use the master node's primary IP as the source for all local traffic avoiding Cilium's routing policy traps:
```bash
ip route replace local 10.0.1.188 dev ens5 table local proto kernel scope host src 10.0.1.188
```
This instantly restored internal ping, broke the deadlock, and brought the K8s API server back online.

---

## 9. ARM64 Image Incompatibility (`exec format error`)

**Issue:**
Several core infrastructure pods failed to initialize on the AWS Graviton (ARM64) instances, crashing immediately with exit codes indicating `exec format error`.

**Root Cause & Resolutions:**
1. **Superset Init DB:** The `jwilder/dockerize:0.6.1` image is AMD64 only.
   * *Fix:* Replaced all 3 occurrences in `superset.yaml` with the multi-arch `busybox:1.36` and implemented a custom `nc -z` wait loop for PostgreSQL and Redis.
2. **Spark Operator:** The legacy `ghcr.io/googlecloudplatform/spark-operator:v1beta2-1.3.8-3.1.1` image lacked ARM64 manifests.
   * *Fix:* Upgraded to the officially maintained multi-arch image `ghcr.io/kubeflow/spark-operator/spark-operator:2.1.0`.
3. **Hive Metastore:** The custom image `subhodeep2022/spark-bigdata:hive-3.1.3-custom` triggered an `ImagePullBackOff`.
   * *Fix:* Requires the Docker image to be rebuilt in the CI pipeline using `docker buildx` with `--platform linux/arm64`.

---

## 10. Pod Initialization Timing Issues

**Issue:**
Pods like `airflow-db-init` and `starrocks-be` were continuously moving into `CrashLoopBackOff` or failing health probes during cluster startup.

**Root Cause & Resolutions:**
1. **Airflow DB Init:** The database migration rushed to start before the `postgres` service DNS was available or the DB was accepting connections.
   * *Fix:* Injected a `busybox` init container in `db-init-airflow.yaml` to block execution until `nc -z postgres 5432` succeeds.
2. **StarRocks Backend (BE):** ARM64 Graviton IO limits and initial JVM bootstrapping took longer than the default 30-second Kubernetes liveness probe allowed, causing the kubelet to prematurely kill the pod.
   * *Fix:* Tuned `starrocks.yaml` probes, increasing `initialDelaySeconds` to 120s and `failureThreshold` to 10.

---

## 11. Dangling Deployments on Dead Nodes (`TLS Handshake Timeout`)

**Issue:**
Standard `kubectl delete` commands were triggering `TLS handshake timeouts` and hanging the API server.

**Root Cause:**
A worker node (`spark-worker`) crashed and moved to `NotReady/SchedulingDisabled` state. When deleting jobs, K8s places the associated pods in a `Terminating` state and waits endlessly for the dead node's kubelet to confirm the deletion. This blocked API server threads and exhausted resources.

**Resolution:**
To clean up cluster state when EC2 nodes die ungracefully:
2. Or, delete the ghost node directly to trigger immediate K8s garbage collection: `kubectl delete node <node-name>`

---

## 12. Kubernetes Dashboard & GitHub Pages Outage (`404 Not Found`)

**Issue:**
The `deploy-v2.sh` script failed silently while generating `kubernetes-dashboard.yaml` and returned a `404 page not found` when trying to access the UI.

**Root Cause:**
1. The **Kubernetes Dashboard** has been officially archived and deprecated by the CNCF, with `Headlamp` cited as its successor.
2. A systemic networking anomaly on the AWS EC2 instance currently causes all `*.github.io` subdomains (including `kubernetes.github.io` and `headlamp-k8s.github.io`) to return HTTP 404 for Helm repositories. This caused the script to generate flat, zero-byte configuration files.

**Resolution:**
1. **Migration to Headlamp**: Ripped out the deprecated `kubernetes-dashboard` completely.
2. **Helm 404 Bypass**: Since the `helm template` command was swallowing the 404 error from `headlamp-k8s.github.io`, the `deploy-v2.sh` script was patched to fetch the raw `kubernetes-headlamp.yaml` manifest directly through `raw.githubusercontent.com` and automatically inject the Traefik `ingress` resource.

---

## 13. Hubble UI Ingress Failure (`404 Not Found`)

**Issue:**
The Hubble Observability UI `hubble.<domain>` returned a 404 error despite the backend pods running smoothly in `kube-system`.

**Root Cause:**
The Traefik `IngressRoute` for Hubble UI (`k8s-platform-v2/01-networking/hubble-ui-ingressroute.yaml`) was mistakenly created in the `default` namespace, while the service it pointed to was in `kube-system`. Traefik blocks cross-namespace routing by default for security reasons.

**Resolution:**
Updated the `IngressRoute` manifest namespace to `kube-system`, immediately allowing Traefik to securely expose the UI.

-----------------------------------------------
new unsolved issues:

kubectl logs -f hubble-ui-ffdc7bfb5-swwwt -n kube-system
Defaulted container "frontend" out of: frontend, backend
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: can not modify /etc/nginx/conf.d/default.conf (read-only file system?)
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/03/11 19:53:22 [notice] 1#1: using the "epoll" event method
2026/03/11 19:53:22 [notice] 1#1: nginx/1.29.0
2026/03/11 19:53:22 [notice] 1#1: built by gcc 14.2.0 (Alpine 14.2.0) 
2026/03/11 19:53:22 [notice] 1#1: OS: Linux 6.17.0-1007-aws
2026/03/11 19:53:22 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:524288
2026/03/11 19:53:22 [notice] 1#1: start worker processes
2026/03/11 19:53:22 [notice] 1#1: start worker process 21
2026/03/11 19:53:22 [notice] 1#1: start worker process 22
2026/03/11 19:53:22 [notice] 1#1: start worker process 23
2026/03/11 19:53:22 [notice] 1#1: start worker process 24
