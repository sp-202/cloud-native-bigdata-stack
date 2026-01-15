<!--
   Licensed to the Apache Software Foundation (ASF) under one
   or more contributor license agreements.  See the NOTICE file
   distributed with this work for additional information
   regarding copyright ownership.  The ASF licenses this file
   to you under the Apache License, Version 2.0 (the
   "License"); you may not use this file except in compliance
   with the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing,
   software distributed under the License is distributed on an
   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
   KIND, either express or implied.  See the License for the
   specific language governing permissions and limitations
   under the License.
-->

# How to Debug the Project

## Table of Contents
1. [Common Scenarios](#common-scenarios)
2. [Debugging Kubernetes Deployments](#debugging-kubernetes-deployments)
3. [Debugging JupyterHub](#debugging-jupyterhub)
4. [Debugging Spark Connect](#debugging-spark-connect)
5. [Logging and Monitoring](#logging-and-monitoring)
6. [Troubleshooting Tips](#troubleshooting-tips)

---

## Common Scenarios
| Scenario | Typical Command | Expected Output | Possible Errors |
|----------|----------------|----------------|-----------------|
| **Pod CrashLoopBackOff** | `kubectl logs <pod>` | Logs showing the failure reason | `Error from server (NotFound): pods "<pod>" not found` – check pod name or namespace |
| **InvalidImageName** | `kubectl describe pod <pod>` | Event `Failed to pull image` with details | Image tag typo, missing image in registry |
| **NumberFormatException in Spark** | `kubectl logs <spark-pod>` | Stack trace pointing to config parsing | Unquoted numeric value in YAML – e.g., `executorMemory: 4g` should be `"4g"` |
| **Connection Refused** | `kubectl exec -it <jupyter-pod> -- curl -s http://spark-connect:7077` | `Connection refused` or successful response | Service not exposed, NetworkPolicy blocking traffic |

---

## Debugging Kubernetes Deployments
1. **List resources**
   ```bash
   kubectl get all -n <namespace>
   ```
2. **Describe a deployment**
   ```bash
   kubectl describe deployment <deployment-name> -n <namespace>
   ```
   *Look for events such as `FailedCreate`, `FailedScheduling`.*
3. **Inspect pod logs**
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```
4. **Execute a shell inside a pod**
   ```bash
   kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
   ```
5. **Check recent events**
   ```bash
   kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
   ```

---

## Debugging JupyterHub
- **Hub pod logs**
  ```bash
  kubectl logs -l component=hub -n jupyterhub
  ```
- **Authenticator errors** – look for messages like `Invalid password` or `OAuth token expired`.
- **Configuration file** – verify `jupyterhub_config.py` for correct `c.JupyterHub.authenticator_class` and service accounts.
- **RBAC** – ensure the service account used by JupyterHub has the required roles:
  ```bash
  kubectl describe rolebinding -n jupyterhub
  ```

---

## Debugging Spark Connect

### 1. Check Spark Connect Server Status
```bash
kubectl get pods -l app=spark-connect-server -n default
```
**Expected Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
spark-connect-server-7b8f6d9c45-xxxxx   1/1     Running   0          2h
```

### 2. View Spark Connect Server Logs
```bash
kubectl logs -l app=spark-connect-server --tail=100
```
**Look for:**
- `SparkConnectServer: started on port 15002`
- `Executor added: executor_0`

**Possible Errors:**
- `Failed to bind to 0.0.0.0:15002` – Port conflict, check if another process is using port
- `NoClassDefFoundError` – Missing JAR in container image

### 3. Verify Service Connectivity from JupyterHub
```bash
kubectl exec -it deployment/jupyterhub -- curl -v telnet://spark-connect-server-driver-svc:15002
```
**Expected Output:**
```
* Connected to spark-connect-server-driver-svc (10.x.x.x) port 15002
```

**Possible Errors:**
- `Connection refused` – Service not running or wrong port
- `Host not found` – Service name typo or not in same namespace

### 4. Test Spark Session in Notebook
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect-server-driver-svc:15002").getOrCreate()
spark.range(5).show()
```
**Expected Output:**
```
✅ Connected to Spark 4.0.1 via Spark Connect
+---+
| id|
+---+
|  0|
|  1|
|  2|
|  3|
|  4|
+---+
```

**Possible Errors:**
- `grpc._channel._InactiveRpcError: StatusCode.UNAVAILABLE` – Server not running
- `SparkException: Failed to deserialize` – Spark version mismatch between client and server

### 5. Check Executor Pods
```bash
kubectl get pods -l spark-role=executor
```
**Expected Output:**
```
NAME                                         READY   STATUS    RESTARTS   AGE
spark-connect-server-xxxx-exec-1             1/1     Running   0          5m
spark-connect-server-xxxx-exec-2             1/1     Running   0          5m
```

**Possible Errors:**
- `Pending` – Insufficient cluster resources
- `ImagePullBackOff` – Invalid image name in spark.kubernetes.container.image

### 6. Access Spark UI
```bash
kubectl port-forward svc/spark-connect-server-driver-svc 4040:4040
```
Then open `http://localhost:4040` in browser.

---

## Logging and Monitoring
- **Prometheus** – enable in Helm values: `metrics.enabled=true`.
- **Grafana dashboards** – import the Superset dashboards from `docs/grafana/`.
- **Centralized logs** – configure Loki or Elasticsearch via `fluentd` DaemonSet.
- **View logs in UI** – Superset UI > Settings > Logs.

---

## Troubleshooting Tips
- Reproduce the issue locally with `minikube` before scaling.
- Use `kubectl port-forward` to expose a service for local `curl` testing.
- Verify resource quotas: `kubectl describe quota -n <ns>` – OOM kills often stem from limits.
- Review recent commits for config changes that may have introduced regressions.
- Run `pre-commit run` after documentation changes to ensure markdown lint passes.

---

## Verification Plan
- Run `pre-commit run` to validate markdown lint and spellcheck.
- Build the docs site (if using MkDocs) and verify all links resolve.
- Manually walk through each debugging scenario to confirm commands and outputs.
- Commit changes with conventional commit messages, e.g., `docs: add comprehensive HOW_TO_DEBUG guide`.
