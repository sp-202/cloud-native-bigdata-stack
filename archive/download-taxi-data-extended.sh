#!/bin/bash

# NYC Taxi Data Download Script - Extended Version
# Downloads Yellow Taxi trip data in Parquet format
# Target: ~5-6 GB of data (approximately 72 months of data from 2019-2024)

DOWNLOAD_DIR="/home/ubuntu/pipe-line/data/nyc-taxi-downloads"
BASE_URL="https://d37ci6vzurychx.cloudfront.net/trip-data"

# Ensure download directory exists
mkdir -p "$DOWNLOAD_DIR"

echo "Starting NYC taxi data download (Extended)..."
echo "Target directory: $DOWNLOAD_DIR"
echo ""

# Download data from 2019-2024 to get ~5-6 GB
# Each file is approximately 45-60 MB, so we need about 100 files

MONTHS=(
    # 2019 data
    "2019-01" "2019-02" "2019-03" "2019-04" "2019-05" "2019-06"
    "2019-07" "2019-08" "2019-09" "2019-10" "2019-11" "2019-12"
    # 2020 data
    "2020-01" "2020-02" "2020-03" "2020-04" "2020-05" "2020-06"
    "2020-07" "2020-08" "2020-09" "2020-10" "2020-11" "2020-12"
    # 2021 data
    "2021-01" "2021-02" "2021-03" "2021-04" "2021-05" "2021-06"
    "2021-07" "2021-08" "2021-09" "2021-10" "2021-11" "2021-12"
    # 2022 data
    "2022-01" "2022-02" "2022-03" "2022-04" "2022-05" "2022-06"
    "2022-07" "2022-08" "2022-09" "2022-10" "2022-11" "2022-12"
)

TOTAL_FILES=${#MONTHS[@]}
CURRENT_FILE=0

for MONTH in "${MONTHS[@]}"; do
    CURRENT_FILE=$((CURRENT_FILE + 1))
    FILENAME="yellow_tripdata_${MONTH}.parquet"
    URL="${BASE_URL}/${FILENAME}"
    
    # Skip if already exists
    if [ -f "${DOWNLOAD_DIR}/${FILENAME}" ]; then
        echo "[$CURRENT_FILE/$TOTAL_FILES] Skipping $FILENAME (already exists)"
        continue
    fi
    
    echo "[$CURRENT_FILE/$TOTAL_FILES] Downloading $FILENAME..."
    
    # Download with wget, showing progress
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${FILENAME}" "$URL"
    
    if [ $? -eq 0 ]; then
        FILE_SIZE=$(du -h "${DOWNLOAD_DIR}/${FILENAME}" | cut -f1)
        echo "  ✓ Downloaded successfully (Size: $FILE_SIZE)"
    else
        echo "  ✗ Failed to download $FILENAME"
        rm -f "${DOWNLOAD_DIR}/${FILENAME}"  # Remove incomplete file
    fi
    echo ""
done

# Display total size
echo "Download complete!"
echo ""
echo "Total size of downloaded files:"
du -sh "$DOWNLOAD_DIR"
echo ""
echo "Number of files:"
ls -1 "$DOWNLOAD_DIR" | wc -l
