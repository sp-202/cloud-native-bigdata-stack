# Builder Stage
# Using eclipse-temurin:17-jdk-jammy as ARM64-compatible base (multi-arch manifest)
FROM eclipse-temurin:17-jdk-jammy AS builder

ENV SPARK_VERSION=3.5.8 \
    HADOOP_VERSION=3 \
    SCALA_VERSION=2.13 \
    ICEBERG_VERSION=1.10.1 \
    HADOOP_AWS_VERSION=3.3.4 \
    AWS_SDK_V1_VERSION=1.12.262 \
    AWS_SDK_V2_VERSION=2.29.52 \
    GRAVITINO_VERSION=1.2.0 \
    POSTGRES_VERSION=42.6.0 \
    SEDONA_VERSION=1.8.1 \
    GEOTOOLS_WRAPPER_VERSION=1.8.1-33.1 \
    H3_VERSION=4.0.1 \
    SPARK_HOME=/opt/spark

RUN apt-get update && apt-get install -y wget curl

RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala2.13.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala2.13.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala2.13 ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala2.13.tgz

RUN rm -rf $SPARK_HOME/examples $SPARK_HOME/data $SPARK_HOME/tests $SPARK_HOME/licenses

# Download JARs into WORKDIR — no -P flag needed
# Iceberg-native setup: iceberg-spark-runtime (core) + iceberg-aws-bundle (S3FileIO with shaded AWS SDK v2)
# hadoop-aws + aws-java-sdk-bundle (v1, 1.12.262 — exact version hadoop-aws-3.3.4 was compiled against)
# Both coexist cleanly: iceberg-aws-bundle shades its AWS SDK under org.apache.iceberg.shaded.*
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.13-${ICEBERG_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_V1_VERSION}/aws-java-sdk-bundle-${AWS_SDK_V1_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_V2_VERSION}/bundle-${AWS_SDK_V2_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/${AWS_SDK_V2_VERSION}/url-connection-client-${AWS_SDK_V2_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/sedona/sedona-spark-shaded-3.5_2.13/${SEDONA_VERSION}/sedona-spark-shaded-3.5_2.13-${SEDONA_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/gravitino/gravitino-spark-connector-runtime-3.5_2.13/${GRAVITINO_VERSION}/gravitino-spark-connector-runtime-3.5_2.13-${GRAVITINO_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/datasyslab/geotools-wrapper/${GEOTOOLS_WRAPPER_VERSION}/geotools-wrapper-${GEOTOOLS_WRAPPER_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/com/uber/h3/${H3_VERSION}/h3-${H3_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/spark/spark-connect_2.13/${SPARK_VERSION}/spark-connect_2.13-${SPARK_VERSION}.jar

# Final Stage
FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    tini \
    software-properties-common \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN python3.11 -m pip install --no-cache-dir pandas pyarrow numpy

COPY --from=builder /opt/spark /opt/spark

WORKDIR $SPARK_HOME

RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

# Baseline spark-defaults.conf — executor defaults (no ConfigMap mounted on executors).
# GravitinoSparkPlugin on the driver broadcasts catalog registrations to executors,
# so no per-catalog config is needed here. Plugin + metalake refs are included so
# executor-side plugin init (if any) can reach Gravitino directly.
RUN printf "spark.network.timeout 120\n\
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
spark.plugins org.apache.gravitino.spark.connector.plugin.GravitinoSparkPlugin\n\
spark.sql.gravitino.metalake enterprise_metalake\n\
spark.sql.gravitino.uri http://gravitino.default.svc.cluster.local:8090\n\
spark.sql.gravitino.enableIcebergSupport true\n" > $SPARK_HOME/conf/spark-defaults.conf

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
