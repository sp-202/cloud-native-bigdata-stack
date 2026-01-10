FROM eclipse-temurin:17-jdk-jammy

ENV SPARK_VERSION=4.0.1
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Download and install Spark 4.0.1 Scala 2.13 (includes Hadoop 3.4.1)
RUN wget https://dlcdn.apache.org/spark/spark-4.0.1/spark-4.0.1-bin-hadoop3.tgz && \
    tar -xzf spark-4.0.1-bin-hadoop3.tgz && \
    mv spark-4.0.1-bin-hadoop3 ${SPARK_HOME} && \
    rm spark-4.0.1-bin-hadoop3.tgz

# Download additional JARs
WORKDIR $SPARK_HOME/jars
RUN wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/4.0.0/delta-spark_2.13-4.0.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/4.0.0/delta-storage-4.0.0.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.13/0.3.1/unitycatalog-spark_2.13-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/0.3.1/unitycatalog-client-0.3.1.jar && \
    wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.0_2.13/1.10.1/iceberg-spark-runtime-4.0_2.13-1.10.1.jar && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.24.6/bundle-2.24.6.jar

WORKDIR $SPARK_HOME

# Create entrypoint script
RUN echo '#!/bin/bash\n\
    if [ -z "$SPARK_NO_DAEMONIZE" ]; then\n\
        exec tini -s -- "$@"\n\
    else\n\
        exec "$@"\n\
    fi' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
