#!/bin/bash
/usr/bin/mc config host add myminio http://minio:9000 minioadmin minioadmin;
/usr/bin/mc mb myminio/warehouse;
/usr/bin/mc mb myminio/data;
/usr/bin/mc mb myminio/test-bucket;
/usr/bin/mc mb myminio/taxi-data;
/usr/bin/mc policy set public myminio/warehouse;
/usr/bin/mc policy set public myminio/data;
/usr/bin/mc policy set public myminio/test-bucket;
/usr/bin/mc policy set public myminio/taxi-data;
exit 0;
