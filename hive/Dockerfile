FROM apache/hive:3.1.3

# Switch to root to install packages
USER root

# Install curl
RUN apt-get update && apt-get install -y curl

# Download Postgres JDBC driver
RUN curl -o /opt/hive/lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# Download AWS JARs for S3 support (Hadoop 3.1.0 for Hive 3.1.3)
RUN curl -o /opt/hive/lib/hadoop-aws-3.1.0.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.1.0/hadoop-aws-3.1.0.jar && \
    curl -o /opt/hive/lib/aws-java-sdk-bundle-1.11.271.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.271/aws-java-sdk-bundle-1.11.271.jar

# Fix permissions
RUN mkdir -p /home/hive/.beeline && \
    chown -R hive:hive /home/hive && \
    chown -R hive:hive /opt/hive

USER hive
