FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_VERSION=3.5.7
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Download and install Spark
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# Download AWS JARs for S3 support
# Spark 3.5.x uses Hadoop 3.3.4 by default
# Hadoop 3.3.4 uses aws-java-sdk-bundle 1.12.262
WORKDIR $SPARK_HOME/jars
RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/3.2.0/delta-spark_2.12-3.2.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/3.2.0/delta-storage-3.2.0.jar

WORKDIR $SPARK_HOME

# Expose ports
EXPOSE 8080 8081 7077 4040 18080

# Copy local configurations and jars
COPY conf/spark-defaults.conf $SPARK_HOME/conf/spark-defaults.conf
RUN mkdir -p $SPARK_HOME/custom-jars
COPY jars/* $SPARK_HOME/custom-jars/

CMD ["/bin/bash"]
