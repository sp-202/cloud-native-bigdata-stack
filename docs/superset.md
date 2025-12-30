# 📊 Apache Superset - Detailed Guide

## 1. Deployment Method (Helm)
We use the official **Superset Helm Chart**. Configuration is applied via `superset-values.yaml`.

## 2. Configuration deep Dive (`superset-values.yaml`)

### Key Overrides
We use `configOverrides` to inject Python code directly into `superset_config.py`.

```python
# Caching Config (Critical for Performance)
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_KEY_PREFIX': 'superset_results_',
    'CACHE_REDIS_HOST': 'superset-redis-master',
   ...
}
```
**Why Redis?**: Superset by default might store cache on disk or in memory. In K8s, pods die. Redis provides a persistent, shared cache layer.

### Feature Flags
Enabled in `superset-values.yaml`:
*   `"DASHBOARD_NATIVE_FILTERS": True`: Enables the new sidebar filter UI.
*   `"DASHBOARD_CROSS_FILTERS": True`: Clicking a chart filters other charts.

## 3. Database Connections
Superset needs to talk to your Data Warehouses.
*   **Hive Metastore**: `hive://hive-metastore:10000/default`.
*   **Presto/Trino** (If added): `presto://trino:8080/hive`.
*   **Internal Postgres**: Used for Superset's *own* metadata (users, dashboards), NOT for data analysis.

## 4. Troubleshooting
| Error | Cause | Fix |
| :--- | :--- | :--- |
| **"Alchemy Connection Failed"** | Redis or DB is down. | Check `kubectl get pods` for `superset-redis` and `postgres`. |
| **"Worker Timeout"** | Query took too long. | Increase `SUPERSET_WEBSERVER_TIMEOUT` in values.yaml. |
| **"CSRF Token Missing"** | Browser Cookie issue or LoadBalancer switching. | Clear Cookies. Our `Ingress` session affinity usually handles this. |
