#!/bin/sh
# MinIO upload script to run inside mc container

# Configure MinIO
mc config host add myminio http://minio:9000 minioadmin minioadmin

# Create bucket
mc mb myminio/taxi-data 2>/dev/null || echo "Bucket already exists"

# Upload all parquet files
echo "Starting upload of parquet files..."
cd /data
COUNT=0
for file in *.parquet; do
    COUNT=$((COUNT + 1))
    echo "[$COUNT/78] Uploading $file..."
    mc cp "$file" myminio/taxi-data/
done

# Set public policy
mc policy set public myminio/taxi-data

# Verify
echo ""
echo "Upload complete!"
mc ls myminio/taxi-data/ | wc -l
mc du myminio/taxi-data/
