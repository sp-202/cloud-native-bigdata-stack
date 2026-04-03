# 📦 Redis Sub-chart

In-memory data structure store used for caching and session management.

## 🚀 Overview
- **Role**: Cache backend for Apache Superset.
- **Image**: `redis:7-alpine`.
- **Sync Wave**: `-2` (Infrastructure Layer).

## 📂 Components
- **Deployment**: Single-replica Redis instance.
- **Service**: Internal service on port 6379.

## 🛠 Configuration
```yaml
redis:
  enabled: true
```
