FROM apache/hive:4.1.0

# Switch to root to install packages
USER root

# Install curl (UBI9-minimal uses microdnf, not apt)
# RUN microdnf install -y curl && microdnf clean all

# Download Postgres JDBC driver
RUN curl -o /opt/hive/lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar

# Download AWS JARs for S3 support (Hadoop 3.4.1 + AWS SDK v2 — matching Spark 4.0.1)
# hadoop-aws 3.4.x requires AWS SDK v2; the old aws-java-sdk-bundle (SDK v1) is NOT sufficient
RUN curl -o /opt/hive/lib/hadoop-aws-3.4.1.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    curl -o /opt/hive/lib/bundle-2.29.52.jar https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.29.52/bundle-2.29.52.jar && \
    curl -o /opt/hive/lib/url-connection-client-2.29.52.jar https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.29.52/url-connection-client-2.29.52.jar

# Fix permissions
RUN mkdir -p /home/hive/.beeline && \
    chown -R hive:hive /home/hive && \
    chown -R hive:hive /opt/hive

USER hive

