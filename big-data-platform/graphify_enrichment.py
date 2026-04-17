#!/usr/bin/env python3
"""
Graphify Enrichment Script for Big Data Platform
Documents YAML configuration relationships and component dependencies.
Run after: graphify update .
Purpose: Enhance the knowledge graph with Helm chart semantics
"""

import json
import sys
from pathlib import Path


def create_semantic_relationships():
    """
    Define component relationships across the big-data-platform Helm chart.
    Returns dict of component nodes and their connections.
    """
    relationships = {
        "components": {
            "gravitino": {
                "name": "Apache Gravitino 1.2.0",
                "role": "Unified AI & Data Metadata Lake with Iceberg REST Catalog (IRC)",
                "type": "metadata-catalog",
                "endpoints": {"api": ":8090", "iceberg_rest": ":9001"},
                "dependencies": ["postgresql", "minio", "spark"],
                "consumed_by": ["spark", "starrocks", "jupyterhub", "hive-metastore"],
                "config": {"metalake": "enterprise_metalake", "image": "apache/gravitino:1.2.0"},
            },
            "spark": {
                "name": "Apache Spark 3.5.8",
                "role": "Distributed compute engine with Iceberg + Gravitino plugins",
                "type": "compute-engine",
                "image": "subhodeep2022/spark-bigdata:spark-3.5.8-v12-iceberg-gravitino",
                "dependencies": ["gravitino", "hive-metastore", "postgresql", "minio", "airflow"],
                "plugins": ["GravitinoSparkPlugin", "Iceberg-1.10.1", "Spark Connect"],
                "produced_by": ["airflow", "jupyterhub", "spark-connect-server"],
            },
            "hive-metastore": {
                "name": "Apache Hive Metastore 3.1.3",
                "role": "Legacy metadata store + compatibility fallback",
                "type": "metadata-store",
                "service": "hive-metastore.default.svc.cluster.local:9083",
                "dependencies": ["postgresql", "minio"],
                "consumed_by": ["spark", "starrocks", "airflow"],
            },
            "minio": {
                "name": "MinIO",
                "role": "S3-compatible distributed object storage + data lake root",
                "type": "object-storage",
                "service": "minio.default.svc.cluster.local:9000",
                "endpoint": "http://minio.default.svc.cluster.local:9000",
                "dependencies": [],  # foundational
                "consumed_by": ["spark", "gravitino", "hive-metastore", "starrocks", "jupyterhub", "airflow"],
                "buckets": ["spark-logs", "gravitino-meta", "hive-tables", "user-data"],
                "affinity": "minio-worker",
            },
            "postgresql": {
                "name": "PostgreSQL 15+",
                "role": "ACID-compliant relational metadata store",
                "type": "relational-database",
                "service": "postgres.default.svc.cluster.local:5432",
                "dependencies": [],  # foundational
                "consumed_by": ["hive-metastore", "airflow", "superset", "gravitino", "jupyterhub"],
                "databases": ["airflow_db", "hive_metastore", "superset_db", "gravitino_db"],
                "affinity": "k8s-gp-node",
            },
            "airflow": {
                "name": "Apache Airflow 2.7.1",
                "role": "Workflow orchestration & DAG scheduling",
                "type": "orchestration",
                "image": "apache/airflow:2.7.1",
                "executor": "KubernetesExecutor",
                "dependencies": ["postgresql", "spark-operator"],
                "triggers": ["spark", "airflow-user-init", "airflow-db-migrate"],
                "affinity": "k8s-gp-node",
            },
            "starrocks": {
                "name": "StarRocks",
                "role": "OLAP query engine + vectorized MPP database",
                "type": "analytics-engine",
                "operator": "starrocks-kubernetes-operator-1.9.8",
                "dependencies": ["spark", "gravitino", "postgresql"],
                "consumed_by": ["superset", "jupyterhub"],
                "catalog": "Iceberg (native via Gravitino)",
                "affinity": "k8s-gp-node",
            },
            "jupyterhub": {
                "name": "JupyterHub",
                "role": "Multi-user collaborative notebooks",
                "type": "interactive-compute",
                "image": "subhodeep2022/spark-bigdata:jupyterhub-4.0.7-pyspark-scala-sql-prod-v3",
                "spawner": "KubeSpawner",
                "dependencies": ["postgresql", "spark", "minio"],
                "libraries": ["PySpark", "Scala", "SQL", "Pandas", "NumPy"],
            },
            "superset": {
                "name": "Apache Superset",
                "role": "Visual analytics + dashboard creation",
                "type": "bi-dashboard",
                "version": "0.12.0",
                "dependencies": ["postgresql", "starrocks", "spark", "hive-metastore"],
                "connectors": ["StarRocks (JDBC)", "Spark SQL", "Hive"],
                "init_job": "superset-init-job",
            },
            "cloudflared": {
                "name": "Cloudflared",
                "role": "Secure tunnel to dailyblogstudio.com",
                "type": "networking-tunnel",
                "tunnel_id": "91e5be1d-3b51-4cac-aebf-d330aafda394",
                "routes": ["jupyterhub", "superset", "headlamp", "grafana", "spark-history-server", "gravitino-api"],
                "affinity": "control-plane",
                "network_policy": "Restricted egress to tunnel only",
            },
            "spark-history-server": {
                "name": "Spark History Server",
                "role": "Spark job history + event log viewer",
                "type": "monitoring",
                "dependencies": ["minio", "spark"],
                "log_source": "MinIO (spark-logs bucket)",
            },
            "spark-operator": {
                "name": "Spark Operator",
                "role": "SparkApplication CRD controller",
                "type": "kubernetes-operator",
                "crd": "sparkoperator.k8s.io_sparkapplications",
                "version": "2.4.0",
                "affinity": "control-plane",
            },
            "redis": {
                "name": "Redis",
                "role": "Cache + task queuing (optional)",
                "type": "cache",
                "dependencies": [],
                "consumed_by": ["airflow", "jupyterhub", "superset"],
                "enabled": "redis.enabled",
            },
            "prometheus": {
                "name": "Prometheus (kube-prometheus-stack)",
                "role": "Time-series metrics database",
                "type": "metrics",
                "version": "56.6.2",
                "scrape_targets": ["spark", "airflow", "postgresql", "minio", "starrocks", "k8s-api"],
            },
            "grafana": {
                "name": "Grafana",
                "role": "Metrics visualization + alerting",
                "type": "observability-ui",
                "data_sources": ["prometheus", "loki"],
                "dashboards": ["kubernetes", "spark-jobs", "airflow", "data-platform-health"],
                "port": "3000",
                "tunnel": "cloudflared",
            },
            "loki": {
                "name": "Loki Stack",
                "role": "Log aggregation (Prometheus-style)",
                "type": "logging",
                "version": "2.10.2",
                "storage": "minio",
                "retention": {"hot": "7d", "warm": "30d"},
            },
            "headlamp": {
                "name": "Headlamp",
                "role": "Web-based Kubernetes dashboard",
                "type": "k8s-ui",
                "tunnel": "cloudflared",
            },
            "ingress": {
                "name": "Ingress Controller",
                "role": "Path-based routing + TLS termination",
                "type": "networking",
                "routes": ["gravitino", "spark-history-server", "jupyterhub", "superset"],
            },
        },
        "data_flow_patterns": {
            "spark_etl_with_gravitino": {
                "name": "Spark ETL with Gravitino Catalog",
                "steps": [
                    "External Data Source",
                    "Spark Job (KubernetesExecutor or SparkApplication)",
                    "GravitinoSparkPlugin (catalog discovery)",
                    "Iceberg Table Format (via Gravitino IRC @ :9001)",
                    "MinIO S3 Storage (/iceberg/ bucket)",
                    "StarRocks Ingestion (real-time OLAP)",
                    "Superset / JupyterHub (visualization & analysis)",
                ],
                "components": ["spark", "gravitino", "minio", "starrocks", "superset", "jupyterhub"],
            },
            "airflow_orchestrated_spark": {
                "name": "Airflow-Orchestrated Spark Workflows",
                "steps": [
                    "Airflow Scheduler",
                    "DAG Trigger → SparkApplication CRD",
                    "Spark Operator creates Pod",
                    "Spark Driver reads from Gravitino → Workers compute",
                    "Results to MinIO (or Iceberg catalog)",
                    "Task log persisted: PostgreSQL + MinIO",
                    "Metadata sync → Gravitino metastore",
                ],
                "components": ["airflow", "spark-operator", "spark", "minio", "postgresql", "gravitino"],
            },
            "interactive_jupyterhub_analysis": {
                "name": "Interactive Analysis via JupyterHub",
                "steps": [
                    "User Login → Headlamp (K8s dashboard)",
                    "JupyterHub Session (KubeSpawner)",
                    "PySpark Kernel ↔ Spark Cluster",
                    "GravitinoSparkPlugin (catalog)",
                    "Query Iceberg tables in Gravitino",
                    "Push aggregates → StarRocks for BI",
                ],
                "components": ["jupyterhub", "spark", "gravitino", "minio", "starrocks"],
            },
        },
        "init_jobs": {
            "gravitino-init": {
                "role": "Creates Gravitino catalogs + metastore DB",
                "depends_on": ["postgresql", "gravitino"],
                "produces": ["gravitino_db"],
            },
            "airflow-db-migrate": {
                "role": "Alembic migrations for Airflow metadata DB",
                "depends_on": ["postgresql"],
                "produces": ["airflow_db"],
            },
            "airflow-user-init": {
                "role": "Creates Airflow admin user",
                "depends_on": ["airflow-db-migrate"],
                "produces": ["admin_user"],
            },
            "superset-init-job": {
                "role": "Creates admin user + default DB connections",
                "depends_on": ["postgresql", "superset"],
                "produces": ["superset_connections"],
                "status": "Pending fix (deployment issue noted)",
            },
        },
        "node_affinity": {
            "k8s-gp-node": {
                "label": "node-role.kubernetes.io/k8s-gp-node",
                "components": ["postgresql", "airflow", "starrocks", "gravitino", "redis", "prometheus", "grafana"],
                "purpose": "General purpose computing",
            },
            "spark-node": {
                "label": "node-role.kubernetes.io/spark-node",
                "components": ["spark-executor-primary"],
                "purpose": "Primary Spark executor nodes",
            },
            "spark-worker": {
                "label": "node-role.kubernetes.io/spark-worker",
                "components": ["spark-executor-secondary"],
                "purpose": "Secondary Spark executor (overflow)",
            },
            "minio-worker": {
                "label": "node-role.kubernetes.io/minio-worker",
                "components": ["minio"],
                "purpose": "High I/O workload isolation",
            },
            "control-plane": {
                "label": "node-role.kubernetes.io/control-plane",
                "components": ["spark-operator", "cloudflared", "airflow-webserver"],
                "purpose": "Cluster control plane functions",
            },
        },
        "critical_dependencies": {
            "tier_0_foundational": [
                "persistence (OpenEBS)",
                "namespaces",
                "postgresql",
            ],
            "tier_1_core_data": [
                "minio",
                "hive-metastore",
                "redis (optional)",
            ],
            "tier_2_catalog_compute": [
                "gravitino",
                "spark-operator",
                "spark-history-server",
            ],
            "tier_3_orchestration": [
                "airflow",
                "spark-connect-server (optional)",
            ],
            "tier_4_analytics_access": [
                "starrocks (optional)",
                "jupyterhub",
                "superset",
            ],
            "tier_5_monitoring": [
                "kube-prometheus-stack",
                "loki-stack",
                "cloudflared",
                "ingress",
                "headlamp",
            ],
        },
    }
    return relationships


def enrich_graph_json(graph_path: str):
    """
    Load the existing graph.json and enrich it with semantic relationships.
    """
    graph_path = Path(graph_path)

    # Load existing graph or create minimal structure
    if graph_path.exists():
        with open(graph_path) as f:
            graph = json.load(f)
    else:
        graph = {"nodes": [], "edges": []}

    # Add semantic relationships as nodes and edges
    relationships = create_semantic_relationships()

    # Build node map from relationships
    for component_name, component_info in relationships["components"].items():
        # Add component as node if not already present
        existing_node = next((n for n in graph.get("nodes", []) if n.get("label") == component_name), None)
        if not existing_node:
            graph.setdefault("nodes", []).append({
                "id": component_name,
                "label": component_name,
                "description": f"{component_info.get('role', '')}",
                "type": component_info.get("type", "component"),
                "metadata": {k: v for k, v in component_info.items() if k not in ["consumed_by", "dependencies"]},
            })

    # Create edges from dependencies
    edges_added = set()
    for component_name, component_info in relationships["components"].items():
        # Dependency edges
        for dep in component_info.get("dependencies", []):
            edge_key = (component_name, dep)
            if edge_key not in edges_added:
                graph.setdefault("edges", []).append({
                    "source": component_name,
                    "target": dep,
                    "relationship": "depends_on",
                    "label": f"{component_name} depends on {dep}",
                })
                edges_added.add(edge_key)

        # Consumed-by edges (reverse direction)
        for consumer in component_info.get("consumed_by", []):
            edge_key = (consumer, component_name)
            if edge_key not in edges_added:
                graph.setdefault("edges", []).append({
                    "source": consumer,
                    "target": component_name,
                    "relationship": "consumes",
                    "label": f"{consumer} consumes {component_name}",
                })
                edges_added.add(edge_key)

    return graph


def main():
    """Main entry point."""
    graphify_out = Path("graphify-out")
    graphify_out.mkdir(exist_ok=True)

    graph_path = graphify_out / "graph.json"

    # Enrich the graph
    enriched_graph = enrich_graph_json(str(graph_path))

    # Save the enriched graph
    with open(graph_path, "w") as f:
        json.dump(enriched_graph, f, indent=2)

    print(f"✓ Graphify enrichment complete!")
    print(f"  Nodes: {len(enriched_graph.get('nodes', []))}")
    print(f"  Edges: {len(enriched_graph.get('edges', []))}")
    print(f"  Graph saved to: {graph_path}")


if __name__ == "__main__":
    main()
