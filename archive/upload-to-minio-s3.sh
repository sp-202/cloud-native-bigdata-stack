#!/bin/bash

# Properly upload NYC taxi data to MinIO using mc client
# This ensures files are indexed in MinIO's S3 metadata

echo "Setting up MinIO client and uploading taxi data..."

# Start a temporary mc container with access to the data
docker run --rm \
  --network databricks-net \
  -v /home/ubuntu/pipe-line/data/nyc-taxi-downloads:/data \
  minio/mc \
  sh -c "
    # Configure MinIO host
    mc config host add myminio http://minio:9000 minioadmin minioadmin
    
    # Remove existing bucket and recreate (to ensure clean state)
    mc rb --force myminio/taxi-data 2>/dev/null || true
    mc mb myminio/taxi-data
    
    # Upload all parquet files
    echo 'Uploading files...'
    mc cp /data/*.parquet myminio/taxi-data/
    
    # Set public policy
    mc policy set public myminio/taxi-data
    
    # Verify upload
    echo ''
    echo 'Upload complete! Verifying...'
    mc ls myminio/taxi-data/ | wc -l
    echo 'files uploaded'
    mc du myminio/taxi-data/
  "

echo ""
echo "Done! Files are now accessible via s3a://taxi-data/"
