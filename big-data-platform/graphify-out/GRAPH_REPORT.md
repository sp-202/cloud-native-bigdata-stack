# Graph Report - /home/subhodeep/cloud-native-bigdata-stack/big-data-platform  (2026-04-17)

## Corpus Check
- 2 files · ~7,527 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 25 nodes · 7 edges · 21 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]

## God Nodes (most connected - your core abstractions)
1. `enrich_graph_json()` - 4 edges
2. `create_semantic_relationships()` - 3 edges
3. `main()` - 2 edges
4. `Define component relationships across the big-data-platform Helm chart.     Retu` - 1 edges
5. `Load the existing graph.json and enrich it with semantic relationships.` - 1 edges

## Surprising Connections (you probably didn't know these)
- `enrich_graph_json()` --calls--> `create_semantic_relationships()`  [EXTRACTED]
  /home/subhodeep/cloud-native-bigdata-stack/big-data-platform/graphify_enrichment.py → /home/subhodeep/cloud-native-bigdata-stack/big-data-platform/graphify_enrichment.py  _Bridges community 1 → community 0_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.67
Nodes (3): enrich_graph_json(), main(), Load the existing graph.json and enrich it with semantic relationships.

### Community 1 - "Community 1"
Cohesion: 1.0
Nodes (2): create_semantic_relationships(), Define component relationships across the big-data-platform Helm chart.     Retu

### Community 2 - "Community 2"
Cohesion: 1.0
Nodes (0): 

### Community 3 - "Community 3"
Cohesion: 1.0
Nodes (1): gravitino

### Community 4 - "Community 4"
Cohesion: 1.0
Nodes (1): spark

### Community 5 - "Community 5"
Cohesion: 1.0
Nodes (1): hive-metastore

### Community 6 - "Community 6"
Cohesion: 1.0
Nodes (1): minio

### Community 7 - "Community 7"
Cohesion: 1.0
Nodes (1): postgresql

### Community 8 - "Community 8"
Cohesion: 1.0
Nodes (1): airflow

### Community 9 - "Community 9"
Cohesion: 1.0
Nodes (1): starrocks

### Community 10 - "Community 10"
Cohesion: 1.0
Nodes (1): jupyterhub

### Community 11 - "Community 11"
Cohesion: 1.0
Nodes (1): superset

### Community 12 - "Community 12"
Cohesion: 1.0
Nodes (1): cloudflared

### Community 13 - "Community 13"
Cohesion: 1.0
Nodes (1): spark-history-server

### Community 14 - "Community 14"
Cohesion: 1.0
Nodes (1): spark-operator

### Community 15 - "Community 15"
Cohesion: 1.0
Nodes (1): redis

### Community 16 - "Community 16"
Cohesion: 1.0
Nodes (1): prometheus

### Community 17 - "Community 17"
Cohesion: 1.0
Nodes (1): grafana

### Community 18 - "Community 18"
Cohesion: 1.0
Nodes (1): loki

### Community 19 - "Community 19"
Cohesion: 1.0
Nodes (1): headlamp

### Community 20 - "Community 20"
Cohesion: 1.0
Nodes (1): ingress

## Knowledge Gaps
- **2 isolated node(s):** `Define component relationships across the big-data-platform Helm chart.     Retu`, `Load the existing graph.json and enrich it with semantic relationships.`
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 1`** (2 nodes): `create_semantic_relationships()`, `Define component relationships across the big-data-platform Helm chart.     Retu`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 2`** (1 nodes): `main.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 3`** (1 nodes): `gravitino`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 4`** (1 nodes): `spark`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 5`** (1 nodes): `hive-metastore`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 6`** (1 nodes): `minio`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 7`** (1 nodes): `postgresql`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 8`** (1 nodes): `airflow`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 9`** (1 nodes): `starrocks`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 10`** (1 nodes): `jupyterhub`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 11`** (1 nodes): `superset`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 12`** (1 nodes): `cloudflared`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 13`** (1 nodes): `spark-history-server`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 14`** (1 nodes): `spark-operator`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 15`** (1 nodes): `redis`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 16`** (1 nodes): `prometheus`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 17`** (1 nodes): `grafana`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 18`** (1 nodes): `loki`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 19`** (1 nodes): `headlamp`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (1 nodes): `ingress`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `enrich_graph_json()` connect `Community 0` to `Community 1`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `create_semantic_relationships()` connect `Community 1` to `Community 0`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `Define component relationships across the big-data-platform Helm chart.     Retu`, `Load the existing graph.json and enrich it with semantic relationships.` to the rest of the system?**
  _2 weakly-connected nodes found - possible documentation gaps or missing edges._