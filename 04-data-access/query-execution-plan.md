# Reading SQL Server Query Execution Plans

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟡 Middle
**Tags:** `SQL`, `execution-plan`, `index-seek`, `index-scan`, `key-lookup`, `EXPLAIN`, `query-optimizer`, `statistics`

## Question

> How do you read a SQL Server query execution plan? What is the difference between an index seek and an index scan? What is a key lookup, and why is it expensive? How do estimated vs actual row counts help diagnose query problems?

## Short Answer

An execution plan shows the operations the query optimizer chose to execute a query — each node is an operator (Scan, Seek, Lookup, Hash Join, etc.) with a relative cost percentage. **Index seek** navigates the B-tree to a specific range (efficient). **Index scan** reads the entire index leaf level (like a table scan). A **key lookup** happens when a non-clustered index seek finds matching row pointers but must then fetch additional columns from the clustered index — it's a random I/O per row and becomes expensive at scale. **Estimated vs actual row counts** highlight statistics staleness — a large discrepancy means the optimizer made its plan with wrong row count assumptions.

## Detailed Explanation

### How to Get an Execution Plan

```sql
-- Estimated plan (no execution — free to check)
SET SHOWPLAN_XML ON;
SELECT ...

-- Actual plan (executes the query, includes real row counts)
SET STATISTICS XML ON;
SELECT ...
```

In SSMS: Ctrl+L (estimated), Ctrl+M then run (actual). In Azure Data Studio or VS Code SQL Tools, use "Explain" / "Run with Actual Plan".

### Execution Plan Operators

| Operator | Description | When it appears |
|----------|-------------|----------------|
| **Table Scan** | Read every row in a heap table | No clustered index exists |
| **Clustered Index Scan** | Read every row via the clustered index | Large proportion of rows needed; no suitable NC index |
| **Clustered Index Seek** | Navigate B-tree to specific key range | Equality/range filter on clustered key |
| **Index Scan** | Read all leaf pages of a non-clustered index | Low selectivity or broad range |
| **Index Seek** | Navigate B-tree in a non-clustered index | High-selectivity filter matching the index key |
| **Key Lookup** | Fetch row from clustered index using a row pointer | NC index seek found rows but missing columns |
| **RID Lookup** | Same as Key Lookup but on a heap (no clustered index) | Heap table + non-clustered index |
| **Hash Join** | Build a hash table from smaller input, probe with larger | Large unsorted inputs, no suitable index |
| **Merge Join** | Merge two sorted streams | Both inputs already sorted on the join key |
| **Nested Loops** | For each outer row, seek inner table | Small outer input + index on inner table join key |

### Index Seek vs Index Scan

```
Index Seek (efficient):
Root → Intermediate → Leaf: row 4250 found directly via B-tree navigation
I/O: O(log N)

Index Scan (potentially slow):
Leaf Page 1 → Leaf Page 2 → ... → Leaf Page N: read everything
I/O: O(N)
```

SQL Server chooses a scan over a seek when the predicate is low-selectivity and fetching a large fraction of rows — at some threshold, reading the whole index is cheaper than random seeks for each row.

### Key Lookup — The Core Performance Problem

```sql
-- NC index exists on (CreatedAt), but query also needs Total, Status
SELECT OrderId, CustomerId, Total, Status
FROM Orders
WHERE CreatedAt >= '2024-01-01';

-- Execution plan:
-- Index Seek on IX_Orders_CreatedAt → for each result row → Key Lookup on PK
-- 10 000 rows found → 10 000 key lookups (random I/O) → potentially very slow
```

**Fix: add a covering index**:
```sql
CREATE INDEX IX_Orders_CreatedAt_Covering
ON Orders (CreatedAt)
INCLUDE (CustomerId, Total, Status);
-- Now: Index Seek only — no key lookup
```

### Estimated vs Actual Row Counts

SQL Server's optimizer uses **statistics** (histograms of column value distributions) to estimate how many rows each operation will process. When estimates are wrong:

- **Under-estimate**: optimizer chose a Nested Loops join expecting 10 rows; actual = 100 000 → catastrophic at scale
- **Over-estimate**: optimizer built an expensive Hash Join expecting 1M rows; actual = 50 → wasted memory

```sql
-- Check statistics staleness
SELECT 
    s.name AS stat_name,
    STATS_DATE(s.object_id, s.stats_id) AS last_updated,
    sp.rows AS total_rows,
    sp.rows_sampled,
    sp.modification_counter
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECT_NAME(s.object_id) = 'Orders';

-- Update stale statistics
UPDATE STATISTICS Orders;
```

### Reading Plan Costs — The Thick Arrow Rule

In SSMS, the arrow **thickness** between operators represents the estimated number of rows flowing between them. A suddenly thick arrow after a Filter operator often signals a statistics problem (the optimizer expected far fewer rows to survive the filter).

Each operator shows an estimated **subtree cost**. Hover over any operator to see:
- Estimated / Actual row count
- Estimated rows per execution
- I/O cost, CPU cost
- Operator-specific details (e.g., which index was used)

## Code Example

```csharp
// EF Core: TagWith adds a comment to the SQL — visible in execution plans
var orders = await db.Orders
    .TagWith("GetRecentOrders - CustomerDashboard")
    .Where(o => o.CreatedAt >= DateTime.UtcNow.AddDays(-30))
    .Select(o => new { o.OrderId, o.Total, o.Status })
    .ToListAsync(ct);

// Generated SQL will have: /* GetRecentOrders - CustomerDashboard */ at the top
// This makes the query identifiable in Query Store and execution plan cache
```

```sql
-- In SQL Server, force index hint to compare seeks vs scans:
SELECT OrderId, Total
FROM Orders WITH (INDEX(IX_Orders_CreatedAt))  -- hint: use this specific index
WHERE CustomerId = 42;

-- Or use Query Store to find the most expensive queries:
SELECT TOP 10
    qt.query_sql_text,
    rs.avg_duration / 1000.0 AS avg_ms,
    rs.count_executions
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan qp ON q.query_id = qp.query_id
JOIN sys.query_store_runtime_stats rs ON qp.plan_id = rs.plan_id
ORDER BY rs.avg_duration DESC;
```

## Common Follow-up Questions

- What is parameter sniffing, and how does it cause plan reuse problems?
- How does SQL Server's Query Store help with plan regression detection?
- What does a Spool operator in an execution plan indicate?
- When would you use `OPTION (RECOMPILE)` or `OPTION (OPTIMIZE FOR UNKNOWN)`?
- How do missing index recommendations in execution plans work, and should you always follow them?

## Common Mistakes / Pitfalls

- **Ignoring actual vs estimated row count discrepancy**: a plan where estimated = 1 but actual = 500 000 is the number one sign of stale statistics and a bad plan choice.
- **Trusting the cost percentages too much**: cost percentages are estimates based on statistics, not actual measured I/O. A 1% cost operator may be the real bottleneck if it performs 10 000 key lookups.
- **Fixing every key lookup**: key lookups are only expensive when the seek returns many rows. If the query returns 5 rows, one key lookup is negligible.
- **Using query hints in production without understanding the trade-offs**: `NOLOCK` (READ UNCOMMITTED) solves blocking at the cost of dirty reads and phantom data. Don't use it just to make a slow query faster without understanding what data quality is being sacrificed.

## References

- [Execution plans overview — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plans)
- [Logical and physical operators reference — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference)
- [Query Store overview — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
- [See: indexes-overview.md](./indexes-overview.md)
- [See: index-design-patterns.md](./index-design-patterns.md)
