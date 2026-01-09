FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_VERSION=3.5.7
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install dependencies including librocksdbjni
# Note: Spark 3.5.7 includes rocksdbjni in the jars folder, but we ensure system deps are present
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Download and install Spark
# The official binary includes RocksDB support
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# Download AWS JARs and other dependencies
WORKDIR $SPARK_HOME/jars
RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/3.2.0/delta-spark_2.12-3.2.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/3.2.0/delta-storage-3.2.0.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.12/0.2.1/unitycatalog-spark_2.12-0.2.1.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/0.2.1/unitycatalog-client-0.2.1.jar

WORKDIR $SPARK_HOME

# Create entrypoint script
RUN echo '#!/bin/bash\n\
    if [ -z "$JAVA_HOME" ]; then\n\
    export JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep "java.home" | awk "{print \$3}")\n\
    fi\n\
    \n\
    SPARK_K8S_CMD="$1"\n\
    case "$SPARK_K8S_CMD" in\n\
    driver|executor)\n\
    shift 1\n\
    exec /opt/spark/bin/spark-class org.apache.spark.deploy.k8s.SparkKubernetesClient"$SPARK_K8S_CMD" "$@"\n\
    ;;\n\
    *)\n\
    exec "$@"\n\
    ;;\n\
    esac\n\
    ' > /opt/entrypoint.sh && chmod +x /opt/entrypoint.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
