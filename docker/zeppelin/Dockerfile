FROM eclipse-temurin:17-jdk-jammy

# Install dependencies and Zeppelin
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    grep \
    sed \
    python3 \
    python3-pip \
    r-base \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Download and install Zeppelin 0.12.0 (Full package to include interpreters)
ENV ZEPPELIN_VERSION=0.12.0
ENV ZEPPELIN_HOME=/opt/zeppelin
RUN wget https://dlcdn.apache.org/zeppelin/zeppelin-${ZEPPELIN_VERSION}/zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz && \
    tar -xzf zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz && \
    mv zeppelin-${ZEPPELIN_VERSION}-bin-all ${ZEPPELIN_HOME} && \
    rm zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz

# Setup Spark directories
ENV SPARK_HOME=/opt/spark
RUN mkdir -p $SPARK_HOME/jars $SPARK_HOME/conf $SPARK_HOME/custom-jars

# Download EXACT same JARs as Spark Image (these will be in classpath)
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/4.0.0/delta-spark_2.13-4.0.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/4.0.0/delta-storage-4.0.0.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.13/0.3.1/unitycatalog-spark_2.13-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/0.3.1/unitycatalog-client-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar

# Setup User and Permissions
RUN groupadd -r zeppelin --gid=1000 && \
    useradd -r -g zeppelin --uid=1000 -d ${ZEPPELIN_HOME} zeppelin && \
    chown -R 1000:1000 ${ZEPPELIN_HOME} && \
    chown -R 1000:1000 $SPARK_HOME && \
    chmod +x ${ZEPPELIN_HOME}/bin/*.sh

# Environment Variables
ENV ZEPPELIN_ADDR=0.0.0.0
ENV ZEPPELIN_SPARK_ENABLESUPPORTEDVERSIONCHECK=false

WORKDIR ${ZEPPELIN_HOME}
USER 1000

EXPOSE 8080 4040

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-c", "bin/zeppelin-daemon.sh start && sleep 5 && tail -F logs/*.out"]
