# Query Performance Tuning Workflow

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🔴 Senior
**Tags:** `SQL`, `performance-tuning`, `slow-query-log`, `execution-plan`, `Query Store`, `statistics`, `index`, `rewrite`

## Question

> Walk me through your systematic approach to diagnosing and fixing a slow SQL query in a .NET application. What are the steps from detecting a problem to deploying a fix?

## Short Answer

A systematic query tuning workflow: (1) **identify** — slow query log, Application Insights, Query Store, or EF Core slow query interceptor surfaces the problematic SQL; (2) **baseline** — measure current duration/IO/CPU with `SET STATISTICS IO ON` or `sys.dm_exec_query_stats`; (3) **analyze execution plan** — look for index scans, key lookups, incorrect cardinality estimates, missing indexes; (4) **fix in priority order** — update statistics → add/fix covering index → rewrite the query → change schema → add caching; (5) **validate** — re-measure in isolation, then load test in staging; (6) **monitor** — Query Store baseline, alert on regression. Never tune without measuring before and after.

## Detailed Explanation

### Step 1 — Identify the Slow Query

#### Option A: EF Core Slow Query Logging

```csharp
// Log queries above a threshold
options.UseSqlServer(connStr, b => b.EnableRetryOnFailure())
       .LogTo(Console.WriteLine, LogLevel.Information,
              DbContextLoggerOptions.DefaultWithLocalTime)
       .EnableSensitiveDataLogging();

// Or in production — structured logging with minimum duration filter
services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connStr)
           .AddInterceptors(new SlowQueryInterceptor(TimeSpan.FromSeconds(1))));
```

```csharp
// Slow query interceptor
public sealed class SlowQueryInterceptor(TimeSpan threshold) : DbCommandInterceptor
{
    public override async ValueTask<DbDataReader> ReaderExecutedAsync(
        DbCommand command, CommandExecutedEventData eventData, DbDataReader result,
        CancellationToken ct = default)
    {
        if (eventData.Duration > threshold)
        {
            Log.Warning("Slow query {Duration:F0}ms: {Sql}",
                eventData.Duration.TotalMilliseconds, command.CommandText);
        }
        return result;
    }
}
```

#### Option B: Query Store (SQL Server 2016+)

```sql
-- Top 10 slowest queries by average duration
SELECT TOP 10
    qt.query_sql_text,
    qs.execution_count,
    qs.avg_duration / 1000.0 AS avg_ms,
    qs.avg_logical_io_reads,
    qs.last_execution_time
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats qs ON p.plan_id = qs.plan_id
ORDER BY qs.avg_duration DESC;
```

### Step 2 — Baseline the Query

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Run the slow query
SELECT ...;

-- Output:
-- SQL Server parse and compile time: CPU time = 2 ms, elapsed time = 3 ms.
-- (Orders). Scan count 1, logical reads 12450, physical reads 0
-- SQL Server Execution Times: CPU time = 340 ms, elapsed time = 890 ms.
```

High `logical reads` = many buffer pool page reads = index is inefficient or missing.

### Step 3 — Analyze the Execution Plan

Look for these operators (in SSMS Ctrl+M for actual plan):

| Signal | What it means |
|--------|--------------|
| **Table Scan / Clustered Index Scan** | No suitable index — full table read |
| **Key Lookup** | Non-clustered index found rows; extra round-trip to clustered index for missing columns |
| **Hash Join** (large build input) | Missing index on join column; optimizer couldn't use nested loops |
| **Sort** on large input | Missing ORDER BY support in the index |
| **Estimated rows 1, Actual rows 1 000 000** | Stale statistics — optimizer made bad plan |

### Step 4 — Fix in Priority Order

**4a. Update Statistics** (free, often instant improvement):
```sql
UPDATE STATISTICS Orders;
-- Or for all tables:
EXEC sp_updatestats;
```

**4b. Add or Extend a Covering Index** (most common fix):
```sql
-- Key lookup detected: query needs CustomerId and Total but index only has CreatedAt
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt_Covering
ON Orders (CreatedAt)
INCLUDE (CustomerId, Total, Status);
```

**4c. Rewrite the Query** (when index changes aren't enough):
```sql
-- ❌ OR conditions often prevent index use
SELECT * FROM Orders WHERE Status = 'Pending' OR Status = 'Processing';

-- ✅ UNION ALL — each branch can use the index independently
SELECT * FROM Orders WHERE Status = 'Pending'
UNION ALL
SELECT * FROM Orders WHERE Status = 'Processing';
```

**4d. Caching** (for queries with low update frequency):
```csharp
// Cache expensive reporting queries
var report = await _cache.GetOrCreateAsync($"report:{date:yyyyMM}", async entry =>
{
    entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10);
    return await _db.Database.SqlQuery<ReportRow>(/* ... */).ToListAsync();
});
```

### Step 5 — Validate

```sql
-- Re-run with STATISTICS IO after changes
SET STATISTICS IO ON;
SELECT ... ; -- same query

-- Compare: logical reads 12450 → 8 is a success
```

Always measure in isolation first (SET STATISTICS IO), then under concurrent load (load test with k6, NBomber, or Azure Load Testing).

### Step 6 — Monitor for Regression

```sql
-- Query Store detects plan regressions automatically
-- Force the good plan if a regression is detected:
EXEC sys.sp_query_store_force_plan @query_id = 42, @plan_id = 17;
```

## Code Example

```csharp
// TagWith + interceptor: full observability pipeline
public class OrderQueryService(AppDbContext db)
{
    public async Task<List<OrderSummary>> GetActiveOrdersAsync(
        int customerId, CancellationToken ct)
    {
        return await db.Orders
            .TagWith("GetActiveOrders:CustomerDashboard") // visible in Query Store
            .AsNoTracking()
            .Where(o => o.CustomerId == customerId
                     && o.Status != "Archived")
            .OrderByDescending(o => o.CreatedAt)
            .Select(o => new OrderSummary(o.Id, o.Reference, o.Total, o.Status))
            .Take(50)
            .ToListAsync(ct);
    }
}

// SlowQueryInterceptor surfaces this via structured log — query text includes the TagWith comment
```

## Common Follow-up Questions

- What is parameter sniffing, and how does it cause a previously fast query to suddenly become slow?
- How do you tune a query that performs well in isolation but degrades under concurrency?
- When would you choose to cache query results vs add an index?
- How does `OPTION (RECOMPILE)` interact with Query Store?
- How would you approach query tuning differently in a cloud database (Azure SQL) vs on-premises SQL Server?

## Common Mistakes / Pitfalls

- **Tuning without measuring first**: adding an index without confirming the bottleneck is an index miss wastes time. Always capture execution plan + STATISTICS IO before changing anything.
- **Trusting estimated execution plans instead of actual**: estimated plans can show completely wrong row counts. Always get the actual plan for the real query — not `SHOWPLAN_XML` without execution.
- **Fixing only the slowest query**: fixing P99 query #1 often reveals query #2 becomes the new bottleneck. Tune iteratively.
- **Not considering write impact of new indexes**: adding a covering index to fix a 2-second read may increase the write time for a 10 000 INSERT/s hot path by 10–20%.
- **Using query hints instead of fixing root causes**: `OPTION (RECOMPILE)` or `FORCESEEK` can mask statistics problems. Fix the root cause — update statistics, fix index design.

## References

- [Query tuning methodology — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-profiling-infrastructure)
- [Monitoring performance using Query Store — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
- [SET STATISTICS IO — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-io-transact-sql)
- [See: query-execution-plan.md](./query-execution-plan.md)
- [See: index-design-patterns.md](./index-design-patterns.md)
- [See: ef-core-logging-and-diagnostics.md](./ef-core-logging-and-diagnostics.md)
