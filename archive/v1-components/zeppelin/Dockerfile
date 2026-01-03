FROM apache/zeppelin:0.12.0

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    grep \
    sed \
    && rm -rf /var/lib/apt/lists/*

# Spark versions (Environment variables for reference or if Operator injects them)
ENV HADOOP_VERSION=3

# NOTE: We rely on the base Zeppelin image or external provision for Spark binaries/Spark Operator.
# We DO NOT install a separate Spark distribution here.
# However, we define SPARK_HOME to organize the Jars we are downloading.
ENV SPARK_HOME=/opt/spark
RUN mkdir -p $SPARK_HOME/jars

# Download EXACT same JARs as Spark Image
WORKDIR $SPARK_HOME/jars
RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/3.2.0/delta-spark_2.12-3.2.0.jar && \
    wget https://repo1.maven.org/maven2/io/delta/delta-storage/3.2.0/delta-storage-3.2.0.jar

# Setup defaults
WORKDIR $SPARK_HOME

# Copy Configs and Custom Jars from Build Context
# Note: Build context must include spark/conf and spark/jars
COPY spark/conf/spark-defaults.conf $SPARK_HOME/conf/spark-defaults.conf
RUN mkdir -p $SPARK_HOME/custom-jars
COPY spark/jars/* $SPARK_HOME/custom-jars/

# Environment Variables for Zeppelin to use Spark
ENV ZEPPELIN_Addr=0.0.0.0
# Important for connecting to newer Spark versions
ENV ZEPPELIN_SPARK_ENABLESUPPORTEDVERSIONCHECK=false

WORKDIR /opt/zeppelin
USER 1000
