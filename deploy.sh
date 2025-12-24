#!/bin/bash
set -e

echo "=============================================="
echo "Starting Fresh Deployment of Data Platform"
echo "=============================================="

# 1. Infrastructure & Storage
echo "[1/5] Deploying Storage and Databases..."
kubectl apply -f kubernetes/persistence.yaml
kubectl apply -f kubernetes/postgres.yaml
kubectl apply -f kubernetes/minio.yaml

# Wait for DBs to be ready (Simple sleep or wait)
echo "Waiting 20s for Databases to initialize..."
sleep 20

# 2. Core Services
echo "[2/5] Deploying Hive Metastore & Airflow..."
kubectl apply -f kubernetes/hive-metastore.yaml
kubectl apply -f kubernetes/airflow.yaml
# (If airflow.yaml exists instead of separate files, use that. I saw separate pods deleted earlier.)
# Checking file list implies I should verify specific filenames.
# Based on earlier delete output: airflow-webserver, airflow-scheduler deployments.
# Assuming standard file names or unified. I will check file list to be precise. 
# For now, I will use 'kubectl apply -f kubernetes/' for the folder but exclude non-manifests?
# Safer to apply specific known files or the whole folder and ignore errors on non-manifests.
# Let's apply specific files to be clean.

# 3. Compute Engines
echo "[3/5] Deploying Zeppelin..."
# Create ConfigMap from XML file
kubectl create configmap zeppelin-site --from-file=kubernetes/zeppelin-site.xml --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f kubernetes/zeppelin.yaml
# Apply ConfigMaps for Spark Templates? They were created from files?
# `spark-configmap.yaml` likely does this.
kubectl apply -f kubernetes/spark-configmap.yaml
# Create ConfigMap for Interpreter Spec Template (Jinja2 format, not raw YAML)
kubectl create configmap zeppelin-interpreter-spec --from-file=100-interpreter-spec.yaml=kubernetes/100-interpreter-spec.yaml --dry-run=client -o yaml | kubectl apply -f -

# 4. Superset
echo "[4/5] Installing Superset via Helm..."
# Ensure repo exists (idempotent)
helm repo add superset https://apache.github.io/superset
helm repo update

# Install using explicit repo to avoid local 'superset' folder collision
# We change directory to avoid Helm scanning the local 'superset' source folder
pushd kubernetes
helm upgrade --install superset superset \
  --repo https://apache.github.io/superset \
  --values superset-values.yaml \
  --timeout 10m
popd

echo "=============================================="
echo "Deployment Triggered. Pods are starting."
echo "Monitor status with: kubectl get pods -w"
echo "=============================================="
