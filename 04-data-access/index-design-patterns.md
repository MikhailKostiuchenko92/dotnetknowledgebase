# Index Design Patterns

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🔴 Senior
**Tags:** `SQL`, `indexes`, `composite-index`, `include-columns`, `filtered-index`, `index-selectivity`, `missing-index-DMV`, `index-fragmentation`

## Question

> How do you design composite indexes for maximum query coverage? What is the correct column ordering rule for composite indexes, and how do `INCLUDE` columns differ from key columns? What are filtered indexes, and when do they outperform full indexes?

## Short Answer

For composite index column ordering: put the **highest-cardinality equality-filter column first**, then range-filter columns, then sort-order columns. Columns needed only for projection (not filtering or sorting) go in `INCLUDE` — they exist only at the leaf level and don't affect tree depth. **Filtered indexes** (partial indexes) cover only a subset of rows matching a predicate — they're smaller, updated less often, and generate better statistics for selective queries (e.g., `WHERE Status = 'Pending' AND DeletedAt IS NULL`). Missing index DMVs (`sys.dm_db_missing_index_details`) identify opportunities but should be treated as suggestions, not prescriptions — blindly applying every suggestion leads to over-indexing.

## Detailed Explanation

### Composite Index Column Ordering — The Rules

The B-tree is sorted by the first key column, then second within equal first-column values, and so on. SQL Server can use the index if the query filters on a **leading prefix** of the key:

```sql
-- Index: (A, B, C)
-- Supported access patterns:
WHERE A = x                    -- uses first column ✅
WHERE A = x AND B = y          -- uses first two columns ✅
WHERE A = x AND B = y AND C = z  -- uses all three ✅
WHERE A BETWEEN 1 AND 10       -- range scan on first column ✅
WHERE A = x AND C = z          -- A used, C skipped (B missing) — partial use ⚠️
WHERE B = y                    -- B is not a leading key — index NOT used ❌
```

### Equality vs Range Columns — Column Order Matters

```sql
-- Query: filter on Status (equality) and CreatedAt (range)
SELECT * FROM Orders WHERE Status = 'Pending' AND CreatedAt >= '2024-01-01';

-- ✅ Correct order: equality first (Status), range second (CreatedAt)
CREATE INDEX IX_Orders_Status_CreatedAt ON Orders (Status, CreatedAt);
-- Seeks to Status='Pending', then range scans on CreatedAt within that group

-- ❌ Wrong order: range first (CreatedAt), equality second (Status)
CREATE INDEX IX_Orders_CreatedAt_Status ON Orders (CreatedAt, Status);
-- Performs range scan on the entire CreatedAt range, then filters Status in the index
-- Much less selective for the Status='Pending' filter
```

### INCLUDE Columns — Covering without Inflating the Key

Key columns participate in B-tree ordering at all levels. `INCLUDE` columns are stored only at the **leaf level** and do not affect tree depth or ordering:

```sql
-- Query: filter on (Status, CreatedAt), return (Id, CustomerId, Total)
SELECT Id, CustomerId, Total
FROM Orders
WHERE Status = 'Pending' AND CreatedAt >= '2024-01-01';

-- Covering index — no key lookup needed
CREATE NONCLUSTERED INDEX IX_Orders_Pending_Covering
ON Orders (Status, CreatedAt)          -- filter columns as keys (define B-tree ordering)
INCLUDE (Id, CustomerId, Total);       -- output columns at leaf level (no tree impact)
```

> **Rule**: If a column appears only in `SELECT` (not `WHERE`, `JOIN ON`, or `ORDER BY`), use `INCLUDE`. If it appears in a filter or sort, make it a key column.

### Filtered (Partial) Indexes

A filtered index covers only rows matching a `WHERE` predicate:

```sql
-- Only index un-processed orders — the hot path
CREATE NONCLUSTERED INDEX IX_Orders_Pending
ON Orders (CreatedAt)
INCLUDE (CustomerId, Total)
WHERE Status = 'Pending';
-- If 2% of orders are Pending, this index is 50x smaller than a full index on CreatedAt
```

**Benefits of filtered indexes**:
- Smaller → less disk I/O, fits in buffer pool more easily
- Less write overhead — only updates when `Status = 'Pending'` rows change
- Better statistics — statistics reflect only the filtered row set → optimizer makes better decisions

**Filtered unique index — soft delete pattern**:

```sql
-- Unique email among non-deleted users
CREATE UNIQUE INDEX IX_Users_Email_Active
ON Users (Email)
WHERE DeletedAt IS NULL;
-- Soft-deleted users can share an email address; active users cannot
```

```csharp
// EF Core Fluent API equivalent
entity.HasIndex(e => e.Email)
      .HasFilter("[DeletedAt] IS NULL")
      .IsUnique();
```

### Finding Missing Indexes with DMVs

```sql
-- Top 20 most beneficial missing indexes
SELECT TOP 20
    migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) *
    (migs.user_seeks + migs.user_scans) AS improvement_measure,
    mid.statement AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.user_seeks,
    migs.user_scans
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid
    ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
```

> **Caveat**: DMV suggestions are for a single query at a time. Creating every suggested index leads to over-indexing. Evaluate whether the query is a hot path, and check if an existing index can be extended with `INCLUDE` columns to cover it.

### Index Fragmentation

B-tree page splits during inserts/updates cause logical fragmentation — pages are not physically sequential, hurting sequential scan performance.

```sql
-- Check fragmentation
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- Reorganize (online, minor fragmentation 10-30%)
ALTER INDEX IX_Orders_Status ON Orders REORGANIZE;

-- Rebuild (brief offline, high fragmentation >30%)
ALTER INDEX IX_Orders_Status ON Orders REBUILD WITH (ONLINE = ON);
```

## Code Example

```csharp
// EF Core: composite index + filtered index + include columns via Fluent API
protected override void OnModelCreating(ModelBuilder builder)
{
    builder.Entity<Order>(entity =>
    {
        // Composite covering index for order dashboard query
        entity.HasIndex(e => new { e.Status, e.CreatedAt })
              .IncludeProperties(e => new { e.CustomerId, e.Total, e.Reference })
              .HasDatabaseName("IX_Orders_Status_CreatedAt_Covering");

        // Filtered index — only active (non-archived) orders in the "hot" index
        entity.HasIndex(e => new { e.CustomerId, e.CreatedAt })
              .HasFilter("[ArchivedAt] IS NULL")
              .HasDatabaseName("IX_Orders_Active_Customer");
    });
}
```

## Common Follow-up Questions

- How does index fill factor affect fragmentation and query performance?
- What is a columnstore index, and when should you use one vs a rowstore B-tree index?
- How do indexed views work in SQL Server, and when are they materialized automatically?
- How does SQL Server's auto-statistics update threshold work, and when must you manually update statistics?
- How do you identify unused indexes in production using `sys.dm_db_index_usage_stats`?

## Common Mistakes / Pitfalls

- **Blindly following every missing index DMV suggestion**: DMVs suggest per-query; applying all creates many overlapping indexes with high write overhead. Consolidate suggestions — one composite may cover several.
- **Putting range columns before equality columns in composite keys**: `(CreatedAt, Status)` with a filter on `Status = 'Pending' AND CreatedAt >= x` is far less selective than `(Status, CreatedAt)`.
- **Using INCLUDE for filter columns**: if a column appears in `WHERE` or `JOIN ON`, it must be a key column — `INCLUDE` columns are not in the intermediate B-tree nodes and don't enable seeks on that column.
- **Ignoring fragmentation on volatile tables**: high-insert/update tables accumulate fragmentation quickly. Schedule regular `REORGANIZE` or `REBUILD` maintenance jobs.

## References

- [Index architecture and design guide — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)
- [Create filtered indexes — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)
- [sys.dm_db_missing_index_details — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql)
- [See: indexes-overview.md](./indexes-overview.md)
- [See: query-execution-plan.md](./query-execution-plan.md)
