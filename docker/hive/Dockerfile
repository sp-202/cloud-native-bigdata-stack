FROM apache/hive:4.1.0

# Switch to root to install packages
USER root

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Download Postgres JDBC driver
RUN curl -o /opt/hive/lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# Download AWS JARs for S3 support (Hadoop 3.4.1 — matching Spark 4.0.1)
RUN curl -o /opt/hive/lib/hadoop-aws-3.4.1.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    curl -o /opt/hive/lib/aws-java-sdk-bundle-1.12.367.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar

# Fix permissions
RUN mkdir -p /home/hive/.beeline && \
    chown -R hive:hive /home/hive && \
    chown -R hive:hive /opt/hive

USER hive
