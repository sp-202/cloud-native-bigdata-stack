# Use official Jupyter PySpark image as base
FROM jupyter/pyspark-notebook:spark-3.5.0

USER root

# Install system dependencies if any
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

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

# Note: 00-spark-init.py will be mounted or copied here. 
# We can also bake it in if it's stable.
COPY 00-spark-init.py /home/jovyan/.ipython/profile_default/startup/00-spark-init.py

# Fix permissions
USER root
RUN chown -R ${NB_UID}:${NB_GID} /home/jovyan/.ipython/ && \
    chmod -R 755 /home/jovyan/.ipython/
USER ${NB_UID}

WORKDIR /home/jovyan/work
