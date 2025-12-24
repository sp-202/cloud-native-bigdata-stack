#!/bin/bash

# Create archive directory
mkdir -p archive

echo "Archiving Legacy and Temporary Files..."

# Move Legacy Docker Compose Files
mv docker-compose.yml archive/ 2>/dev/null || true
mv docker-compose-superset.yml archive/ 2>/dev/null || true

# Move Logs
mv *.log archive/ 2>/dev/null || true
mv *.txt archive/ 2>/dev/null || true

# Move Miscellaneous Scripts
mv batch-upload.sh archive/ 2>/dev/null || true
mv download-taxi-data*.sh archive/ 2>/dev/null || true
mv mc-upload.sh archive/ 2>/dev/null || true
mv upload-to-minio*.sh archive/ 2>/dev/null || true

# Move Test Artifacts
mv sample.json archive/ 2>/dev/null || true
mv test_hive.py archive/ 2>/dev/null || true

# Move Dashboard artifacts (if not strictly needed in root)
mv dashboard-access.service archive/ 2>/dev/null || true
mv dashboard-admin.yaml archive/ 2>/dev/null || true

# Check if superset folder is needed. 
# deploy.sh uses remote chart, but local folder caused issues. 
# Moving it to archive prevents Helm collision safely.
if [ -d "superset" ]; then
    echo "Moving superset/ directory to archive/..."
    mv superset archive/
fi

if [ -d "helm-charts" ]; then
    echo "Moving helm-charts/ directory to archive/..."
    mv helm-charts archive/
fi

echo "Cleanup Complete. Legacy files moved to archive/."
ls -F
