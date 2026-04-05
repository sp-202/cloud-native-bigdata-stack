# Builder Stage
# Using eclipse-temurin:17-jdk-jammy as ARM64-compatible base (multi-arch manifest)
FROM eclipse-temurin:17-jdk-jammy AS builder

ENV SPARK_VERSION=4.0.1
ENV HADOOP_VERSION=3
ENV SCALA_VERSION=2.13
# Iceberg 1.10.1 — matches Gravitino 1.2.0's bundled Iceberg version exactly
ENV ICEBERG_VERSION=1.10.1
ENV HADOOP_AWS_VERSION=3.4.1
ENV AWS_SDK_V2_VERSION=2.29.52
ENV POSTGRES_VERSION=42.6.0
ENV SEDONA_VERSION=1.8.1
ENV GEOTOOLS_WRAPPER_VERSION=1.8.1-33.1
ENV H3_VERSION=4.0.1
ENV SPARK_HOME=/opt/spark

# Install build dependencies
RUN apt-get update && apt-get install -y wget curl

# Download and install Spark
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# Remove unused Spark artifacts to reduce image size
RUN rm -rf $SPARK_HOME/examples $SPARK_HOME/data $SPARK_HOME/tests $SPARK_HOME/licenses

# Download JARs 
# Iceberg-native setup: iceberg-spark-runtime (core) + iceberg-aws-bundle (S3FileIO with shaded AWS SDK v2)
# hadoop-aws + bundle + url-connection-client: needed for Spark's S3A FileSystem (separate from Iceberg S3FileIO)
# Both coexist cleanly: iceberg-aws-bundle shades its AWS SDK under org.apache.iceberg.shaded.*
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.0_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-4.0_2.13-${ICEBERG_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_V2_VERSION}/bundle-${AWS_SDK_V2_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/${AWS_SDK_V2_VERSION}/url-connection-client-${AWS_SDK_V2_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/sedona/sedona-spark-shaded-4.0_2.13/${SEDONA_VERSION}/sedona-spark-shaded-4.0_2.13-${SEDONA_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/datasyslab/geotools-wrapper/${GEOTOOLS_WRAPPER_VERSION}/geotools-wrapper-${GEOTOOLS_WRAPPER_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/com/uber/h3/${H3_VERSION}/h3-${H3_VERSION}.jar -P $SPARK_HOME/jars/

# Final Stage
FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    tini \
    software-properties-common \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-distutils \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Install PySpark executor dependencies (minimal)
RUN python3.11 -m pip install --no-cache-dir pandas pyarrow numpy

# Copy pre-built Spark artifact from builder
COPY --from=builder /opt/spark /opt/spark

WORKDIR $SPARK_HOME

# Copy and set official Spark K8s entrypoint
RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

# Baseline spark-defaults.conf — Iceberg + Gravitino REST catalog
# Full config is injected at runtime via the spark-config ConfigMap mounted by the Connect server.
# This baseline ensures executors (which don't mount the ConfigMap) can still reach the catalog.
RUN echo "spark.network.timeout 120\n\
spark.files.fetchTimeout 60\n\
spark.executor.heartbeatInterval 10\n\
spark.hadoop.fs.s3a.connection.timeout 60\n\
spark.hadoop.fs.s3a.connection.establish.timeout 30\n\
spark.hadoop.fs.s3a.connection.acquisition.timeout 60\n\
spark.hadoop.fs.s3a.threads.keepalivetime 60\n\
spark.hadoop.fs.s3a.multipart.purge.age 86400\n\
spark.serializer org.apache.spark.serializer.KryoSerializer\n\
spark.kryo.registrator org.apache.sedona.core.serde.SedonaKryoRegistrator\n\
spark.sql.extensions org.apache.sedona.viz.sql.SedonaVizExtensions,org.apache.sedona.sql.SedonaSqlExtensions,org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions\n\
spark.sql.catalog.spark_catalog org.apache.iceberg.spark.SparkCatalog\n\
spark.sql.catalog.spark_catalog.type rest\n\
spark.sql.catalog.spark_catalog.uri http://gravitino.default.svc.cluster.local:9001/iceberg/\n\
spark.sql.catalog.spark_catalog.io-impl org.apache.iceberg.aws.s3.S3FileIO\n\
spark.sql.defaultCatalog spark_catalog" > $SPARK_HOME/conf/spark-defaults.conf

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
