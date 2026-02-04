#!/bin/sh
set -e
# Configure MinIO alias
mc alias set myminio http://minio.default.svc.cluster.local:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"

# Mirror the repo contents to MinIO
# /dags/repo is the checked out git repo (linked)
mc mirror --overwrite /dags/repo myminio/dags
