# Custom Spark Docker Image (rke2 branch)

The Spark image used by the Spark Operator jobs, the Spark History Server and Spark Connect:
stock **Apache Spark 3.5.8** (Hadoop 3, Scala 2.13, from the Apache archive, SHA-512 verified)
plus Iceberg 1.10.1 + iceberg-aws-bundle, hadoop-aws 3.3.4 / aws-java-sdk-bundle, the
Gravitino Spark connector, the PostgreSQL JDBC driver and the Kafka connector (spark-sql-kafka) for Structured Streaming. Python 3.12 with pandas/pyarrow/numpy
for PySpark.

No Comet on this branch (main's image adds it). Everything is JVM or pure Python, so the image
builds for any platform; `SPARK_PLATFORMS` in `.env.spark` is `linux/amd64` for the x86_64
RKE2 nodes. Tag: `spark-<SPARK_VERSION>-<SPARK_IMAGE_VERSION>`
(`spark-3.5.8-v14-iceberg-gravitino-kafka-oss`), matching `global.sparkImage` in
`big-data-platform/values.yaml`.

## Build
```bash
./build.sh          # reads .env.spark, buildx --platform $SPARK_PLATFORMS --push
```
CI (`.github/workflows/docker-build.yml`) does the same on pushes that change the Dockerfile.

## Configuration
No credentials or endpoints are baked in. On RKE2, jobs set the SeaweedFS endpoint
(`spark.hadoop.fs.s3a.endpoint`, path-style, no SSL) and get `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` from the `lakehouse-s3` Secret via `envFrom` — see
`examples/spark-jobs/rke2-iceberg-smoke-test.yaml`.
