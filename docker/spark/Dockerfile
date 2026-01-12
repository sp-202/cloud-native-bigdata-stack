# Use valid Java 17 base image (official Spark images for 3.5.1+ with Scala 2.13 don't exist on Docker Hub)
FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_VERSION=3.5.3
ENV HADOOP_VERSION=3
ENV SCALA_VERSION=2.13
ENV DELTA_VERSION=3.2.0
ENV UC_VERSION=0.3.1
ENV ICEBERG_VERSION=1.5.2
ENV HADOOP_AWS_VERSION=3.3.4
ENV AWS_SDK_VERSION=1.12.262
ENV POSTGRES_VERSION=42.6.0
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    tini \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y \
    python3.11 \
    python3.11-distutils \
    python3.11-dev \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Install PySpark executor dependencies
RUN python3.11 -m pip install --no-cache-dir pandas pyarrow numpy

# Download and install Spark w/ Scala 2.13 (includes Hadoop 3)
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION} ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${SCALA_VERSION}.tgz

# Download compatible JARs for Spark 3.5 (Scala 2.13)
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/io/delta/delta-iceberg_2.13/${DELTA_VERSION}/delta-iceberg_2.13-${DELTA_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/${DELTA_VERSION}/delta-spark_2.13-${DELTA_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.13/${UC_VERSION}/unitycatalog-spark_2.13-${UC_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/${UC_VERSION}/unitycatalog-client-${UC_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.13-${ICEBERG_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar -P $SPARK_HOME/jars/ && \
    # Fix Guava version conflict for Unity Catalog
    rm $SPARK_HOME/jars/guava-14.0.1.jar && \
    wget https://repo1.maven.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar -P $SPARK_HOME/jars/ && \
    wget https://repo1.maven.org/maven2/com/google/guava/failureaccess/1.0.1/failureaccess-1.0.1.jar -P $SPARK_HOME/jars/

WORKDIR $SPARK_HOME

# Copy and set official Spark K8s entrypoint
RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
