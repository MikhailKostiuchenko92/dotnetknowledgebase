# Indexes Overview

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟢 Junior
**Tags:** `SQL`, `indexes`, `clustered`, `non-clustered`, `covering-index`, `B-tree`, `selectivity`

## Question

> What is the difference between a clustered and a non-clustered index? What is a covering index, and when should you add one? When do indexes hurt performance rather than help it?

## Short Answer

A **clustered index** defines the physical ordering of the table rows on disk — there can be only one per table, and SQL Server creates it on the primary key by default. A **non-clustered index** is a separate B-tree structure containing the indexed columns plus a pointer to the actual row; a table can have up to 999. A **covering index** is a non-clustered index whose column set includes every column the query needs, eliminating the need to look up the base table row. Indexes help read queries but hurt write performance because every `INSERT`/`UPDATE`/`DELETE` must also update all relevant indexes.

## Detailed Explanation

### B-Tree Structure

Both clustered and non-clustered indexes use a B-tree (balanced tree) structure:

```
Root Page
├── Intermediate Pages (range boundaries)
│   ├── Leaf Page (row data / row pointers)
│   └── Leaf Page ...
└── Intermediate Pages ...
```

The leaf level differs:
- **Clustered index** — leaf pages contain the actual data rows. A table with a clustered index is called a *clustered table* (vs a *heap*, which has no clustered index).
- **Non-clustered index** — leaf pages contain the indexed column values + a **row locator** (the clustered key if one exists; otherwise, the heap Row ID).

### Clustered vs Non-Clustered — Comparison

| Feature | Clustered | Non-Clustered |
|---------|-----------|--------------|
| Data storage | **IS** the table (leaf = rows) | Separate structure, points to rows |
| Count per table | **1** | Up to 999 |
| Default on PK? | Yes (SQL Server default) | No |
| Range scans | Excellent (rows are sorted) | Slower (key lookups may be needed) |
| Row size impact | N/A (data lives here anyway) | Index includes key + pointer |
| Write cost | Moderate | Adds per-index maintenance on DML |

### Covering Indexes

A **covering index** includes all columns needed to satisfy a query — both the filter columns (predicates) and the select columns (projections):

```sql
-- Query that benefits from a covering index:
SELECT CustomerId, Total, Status
FROM Orders
WHERE CreatedAt >= '2024-01-01' AND Status = 'Shipped';

-- Without covering index: index seeks on CreatedAt, then KEY LOOKUP to get CustomerId, Total, Status
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt
ON Orders (CreatedAt);  -- forces a key lookup (expensive at scale)

-- Covering index: all required columns are in the index
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt_Covering
ON Orders (CreatedAt, Status)         -- filter columns first
INCLUDE (CustomerId, Total);          -- projected columns in INCLUDE (don't affect index ordering)
```

**`INCLUDE` columns** are stored at the leaf level only — they narrow the key lookup without enlarging the intermediate index tree.

### Index Selectivity

Index selectivity = proportion of rows excluded by the index predicate. SQL Server uses statistics to estimate whether a seek is worth it.

| Column | Distinct values | Selectivity | Index useful? |
|--------|----------------|-------------|--------------|
| `OrderId` (PK) | ~10 000 000 | Very high | ✅ Always |
| `Status` | 4 (new, processing, shipped, cancelled) | Very low | ❌ Often not — faster to scan |
| `Email` | ~10 000 000 | Very high | ✅ Equality lookups |
| `CreatedAt` | High range | Medium | ✅ Range queries |

> **Low-selectivity columns** (fewer than ~5–10 distinct values in a large table) are poor index candidates on their own. SQL Server may choose a table scan over using the index.

### When Indexes Hurt

- **Writes are slower**: every `INSERT`, `UPDATE`, or `DELETE` must update all indexes on the modified columns.
- **Over-indexing**: 15+ indexes on a high-write table can make writes dramatically slower — OLTP tables typically need 3–7 indexes.
- **Stale statistics**: if statistics aren't updated, the query optimizer may make wrong decisions (e.g., choosing a scan over a seek).
- **Unused indexes**: each unused index wastes storage and write overhead with no read benefit. Use `sys.dm_db_index_usage_stats` to find them.

## Code Example

```csharp
// EF Core — defining a covering index via Fluent API
entity.HasIndex(e => new { e.CreatedAt, e.Status })
      .IncludeProperties(e => new { e.CustomerId, e.Total })
      .HasDatabaseName("IX_Orders_CreatedAt_Status_Covering");

// EF Core — filtered index (partial index) for soft-delete pattern
entity.HasIndex(e => e.Email)
      .HasFilter("[DeletedAt] IS NULL")
      .IsUnique()
      .HasDatabaseName("IX_Users_Email_Active");
```

```sql
-- T-SQL equivalents
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt_Status_Covering
ON Orders (CreatedAt DESC, Status)
INCLUDE (CustomerId, Total);

-- Filtered (partial) index — much smaller, only active rows
CREATE UNIQUE NONCLUSTERED INDEX IX_Users_Email_Active
ON Users (Email)
WHERE DeletedAt IS NULL;
```

## Common Follow-up Questions

- What is an index scan vs an index seek? When does SQL Server choose each?
- What is a key lookup (bookmark lookup), and how does it affect query performance?
- How do composite index column ordering and cardinality affect index effectiveness?
- What are filtered (partial) indexes, and when are they better than full indexes?
- How would you find unused or missing indexes in SQL Server?

## Common Mistakes / Pitfalls

- **Indexing every column individually**: a composite index `(A, B)` can serve queries on `A` alone, on `A + B`, but NOT on `B` alone. Developers sometimes add `IX_B` separately, missing the chance to reuse the composite.
- **Putting low-selectivity columns first in a composite index**: column order matters — place the highest-selectivity column first (the one that eliminates the most rows).
- **Forgetting `INCLUDE` columns**: adding projection columns to the key (not INCLUDE) creates a wider key, increasing index depth and write cost. Use `INCLUDE` for non-filter columns.
- **Indexing foreign keys by default without considering queries**: FK columns need indexes when joining/filtering in that direction, but not all FKs are queried.
- **Ignoring write costs**: adding an index to speed up a `SELECT` that runs once a minute while there are 1000 `INSERT`s per second may be counterproductive.

## References

- [Clustered and nonclustered indexes — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/clustered-and-nonclustered-indexes-described)
- [Create indexes with included columns — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes-with-included-columns)
- [Index architecture and design guide — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)
- [EF Core indexes — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/indexes)
