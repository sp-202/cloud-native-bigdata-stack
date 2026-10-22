# Builder Stage
# eclipse-temurin:17-jdk-noble (Ubuntu 24.04, Python 3.12 by default), multi-arch. Stock
# Apache Spark from the Apache archive -- this branch (rke2) carries no Comet: everything in
# the image is JVM or pure Python, so the same Dockerfile builds for linux/amd64 (the RKE2
# nodes) or any other platform buildx is asked for.
FROM eclipse-temurin:17-jdk-noble AS builder

ENV SPARK_VERSION=3.5.8 \
    SCALA_VERSION=2.13 \
    ICEBERG_VERSION=1.10.1 \
    HADOOP_AWS_VERSION=3.3.4 \
    AWS_SDK_V1_VERSION=1.12.262 \
    AWS_SDK_V2_VERSION=2.29.52 \
    GRAVITINO_VERSION=1.2.0 \
    POSTGRES_VERSION=42.6.0 \
    KAFKA_CLIENTS_VERSION=3.4.1 \
    COMMONS_POOL2_VERSION=2.11.1 \
    SPARK_HOME=/opt/spark

RUN apt-get update && apt-get install -y wget curl zip unzip

# Official binary distribution (Hadoop 3, Scala 2.13), verified against the published SHA-512.
# The .sha512 file comes in two layouts across releases ("name: HEX HEX ..." split over lines,
# or sha512sum's "HEX  name"); squeezing whitespace and taking the first 128-hex-char run reads
# both.
RUN set -eu; \
    tgz="spark-${SPARK_VERSION}-bin-hadoop3-scala${SCALA_VERSION}.tgz"; \
    base="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}"; \
    wget -q "${base}/${tgz}" -O /tmp/spark.tgz; \
    wget -q "${base}/${tgz}.sha512" -O /tmp/spark.tgz.sha512; \
    want=$(tr -d ' \n\r\t' < /tmp/spark.tgz.sha512 | grep -oiE '[0-9a-f]{128}' | head -1 | tr 'A-F' 'a-f'); \
    have=$(sha512sum /tmp/spark.tgz | cut -d' ' -f1); \
    [ -n "$want" ] && [ "$want" = "$have" ] || { echo "SHA-512 mismatch for ${tgz}" >&2; exit 1; }; \
    mkdir -p /tmp/spark-extract; \
    tar -xzf /tmp/spark.tgz -C /tmp/spark-extract; \
    mv /tmp/spark-extract/*/ ${SPARK_HOME}; \
    rm -rf /tmp/spark-extract /tmp/spark.tgz /tmp/spark.tgz.sha512

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
    wget https://repo1.maven.org/maven2/org/apache/gravitino/gravitino-spark-connector-runtime-3.5_2.13/${GRAVITINO_VERSION}/gravitino-spark-connector-runtime-3.5_2.13-${GRAVITINO_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/spark/spark-connect_2.13/${SPARK_VERSION}/spark-connect_2.13-${SPARK_VERSION}.jar

# Structured Streaming from Kafka (the IIoT dcs.raw topic, charts/iiot). Pinned to what
# spark-sql-kafka 3.5.x is built against (kafka-clients 3.4.1, commons-pool2 2.11.1), so jobs
# need no --packages download at submit time.
RUN wget https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.13/${SPARK_VERSION}/spark-sql-kafka-0-10_2.13-${SPARK_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.13/${SPARK_VERSION}/spark-token-provider-kafka-0-10_2.13-${SPARK_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar && \
    wget https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/${COMMONS_POOL2_VERSION}/commons-pool2-${COMMONS_POOL2_VERSION}.jar

# No jar may bundle its own unrelocated SLF4J. Spark 3.5 ships slf4j-api 2.0.7 with a log4j 2.x
# provider; a second org/slf4j/LoggerFactory from an older API (geotools-wrapper 1.8.1-33.1
# carried 1.7.36) can win the classpath race, find no 1.x binding and fall back to NOP --
# silently discarding every Spark JVM log line, which is what happened on the 29 Sep runs.
# This check fails the build if any jar added later reintroduces the problem.
RUN bad=""; for j in $SPARK_HOME/jars/*.jar; do \
      case "$(basename "$j")" in slf4j-*|jcl-over-slf4j-*|jul-to-slf4j-*|log4j-slf4j*) continue ;; esac; \
      if unzip -Z1 "$j" 2>/dev/null | grep -q '^org/slf4j/LoggerFactory.class$'; then bad="$bad $(basename "$j")"; fi; \
    done; \
    if [ -n "$bad" ]; then echo "jars bundling unrelocated SLF4J:$bad" >&2; exit 1; fi

# Final Stage
FROM eclipse-temurin:17-jdk-noble

ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    tini \
    curl \
    python3 \
    python3-pip \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --break-system-packages pandas pyarrow numpy

COPY --from=builder /opt/spark /opt/spark

WORKDIR $SPARK_HOME

RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

# Baseline spark-defaults.conf — executor defaults (no ConfigMap mounted on executors).
# UNITS. Spark and Hadoop disagree on the default unit per key, so a bare integer means
# different things on adjacent lines:
#   spark.network.timeout, spark.files.fetchTimeout  -> timeConf(SECONDS)
#   spark.executor.heartbeatInterval                 -> timeConf(MILLISECONDS), default "10s"
#   fs.s3a.*.timeout                                 -> milliseconds (Hadoop 3.3.4)
# Suffix anything Spark accepts a suffix for. fs.s3a.connection.timeout /
# connection.establish.timeout are left at hadoop-aws's in-code defaults (200000ms / 5000ms),
# sized for 128MB multipart uploads.
#
# No S3 endpoint or credentials here: the image works against any S3. On RKE2 the job sets
# spark.hadoop.fs.s3a.endpoint (SeaweedFS, path-style, no SSL) and gets AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY from the lakehouse-s3 Secret (examples/spark-jobs/rke2-*.yaml).
#
# spark.plugins and spark.sql.extensions are deliberately NOT set here. Neither is additive: a
# job that sets either in its SparkConf replaces this value outright rather than adding to it,
# so baking them creates the illusion that Gravitino/Iceberg are active when they have been
# silently dropped. Declare the full list per job instead, e.g.
#   spark.plugins: "org.apache.gravitino.spark.connector.plugin.GravitinoSparkPlugin"
RUN printf "spark.network.timeout 120s\n\
spark.files.fetchTimeout 60s\n\
spark.executor.heartbeatInterval 10s\n\
spark.hadoop.fs.s3a.threads.keepalivetime 60\n\
spark.hadoop.fs.s3a.multipart.purge.age 86400\n\
spark.serializer org.apache.spark.serializer.KryoSerializer\n\
spark.sql.gravitino.metalake enterprise_metalake\n\
spark.sql.gravitino.uri http://gravitino.default.svc.cluster.local:8090\n\
spark.sql.gravitino.enableIcebergSupport true\n" > $SPARK_HOME/conf/spark-defaults.conf

# spark-env.sh — DRIVER ONLY on Kubernetes (entrypoint.sh -> spark-submit -> load-spark-env.sh);
# executors start as a bare `java ... KubernetesExecutorBackend` and never source it.
# python3 is the system Python installed above — pandas/pyarrow/numpy are already in its
# site-packages, so no PYTHONPATH/venv override is needed.
RUN printf "#!/usr/bin/env bash\n\
export PYSPARK_PYTHON=/usr/bin/python3\n\
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3\n" > $SPARK_HOME/conf/spark-env.sh && \
    chmod +x $SPARK_HOME/conf/spark-env.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
