#!/bin/bash

# Upload NYC taxi data to MinIO bucket
# This script uploads all downloaded Parquet files to the taxi-data bucket in MinIO

DOWNLOAD_DIR="/home/ubuntu/pipe-line/data/nyc-taxi-downloads"
BUCKET_NAME="taxi-data"

echo "Uploading NYC taxi data to MinIO..."
echo "Source: $DOWNLOAD_DIR"
echo "Destination: minio/$BUCKET_NAME"
echo ""

# Copy all files to MinIO using docker cp and then mc
# First, ensure bucket exists
sudo docker exec minio mc mb /data/$BUCKET_NAME 2>/dev/null || echo "  Bucket already exists or will be created"

# Copy files directly to MinIO data volume
echo "Copying files to MinIO..."
sudo cp -r $DOWNLOAD_DIR/* /home/ubuntu/pipe-line/data/minio/$BUCKET_NAME/

echo ""
echo "Upload complete!"
echo ""
echo "Verifying upload..."
sudo docker exec minio ls -lh /data/$BUCKET_NAME/ | head -20
echo ""
echo "Total files uploaded:"
sudo docker exec minio ls /data/$BUCKET_NAME/ | wc -l
echo ""
echo "Total size in bucket:"
sudo docker exec minio du -sh /data/$BUCKET_NAME/
