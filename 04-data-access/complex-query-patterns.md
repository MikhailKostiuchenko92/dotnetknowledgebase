# Complex Query Patterns in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `CTE`, `window-functions`, `raw-sql`, `subqueries`, `hybrid-queries`, `SqlQuery`

## Question

> What query patterns cannot be expressed in EF Core LINQ, and how do you handle them? How do you use CTEs, window functions, and subqueries in EF Core — and what is the best hybrid approach that combines LINQ and raw SQL?

## Short Answer

EF Core LINQ covers most standard SQL patterns, but CTEs, window functions (`ROW_NUMBER`, `RANK`, `LAG`), `PIVOT`, hierarchical queries (`WITH RECURSIVE`), and provider-specific functions can't be expressed in LINQ. The primary tools for these are `FromSqlRaw`/`SqlQuery<T>` for queries returning entities or unmapped types, and `ExecuteSqlRaw` for DML. The best hybrid pattern is to use LINQ to build the outer query (filtering, paging, projection) and raw SQL only for the complex inner part — EF Core wraps the raw SQL as a subquery that LINQ operates on top of.

## Detailed Explanation

### What LINQ Cannot Translate

| Pattern | LINQ | Workaround |
|---------|------|-----------|
| CTE (`WITH … AS`) | ❌ | `FromSqlRaw` with CTE |
| Window functions (`ROW_NUMBER() OVER (...)`) | ❌ | `FromSqlRaw` or `SqlQuery<T>` |
| `PIVOT` / `UNPIVOT` | ❌ | Raw SQL or C# reshaping after query |
| Recursive CTE (hierarchies) | ❌ | Raw SQL |
| `MERGE` (upsert) | ❌ | Raw SQL or `ExecuteUpdate`/`ExecuteDelete` |
| Full-text `FREETEXT`/`CONTAINS` | Partial | `EF.Functions.FreeText`/`Contains` |
| `CROSS APPLY` / `OUTER APPLY` | Partial (EF Core 8+) | `SelectMany` with `DefaultIfEmpty` |
| Multiple result sets | ❌ | ADO.NET directly |

### Pattern 1: CTE via `FromSqlRaw` + LINQ Composition

EF Core can wrap raw SQL as a subquery and compose LINQ on top:

```csharp
// Raw CTE as the "base"; LINQ adds WHERE/ORDER/SKIP/TAKE on top
var topCustomers = await db.Database
    .SqlQuery<CustomerRevenueSummary>($"""
        WITH revenue AS (
            SELECT   c.Id, c.Name, SUM(o.Total) AS Revenue
            FROM     Customers c
            JOIN     Orders o ON o.CustomerId = c.Id
            WHERE    o.CreatedAt >= {from}
            GROUP BY c.Id, c.Name
        )
        SELECT Id, Name, Revenue FROM revenue
        """)
    .OrderByDescending(r => r.Revenue)   // LINQ operator on top of raw SQL
    .Take(10)
    .ToListAsync(ct);

public record CustomerRevenueSummary(int Id, string Name, decimal Revenue);
```

EF Core 7+ `SqlQuery<T>` returns `IQueryable<T>`, so LINQ operators translate to a wrapping query:

```sql
SELECT * FROM (
    WITH revenue AS ( ... ) SELECT Id, Name, Revenue FROM revenue
) AS r
ORDER BY r.Revenue DESC
FETCH FIRST 10 ROWS ONLY
```

### Pattern 2: Window Functions for Ranking

```csharp
// Rank orders within each customer partition
var ranked = await db.Database
    .SqlQuery<RankedOrder>($"""
        SELECT
            o.Id,
            o.CustomerId,
            o.Total,
            ROW_NUMBER() OVER (PARTITION BY o.CustomerId ORDER BY o.Total DESC) AS Rank
        FROM Orders o
        WHERE o.Status = {status}
        """)
    .Where(r => r.Rank <= 3)   // filter to top-3 per customer in SQL
    .ToListAsync(ct);

public record RankedOrder(int Id, int CustomerId, decimal Total, int Rank);
```

### Pattern 3: Hierarchical Data (Recursive CTE)

```csharp
// Organisation chart: all reports under a given manager
public async Task<List<Employee>> GetSubtreeAsync(int managerId, CancellationToken ct) =>
    await db.Employees
        .FromSqlRaw("""
            WITH RECURSIVE org AS (
                SELECT * FROM Employees WHERE Id = {0}
                UNION ALL
                SELECT e.* FROM Employees e
                JOIN org ON e.ManagerId = org.Id
            )
            SELECT * FROM org
            """, managerId)
        .AsNoTracking()
        .ToListAsync(ct);
```

### Pattern 4: `FromSqlRaw` + Entity Composition

`FromSqlRaw` returning full entities can still be composed with LINQ and `Include`:

```csharp
var orders = await db.Orders
    .FromSqlRaw("""
        SELECT o.*
        FROM   Orders o
        JOIN   fn_GetActiveOrderIds() ids ON o.Id = ids.Id
        """)   // table-valued function or complex join
    .Include(o => o.Customer)         // EF Core adds the JOIN automatically
    .Where(o => o.Status == "Pending")  // LINQ WHERE added as outer filter
    .ToListAsync(ct);
```

Restriction: the raw SQL must return all columns of the entity type and the `FROM` alias/table must be the base table EF Core expects.

### Pattern 5: Lateral Joins / `CROSS APPLY` (EF Core 8+)

EF Core 8 added support for lateral joins via `SelectMany`:

```csharp
// CROSS APPLY equivalent: for each customer, get their top 3 orders
var result = await db.Customers
    .SelectMany(c => db.Orders
        .Where(o => o.CustomerId == c.Id)
        .OrderByDescending(o => o.Total)
        .Take(3),
        (c, o) => new { c.Name, o.Reference, o.Total })
    .ToListAsync(ct);
// EF Core 8+: translates to CROSS APPLY (SQL Server) or LATERAL JOIN (PostgreSQL)
```

### When to Fall Back to Raw ADO.NET

Use raw `SqlConnection`/`SqlCommand` when:

- You need multiple result sets from one stored procedure.
- Streaming very large result sets without materialisation.
- Using `SqlBulkCopy` for bulk insert.
- Need fine-grained control over command timeout, transaction isolation, or parameters.

```csharp
// Multiple result sets — must use ADO.NET or Dapper
var conn = db.Database.GetDbConnection();
await conn.OpenAsync(ct);
using var cmd = conn.CreateCommand();
cmd.CommandText = "EXEC sp_GetDashboard @UserId";
cmd.Parameters.Add(new SqlParameter("@UserId", userId));
using var reader = await cmd.ExecuteReaderAsync(ct);

var summary = new List<SummaryRow>();
while (await reader.ReadAsync(ct))
    summary.Add(MapSummary(reader));

await reader.NextResultAsync(ct);

var alerts = new List<AlertRow>();
while (await reader.ReadAsync(ct))
    alerts.Add(MapAlert(reader));
```

## Code Example

```csharp
// Full example: monthly revenue report using CTE + window function
public async Task<List<MonthlyRevenueReport>> GetMonthlyReportAsync(
    int year, CancellationToken ct)
{
    return await db.Database
        .SqlQuery<MonthlyRevenueReport>($"""
            WITH monthly AS (
                SELECT
                    MONTH(o.CreatedAt)          AS Month,
                    SUM(o.Total)                AS Revenue,
                    COUNT(*)                    AS OrderCount,
                    COUNT(DISTINCT o.CustomerId) AS UniqueCustomers
                FROM Orders o
                WHERE YEAR(o.CreatedAt) = {year}
                  AND o.Status <> 'Cancelled'
                GROUP BY MONTH(o.CreatedAt)
            )
            SELECT
                Month,
                Revenue,
                OrderCount,
                UniqueCustomers,
                Revenue - LAG(Revenue, 1, 0) OVER (ORDER BY Month) AS RevenueChange
            FROM monthly
            """)
        .OrderBy(r => r.Month)
        .ToListAsync(ct);
}

public record MonthlyRevenueReport(
    int Month,
    decimal Revenue,
    int OrderCount,
    int UniqueCustomers,
    decimal RevenueChange);
```

## Common Follow-up Questions

- How do you call a SQL Server table-valued function (TVF) from EF Core LINQ?
- Can you map a database view to an EF Core entity and query it with LINQ?
- How does `SqlQuery<T>` differ from `FromSqlRaw` — when would you choose one over the other?
- How do you handle stored procedures with output parameters in EF Core?
- What is `HasDbFunction` and how does it let you translate C# method calls to SQL functions?

## Common Mistakes / Pitfalls

- **Returning partial entity columns from `FromSqlRaw`**: If the SQL doesn't return all columns of the mapped entity, EF Core throws `InvalidOperationException` or leaves properties at their default values. Use `SqlQuery<DTO>` for partial results.
- **Not parameterizing CTE inputs**: Writing `$"WHERE Year = {year}"` with C# interpolation in `FromSqlRaw` (not `SqlQuery<T>`) is SQL injection. Use `SqlQuery<T>` with `$""` (FormattableString) or pass `SqlParameter` objects to `FromSqlRaw`.
- **Stale change tracker after raw DML**: `ExecuteSqlRaw("UPDATE Orders SET Status = 'Done'")` doesn't update EF Core's change tracker. Previously loaded `Order` entities retain their old `Status`. Call `db.ChangeTracker.Clear()` after bulk DML.
- **Overusing raw SQL for simple queries**: Reaching for raw SQL when LINQ would suffice bypasses query compilation caching, refactoring support, and type safety. Reserve raw SQL for genuinely complex patterns.
- **`FromSqlRaw` results not respecting global query filters**: Raw SQL bypasses `HasQueryFilter`. If you need filters (e.g., tenant ID, soft delete), add them manually to the SQL or wrap with LINQ `.Where()` after materialization.

## References

- [Raw SQL queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/sql-queries)
- [Database functions — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/database-functions)
- [EF Core 8: Lateral joins — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-8.0/whatsnew#lateral-joins)
- [See: raw-sql-in-ef-core.md](./raw-sql-in-ef-core.md)
- [See: dapper-vs-ef-core.md](./dapper-vs-ef-core.md)
