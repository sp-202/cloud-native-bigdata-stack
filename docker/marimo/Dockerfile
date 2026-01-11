# Use Spark v5 image as base (contains Spark, Python 3.11, etc.)
FROM subhodeep2022/spark-bigdata:spark-3.5.3-uc-0.3.1-v5

USER root

# Install Marimo and additional Python dependencies
RUN python3.11 -m pip install --no-cache-dir \
    marimo \
    pandas \
    pyarrow \
    numpy

# Create a non-root user
RUN useradd -m -s /bin/bash marimo
USER marimo
WORKDIR /home/marimo

# Expose Marimo port
EXPOSE 8080

# Environment variables for Spark
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip

# Run Marimo in edit mode
CMD ["python3.11", "-m", "marimo", "edit", "--host", "0.0.0.0", "--port", "8080", "--no-token"]
