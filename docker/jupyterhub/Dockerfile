# Use official Jupyter PySpark image as base (Spark 3.5.x series)
FROM jupyter/pyspark-notebook:spark-3.5.4

USER root

# Install system dependencies if any
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

# Pin PySpark to exactly match Spark Connect server version (3.5.8).
# The base image ships with Spark 3.5.4 binaries but for Spark Connect (remote)
# only the pyspark Python client version matters — no local Spark JVM needed.
RUN pip install --no-cache-dir pyspark==3.5.8

# Install Python packages for SQL magic, Scala support, and S3 persistence
RUN pip install --no-cache-dir \
    sparkmagic \
    toree \
    s3contents \
    s3fs

# Install Toree Scala kernel
RUN jupyter toree install --user --spark_home=${SPARK_HOME} --kernel_name="Scala" --interpreters=Scala

# Create IPython profile and startup directory
RUN mkdir -p /home/jovyan/.ipython/profile_default/startup/

# Bake in the SparkSession auto-injection script
COPY 00-spark-init.py /home/jovyan/.ipython/profile_default/startup/00-spark-init.py

# Fix permissions
USER root
RUN chown -R ${NB_UID}:${NB_GID} /home/jovyan/.ipython/ && \
    chmod -R 755 /home/jovyan/.ipython/
USER ${NB_UID}

WORKDIR /home/jovyan/work
