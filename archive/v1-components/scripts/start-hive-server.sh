#!/bin/bash
set -e

/opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2 \
  --name "Thrift JDBC/ODBC Server" \
  --conf spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083 \
  --conf spark.sql.warehouse.dir=s3a://warehouse/ \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.access.key=${MINIO_ACCESS_KEY} \
  --conf spark.hadoop.fs.s3a.secret.key=${MINIO_SECRET_KEY} \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.driver.extraClassPath=/opt/spark/jars/postgresql-42.6.0.jar \
  --conf spark.executor.extraClassPath=/opt/spark/jars/postgresql-42.6.0.jar \
  --conf spark.driver.extraJavaOptions="-Djava.net.preferIPv4Stack=true" \
  --conf spark.executor.extraJavaOptions="-Djava.net.preferIPv4Stack=true" \
  --conf spark.cores.max=1 \
  --conf spark.hadoop.hive.server2.thrift.port=10000 \
  --conf spark.hadoop.hive.server2.thrift.bind.host=0.0.0.0 \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
  --conf spark.hadoop.hive.server2.transport.mode=binary \
  --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
  --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog
