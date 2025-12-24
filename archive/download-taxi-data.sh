#!/bin/bash

# NYC Taxi Data Download Script
# Downloads Yellow Taxi trip data in Parquet format
# Target: ~5-6 GB of data (approximately 18 months of data)

DOWNLOAD_DIR="/home/ubuntu/pipe-line/data/nyc-taxi-downloads"
BASE_URL="https://d37ci6vzurychx.cloudfront.net/trip-data"

# Ensure download directory exists
mkdir -p "$DOWNLOAD_DIR"

echo "Starting NYC taxi data download..."
echo "Target directory: $DOWNLOAD_DIR"
echo ""

# Download data from 2023-01 to 2024-06 (18 months)
# Each file is approximately 100-200 MB, so 18 months should give us ~5-6 GB

MONTHS=(
    "2023-01" "2023-02" "2023-03" "2023-04" "2023-05" "2023-06"
    "2023-07" "2023-08" "2023-09" "2023-10" "2023-11" "2023-12"
    "2024-01" "2024-02" "2024-03" "2024-04" "2024-05" "2024-06"
)

TOTAL_FILES=${#MONTHS[@]}
CURRENT_FILE=0

for MONTH in "${MONTHS[@]}"; do
    CURRENT_FILE=$((CURRENT_FILE + 1))
    FILENAME="yellow_tripdata_${MONTH}.parquet"
    URL="${BASE_URL}/${FILENAME}"
    
    echo "[$CURRENT_FILE/$TOTAL_FILES] Downloading $FILENAME..."
    
    # Download with wget, showing progress
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${FILENAME}" "$URL"
    
    if [ $? -eq 0 ]; then
        FILE_SIZE=$(du -h "${DOWNLOAD_DIR}/${FILENAME}" | cut -f1)
        echo "  ✓ Downloaded successfully (Size: $FILE_SIZE)"
    else
        echo "  ✗ Failed to download $FILENAME"
    fi
    echo ""
done

# Display total size
echo "Download complete!"
echo ""
echo "Total size of downloaded files:"
du -sh "$DOWNLOAD_DIR"
echo ""
echo "Files downloaded:"
ls -lh "$DOWNLOAD_DIR"
