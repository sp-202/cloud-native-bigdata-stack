# Base: ARM64-native Eclipse Temurin JDK 17 on UBI9-minimal
# Using Hive 3.1.3 (pure Java JARs — arch-independent) on an ARM64-native JDK image
# Hive 3.1.3 is compatible with Spark 4.0's bundled hive-metastore-2.3.10 client
# NOTE: apache/hive:4.1.0 was ARM64-native but incompatible with Spark's Hive 2.3 client
#       (HMS 4.x removed get_table from the standalone metastore Thrift processor)
FROM eclipse-temurin:17-jre-ubi9-minimal

USER root

# Install required system tools
RUN microdnf install -y curl procps && microdnf clean all

# Hive 3.1.3 environment
ENV HIVE_VERSION=3.1.3
ENV HIVE_HOME=/opt/hive
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_VERSION=3.4.1
ENV PATH=${HIVE_HOME}/bin:${HADOOP_HOME}/bin:${PATH}

# Download and install Hadoop (needed for bin/hadoop and core JARs)
RUN curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    | tar -xz -C /opt && \
    ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop

# Download and install Hive 3.1.3
RUN curl -fsSL https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz \
    | tar -xz -C /opt && \
    ln -s /opt/apache-hive-${HIVE_VERSION}-bin /opt/hive

# Remove conflicting Guava (Hive 3.1.3 ships guava-19, Hadoop 3.4.1 needs guava-27)
RUN rm -f ${HIVE_HOME}/lib/guava-19.0.jar && \
    cp ${HADOOP_HOME}/share/hadoop/hdfs/lib/guava-27.0-jre.jar ${HIVE_HOME}/lib/

# Postgres JDBC driver
RUN curl -o ${HIVE_HOME}/lib/postgresql-42.6.0.jar \
    https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# AWS S3 support (Hadoop 3.4.1 + AWS SDK v2)
RUN curl -o ${HIVE_HOME}/lib/hadoop-aws-3.4.1.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    curl -o ${HIVE_HOME}/lib/bundle-2.29.52.jar \
      https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.29.52/bundle-2.29.52.jar && \
    curl -o ${HIVE_HOME}/lib/url-connection-client-2.29.52.jar \
      https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.29.52/url-connection-client-2.29.52.jar

# Create hive user and required directories
RUN groupadd -r hive && useradd -r -g hive -d /home/hive -m hive && \
    mkdir -p /home/hive/.beeline /tmp/hive && \
    chown -R hive:hive /home/hive /opt/hive /tmp/hive

USER hive

EXPOSE 9083 10000
