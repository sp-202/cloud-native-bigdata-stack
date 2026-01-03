# Check for Destructive Flag
# K3s Auto-Context Fix
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    if [ ! -r "/etc/rancher/k3s/k3s.yaml" ]; then
        sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    fi
fi

DESTROY_ALL=false
if [[ "$1" == "--destroy-all" ]]; then
  DESTROY_ALL=true
  echo "⚠️  WARNING: DESTRUCTIVE DATA WIPE MODE ENABLED ⚠️"
  echo "This will delete ALL data (PVCs), Databases, and Monitoring Stacks."
  echo "Starting in 5 seconds..."
  sleep 5
else
  echo "ℹ️  SAFE MODE: Deleting Applications Only (Keeping Data/Infra)"
  echo "To delete everything (including data), run: ./cleanup.sh --destroy-all"
fi

# Uninstall Stateless Applications
echo "Uninstalling Applications..."
helm uninstall superset || true
kubectl delete deployment airflow-webserver airflow-scheduler zeppelin || true
kubectl delete svc airflow-webserver zeppelin zeppelin-server superset superset-redis-headless superset-redis-master || true
kubectl delete job minio-create-buckets superset-init-db || true
kubectl delete statefulset superset-redis-master || true

if [ "$DESTROY_ALL" = true ]; then
  echo "Uninstalling Infrastructure & Data..."
  helm uninstall traefik || true
  helm uninstall spark-operator -n spark-operator || true
  helm uninstall spark-operator || true
  helm uninstall kubernetes-dashboard -n kubernetes-dashboard || true
  helm uninstall kube-prometheus-stack || true
  
  kubectl delete deployment hive-metastore minio postgres || true
  kubectl delete svc minio hive-metastore postgres traefik || true
  kubectl delete secret superset-env superset-config || true
  
  # Delete PVCs (DATA LOSS)
  echo "Deleting PVCs (Data Wipe)..."
  kubectl delete pvc minio-data-pvc postgres-data-pvc zeppelin-notebook-pvc || true
  kubectl delete pvc -l app.kubernetes.io/name=prometheus || true
  kubectl delete pvc -l app.kubernetes.io/instance=kube-prometheus-stack || true
  kubectl delete pvc -l app.kubernetes.io/instance=superset || true
  
  kubectl delete namespace spark-operator || true
  kubectl delete namespace kubernetes-dashboard || true
  kubectl delete clusterrolebinding admin-user || true
  kubectl delete serverstransport -n default insecure-transport || true
fi

# Delete ConfigMaps (Safe to recreate)
kubectl delete cm airflow-dags hive-config spark-config spark-templates zeppelin-interpreter-spec zeppelin-site || true

echo "Cleanup Complete."
