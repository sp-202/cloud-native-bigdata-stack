# Use Spark 3.5.7 (User Requested) with Scala 2.13 and Java 17
FROM apache/spark:3.5.7-scala2.13-java17

USER root

# Install dependencies
RUN apt-get update && apt-get install -y curl vim && rm -rf /var/lib/apt/lists/*

# Set up Spark environment
ENV SPARK_HOME=/opt/spark
ENV PATH=$SPARK_HOME/bin:$PATH

# --- Compatible Versions for Spark 3.5.x (Scala 2.13) ---
# Delta Lake 3.2.1 (First stable release with UniForm support)
# Iceberg 1.5.2 (Matches Spark 3.5 ABI)
# Unity Catalog 0.3.1 (Required for S3 support)
# AWS SDK bundle (Required for S3A)
# --------------------------------------------------------
RUN curl -o $SPARK_HOME/jars/delta-spark_2.13-3.2.1.jar https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/3.2.1/delta-spark_2.13-3.2.1.jar && \
    curl -o $SPARK_HOME/jars/delta-storage-3.2.1.jar https://repo1.maven.org/maven2/io/delta/delta-storage/3.2.1/delta-storage-3.2.1.jar && \
    curl -o $SPARK_HOME/jars/unitycatalog-spark_2.13-0.3.1.jar https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-spark_2.13/0.3.1/unitycatalog-spark_2.13-0.3.1.jar && \
    curl -o $SPARK_HOME/jars/unitycatalog-client-0.3.1.jar https://repo1.maven.org/maven2/io/unitycatalog/unitycatalog-client/0.3.1/unitycatalog-client-0.3.1.jar && \
    curl -o $SPARK_HOME/jars/iceberg-spark-runtime-3.5_2.13-1.5.2.jar https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.13/1.5.2/iceberg-spark-runtime-3.5_2.13-1.5.2.jar && \
    curl -o $SPARK_HOME/jars/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    curl -o $SPARK_HOME/jars/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    curl -o $SPARK_HOME/jars/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# Configuration directory
WORKDIR $SPARK_HOME

# Copy and set official Spark K8s entrypoint
RUN cp $SPARK_HOME/kubernetes/dockerfiles/spark/entrypoint.sh /opt/entrypoint.sh && \
    chmod +x /opt/entrypoint.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
