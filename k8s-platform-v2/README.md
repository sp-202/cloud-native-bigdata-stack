# ☸️ Infrastructure as Code (K8s-Platform-V2)

This directory is the **Source of Truth** for the Big Data Platform. It contains all the Kubernetes manifests (YAMLs) required to spin up the stack.

We use **Kustomize** for configuration management. Unlike Helm (which uses complex templates), Kustomize uses plain YAMLs and "overlays" to patching configurations.

---

## 🎓 Concepts (Beginner)

### What is this folder structure?
The folders are numbered (`00`, `01`, `02`...) to represent the **Order of Dependency**.
1.  **`00-core`**: We can't deploy apps without a Namespace or Storage.
2.  **`01-networking`**: We need a Router (Traefik) before we can expose apps.
3.  **`02-database`**: Apps need Databases (Postgres/MinIO) to be running first.
4.  **`03-apps`**: The actual logic (Airflow, Spark) starts here, connecting to the databases.

### What is `kustomization.yaml`?
This file is the "Manager". It tells Kubernetes:
1.  Which folders to include (`resources`).
2.  Which Helm Charts to install (`helmCharts`).
3.  What global variables to replace (`vars`).

---

## 🚀 Architecture (Intermediate)

### The Hydration Process
When you run `./deploy-gke.sh`, it executes specific `kustomize` commands. Here is what happens under the hood:

1.  **Collection**: Kustomize traverses all subdirectories listed in `resources`.
2.  **Helm Expansion**: It spots the `05-monitoring` folder asking for `kube-prometheus-stack`. It downloads the Chart and converts it to static YAML.
3.  **Variable Replacement**: It finds the `$(INGRESS_DOMAIN)` variable in all files (e.g., `ingress.yaml`) and replaces it with your actual LoadBalancer IP (e.g., `34.1.2.3.sslip.io`).
4.  **Output**: It spits out one giant YAML file containing thousands of lines, which is piped to `kubectl apply`.

---

## 🧠 Advanced Usage (Expert)

### Debugging the Build
If a deployment fails, it's often useful to see the *final* YAML before it hits the cluster.
```bash
# Render the full manifest to stdout
kubectl kustomize --enable-helm . 
```

### Adding a New App
To add a new component (e.g., Kafka):
1.  Create a folder: `03-apps/kafka`.
2.  Add your YAMLs (`deployment.yaml`, `service.yaml`).
3.  Create a `03-apps/kafka/kustomization.yaml` listing those files.
4.  Edit the parent `03-apps/kustomization.yaml` and add `- kafka` to `resources`.
5.  **Done**. The top-level Kustomize will automatically pick it up.

### Modifications
*   **Changing Images**: Edit the specific `deployment.yaml` in the app's folder.
*   **Changing Storage**: Edit `00-core/storage-class.yaml`.
*   **Global Domain**: defined in `04-configs/ingress-domain.yaml`.

---

## � detailed Directory Guide

| Folder                                         | Purpose               | Key Components                          |
| :--------------------------------------------- | :-------------------- | :-------------------------------------- |
| **[`00-core`](00-core/README.md)**             | **Foundation**        | `Namespace`, `StorageClass`, `PVC`      |
| **[`01-networking`](01-networking/README.md)** | **Traffic Control**   | `Traefik`, `IngressRoute`, `Middleware` |
| **[`02-database`](02-database/README.md)**     | **State Layer**       | `Postgres`, `MinIO`, `Redis`            |
| **[`03-apps`](03-apps/README.md)**             | **Application Layer** | `Airflow`, `Spark`, `Zeppelin`, `Hive`  |
| **[`04-configs`](04-configs/README.md)**       | **Shared Configs**    | `Hadoop XMLs`, `Global Env Vars`        |
| **[`05-monitoring`](05-monitoring/README.md)** | **Observability**     | `Prometheus`, `Grafana`, `Loki`         |
