# Deployment Guide

This guide details how to set up the environment and deploy the Kubernetes Big Data Platform (v2).

## Prerequisites

Ensure you have the following tools installed:
- **Kubernetes Cluster**: A running K8s cluster (GKE, Minikube, Kind, etc.) and `kubectl` configured.
- **Helm**: Version 3+ (v4 is also supported by this project).
- **Git**: To clone repositories.

## Installation Instructions

### macOS (via Homebrew)
If you are on macOS, `brew` is the easiest way to install dependencies.

```bash
# Update Homebrew
brew update

# Install Kubectl
brew install kubernetes-cli

# Install Helm
brew install helm

# Install Git
brew install git
```

### Linux (Debian/Ubuntu)
For Debian-based systems, use `apt` and official sources.

```bash
# 1. Install prerequisites
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# 2. Install Kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# 3. Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# 4. Install Git
sudo apt-get install -y git
```

## Configuration

The platform relies on a `.env` file for dynamic configuration (like Spark image versions).

1.  **Create `.env` file**:
    ```bash
    cp .env.example .env
    ```
    *(If `.env.example` is missing, create `.env` manually)*

2.  **Set Spark Image Version**:
    ```bash
    # Content of .env
    SPARK_IMAGE_VERSION=fix-v4
    SPARK_IMAGE=subhodeep2022/spark-bigdata:spark-4.0.1-uc-0.3.1-fix-v4
    ```

## Deployment

1.  **Clone/Navigate to Project**:
    ```bash
    cd kubernets-big-data-project
    ```

2.  **Build Custom Spark Image**:
    The project requires a custom Spark image with proper Hadoop/AWS SDK dependencies.
    *Ensure Docker is running and you are logged in (`docker login`).*

    ```bash
    ./docker/spark/build.sh
    ```
    *Note: Update `.env` with the new image tag if you change versions.*

3.  **Run Deployment Script**:
    This script will:
    - Install Infrastructure (Traefik, Spark Operator).
    - Deploy Hive Metastore (HMS) and MinIO.
    - Generate Helm manifests for all components.
    - Deploy the platform using `kubectl kustomize`.

    ```bash
    # Ensure .env variables are exported
    set -a && source .env && set +a
    
    ./deploy-gke.sh
    ```

## Verification

After the script completes, verify the deployment:

1.  **Check Pods**:
    ```bash
    kubectl get pods -n default
    ```
    Ensure `hive-metastore`, `spark-operator`, `superset`, `postgres`, `minio` pods are Running.

2.  **Access Web UIs**:
    Based on the output IP (e.g., `34.x.x.x`), access:
    - **JupyterHub**: `http://jupyterhub.34.x.x.x.sslip.io`
    - **Superset**: `http://superset.34.x.x.x.sslip.io`
    - **Traefik Dashboard**: `http://traefik.34.x.x.x.sslip.io/dashboard/`

## Troubleshooting
- **Run Deployment Again**: The script is idempotent. If a step fails (e.g., waiting for IP), just run `./deploy-v2.sh` again.

## Maintenance & Updates

### Force Reapply Configurations & Restart Services
To force an update of all configurations (manifests) and restart only the JupyterHub and Spark components (leaving databases and other services infrastructure intact):

1.  **Reapply Configurations**:
    Run the deployment script again to regenerate and apply latest manifests:
    ```bash
    ./deploy-v2.sh
    ```

2.  **Restart JupyterHub and Spark**:
    Delete the specific pods to force Kubernetes to recreate them with the new configurations:
    ```bash
    # Restart JupyterHub
    kubectl delete pod -l app=jupyterhub

    # Restart Spark Connect Server
    kubectl delete pod -l app=spark-connect-server
    
    # Clean up Spark Executors (if stuck)
    kubectl delete pod -l spark-role=executor
    ```
    *Note: Do not delete pods like `minio`, `postgres`, or `hive-metastore` unless you intend to reset those services.*
