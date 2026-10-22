# Persistence Sub-chart

PVCs for workloads that don't own a StatefulSet volumeClaimTemplate.

- **Sync Wave**: `-3`
- **PVCs**: `redis-data-pvc`, only when `persistence.redis.enabled` (Redis is off while Superset is off).
  StarRocks volumes come from the kube-starrocks chart's own `storageSpec`.
- **StorageClass**: `global.storageClassName` (`local-storage`, OpenEBS local PV — hostpath or
  LVM, chosen at bootstrap; see `rke2/README.md`). WaitForFirstConsumer, RWO.
