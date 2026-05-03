# Use multi-architecture base image (supports AMD64 and ARM64) 
FROM jupyter/base-notebook:python-3.10

USER root

# Install system dependencies (Java required for Spark/Scala kernel)
RUN apt-get update && apt-get install -y \
    openjdk-17-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set SPARK_HOME
ENV SPARK_HOME=/opt/spark

USER ${NB_UID}

# Install PySpark pinned to exactly match Spark Connect server version (3.5.8).
# For Spark Connect (remote execution), only the pyspark Python client version matters.
RUN pip install --no-cache-dir pyspark[connect]==3.5.8 pandas pyarrow grpcio grpcio-status

# Install Python packages for S3 persistence and Scala kernel support
# Note: sparkmagic is for Livy connections, NOT needed for Spark Connect
RUN pip install --no-cache-dir \
    toree \
    s3contents \
    s3fs

# Install Toree Scala kernel (uses Spark from PySpark installation)
RUN PYSPARK_DIST_PATH=$(python -c "import pyspark; print(pyspark.__path__[0])") && \
    jupyter toree install --user \
    --spark_home=${PYSPARK_DIST_PATH}/spark \
    --kernel_name="Scala" \
    --interpreters=Scala

# Fix permissions
USER root
RUN chown -R ${NB_UID}:${NB_GID} /home/jovyan/.ipython/ && \
    chmod -R 755 /home/jovyan/.ipython/
USER ${NB_UID}

WORKDIR /home/jovyan/work
