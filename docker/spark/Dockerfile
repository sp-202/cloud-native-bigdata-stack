# Use valid Java 17 base image (official Spark images for 3.5.1+ with Scala 2.13 don't exist on Docker Hub)
FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_VERSION=3.5.7
ENV HADOOP_VERSION=3
ENV SCALA_VERSION=2.13
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Download and install Spark 3.5.7 w/ Scala 2.13 (includes Hadoop 3)
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION} ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz

# Download compatible JARs for Spark 3.5 (Scala 2.13)
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/3.2.1/delta-spark_2.13-3.2.1.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/3.2.1/delta-storage-3.2.1.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.13/0.3.1/unitycatalog-spark_2.13-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/0.3.1/unitycatalog-client-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.13/1.5.2/iceberg-spark-runtime-3.5_2.13-1.5.2.jar && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

WORKDIR $SPARK_HOME

# Copy and set official Spark K8s entrypoint
RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
