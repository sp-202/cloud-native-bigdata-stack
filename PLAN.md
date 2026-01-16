# 🗺️ Development Plan

## Current Status: v0.3.0 Released

The Spark Connect architecture is now stable and documented.

---

## v0.4.0 Roadmap: Table Format Interoperability

### 📋 Phase 1: Apache Iceberg Integration

| Task | Description | Status |
|------|-------------|--------|
| Add Iceberg JARs | Include `iceberg-spark-runtime` in Spark image | ⬜ TODO |
| Configure Iceberg Catalog | Set up Iceberg REST Catalog or HMS catalog | ⬜ TODO |
| Create Test Tables | Write Iceberg tables from Spark | ⬜ TODO |
| StarRocks Iceberg Catalog | Configure StarRocks to read Iceberg tables | ⬜ TODO |

**Acceptance Criteria:**
- [ ] Spark can write Iceberg tables to MinIO
- [ ] StarRocks can query Iceberg tables directly
- [ ] Performance benchmarks vs Delta Lake

---

### 📋 Phase 2: Delta Lake UniForm Testing

| Task | Description | Status |
|------|-------------|--------|
| Enable UniForm | Add `delta.universalFormat.enabledFormats` config | ⬜ TODO |
| Write UniForm Tables | Create Delta tables with UniForm enabled | ⬜ TODO |
| Read as Iceberg | Verify StarRocks can read Delta+UniForm as Iceberg | ⬜ TODO |
| Compatibility Testing | Test edge cases (schema evolution, partitions) | ⬜ TODO |

**Acceptance Criteria:**
- [ ] Delta tables with UniForm are readable as Iceberg
- [ ] No data loss or corruption during format translation
- [ ] Document any limitations

---

### 📋 Phase 3: Unity Catalog (OSS) Re-integration

| Task | Description | Status |
|------|-------------|--------|
| Deploy UC Server | Re-deploy Unity Catalog with v0.3.1 | ⬜ TODO |
| Configure Storage Credentials | Set up MinIO credentials via Storage Credentials API | ⬜ TODO |
| HMS Fallback | Configure UC to fallback to HMS for legacy tables | ⬜ TODO |
| Spark Integration | Configure Spark to use Unity Catalog as primary catalog | ⬜ TODO |
| StarRocks UC Catalog | Test StarRocks reading from UC-managed tables | ⬜ TODO |

**Acceptance Criteria:**
- [ ] Unity Catalog is stable with MinIO storage
- [ ] Spark can register tables in Unity Catalog
- [ ] Existing HMS tables remain accessible
- [ ] Document migration path from HMS to UC

---

## Testing Checklist

### Integration Tests
- [ ] JupyterHub → Spark Connect → Delta Lake → MinIO
- [ ] JupyterHub → Spark Connect → Iceberg → MinIO
- [ ] StarRocks → Delta Catalog → MinIO
- [ ] StarRocks → Iceberg Catalog → MinIO
- [ ] Superset → StarRocks (Delta tables)
- [ ] Superset → StarRocks (Iceberg tables)

### Performance Tests
- [ ] Write 1M rows to Delta Lake
- [ ] Write 1M rows to Iceberg
- [ ] Query performance comparison
- [ ] Concurrent notebook connections to Spark Connect Server

---

## Notes

> [!TIP]
> Start with Iceberg integration as it's the most requested feature.
> UniForm testing can validate cross-format compatibility.
> UC re-integration should be done last as it has the highest complexity.

---

## References

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Delta Lake UniForm](https://docs.delta.io/latest/delta-uniform.html)
- [Unity Catalog OSS](https://github.com/unitycatalog/unitycatalog)
