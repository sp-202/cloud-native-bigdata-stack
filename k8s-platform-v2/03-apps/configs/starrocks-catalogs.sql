-- StarRocks external catalogs + internal databases (applied by deploy-starrocks.sh)
-- Idempotent: safe to re-run. ${MINIO_ROOT_USER} / ${MINIO_ROOT_PASSWORD} are filled from .env via envsubst.
-- Hosts are fully qualified because StarRocks runs in the "starrocks" namespace, MinIO/HMS in "default".

CREATE EXTERNAL CATALOG IF NOT EXISTS `delta_test`
PROPERTIES (
  "type" = "deltalake",
  "hive.metastore.uris" = "thrift://hive-metastore.default.svc.cluster.local:9083",
  "aws.s3.endpoint" = "http://minio.default.svc.cluster.local:9000",
  "aws.s3.access_key" = "${MINIO_ROOT_USER}",
  "aws.s3.secret_key" = "${MINIO_ROOT_PASSWORD}",
  "aws.s3.enable_path_style_access" = "true",
  "aws.s3.use_instance_profile" = "false"
);

CREATE EXTERNAL CATALOG IF NOT EXISTS `iceberg_minio`
PROPERTIES (
  "type" = "iceberg",
  "iceberg.catalog.type" = "hive",
  "hive.metastore.uris" = "thrift://hive-metastore.default.svc.cluster.local:9083",
  "aws.s3.endpoint" = "http://minio.default.svc.cluster.local:9000",
  "aws.s3.access_key" = "${MINIO_ROOT_USER}",
  "aws.s3.secret_key" = "${MINIO_ROOT_PASSWORD}",
  "aws.s3.enable_ssl" = "false",
  "aws.s3.enable_path_style_access" = "true"
);

CREATE EXTERNAL CATALOG IF NOT EXISTS `nav_delta_catalog`
PROPERTIES (
  "type" = "deltalake",
  "hive.metastore.type" = "hive",
  "hive.metastore.uris" = "thrift://hive-metastore.default.svc.cluster.local:9083",
  "aws.s3.endpoint" = "http://minio.default.svc.cluster.local:9000",
  "aws.s3.access_key" = "${MINIO_ROOT_USER}",
  "aws.s3.secret_key" = "${MINIO_ROOT_PASSWORD}",
  "aws.s3.enable_ssl" = "false",
  "aws.s3.enable_path_style_access" = "true"
);

CREATE DATABASE IF NOT EXISTS demo;
CREATE DATABASE IF NOT EXISTS dbt_models;
