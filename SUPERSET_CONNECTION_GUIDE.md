# Superset Connection Guide

## Hive Connection
To connect Superset to Hive (running in the cluster), use the following SQLAlchemy URI:

**Display Name**: `Hive`
**SQLAlchemy URI**:
```
hive://hive-metastore:10000/default?auth=NOSASL
```

### Authentication
- **Username**: `hive` (or any string)
- **Password**: `hive` (or any string)

## Troubleshooting
### TSocket read 0 bytes
If you see `TSocket read 0 bytes`, it means there is an authentication protocol mismatch. Our Hive server is configured for `NOSASL`, but the client defaults to `SASL`. The `?auth=NOSASL` query parameter fixes this.

### SemanticException [Error 10004]: Invalid table alias
If you see errors like `Invalid table alias or column reference 'tablename.column'`, Superset is generating SQL that Hive struggles with.
**Possible Causes:**
1. **Reserved Keywords**: You have a column named `type`. `TYPE` is a reserved keyword in Hive. Superset might not quote it correctly in generated queries.
2. **Ambiguous Alias**: Hive is confused by Superset's auto-aliasing.

**Workaround (Virtual Dataset):**
1. Go to **SQL Lab**.
2. Write a query that **renames the problematic column**:
   ```sql
   SELECT `type` AS stock_type, particulars, uom, quantity FROM closing_stock
   ```
   *(Note the backticks around `type`)*
3. Click **Explore** (or Save as Dataset).
4. Use `stock_type` in your charts instead of `type`.
