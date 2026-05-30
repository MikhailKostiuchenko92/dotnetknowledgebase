# Raw SQL in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `raw-sql`, `FromSqlRaw`, `SqlQuery`, `ExecuteSqlRaw`, `stored-procedures`, `sql-injection`

## Question

> How do you execute raw SQL in EF Core? What are the differences between `FromSqlRaw`, `FromSqlInterpolated`, `SqlQuery<T>`, and `ExecuteSqlRaw` — and how do you avoid SQL injection when using them?

## Short Answer

EF Core provides several raw SQL APIs for cases LINQ can't handle: `FromSqlRaw` / `FromSqlInterpolated` return entities by composing raw SQL into a query pipeline; `SqlQuery<T>` (EF Core 7+) returns arbitrary scalar types or anonymous projections; `ExecuteSqlRaw` / `ExecuteSqlInterpolated` execute non-query statements (UPDATE, DELETE, stored procedures). The `Interpolated` variants are always safe — they parameterize the interpolated values automatically. `Raw` variants require you to pass parameters explicitly via `SqlParameter` objects; **never** concatenate user input directly into a raw SQL string.

## Detailed Explanation

### `FromSqlRaw` — Query Returning Entities

Returns a tracked `IQueryable<T>` of entity type `T`. The SQL must return all required columns of the entity or owned type.

```csharp
// ✅ Safe: parameterized via SqlParameter
var orders = await db.Orders
    .FromSqlRaw("SELECT * FROM Orders WHERE Status = {0}", status)
    .ToListAsync(ct);

// ✅ Also safe: positional parameters
var orders = await db.Orders
    .FromSqlRaw("SELECT * FROM Orders WHERE CustomerId = {0} AND Status = {1}",
                customerId, status)
    .ToListAsync(ct);
```

EF Core translates `{0}` to a parameterized `@p0` in the query — user input is never interpolated into the SQL string.

**Composing with LINQ after `FromSqlRaw`:**

```csharp
// The raw SQL is a subquery; LINQ is applied on top → server-side
var pagedOrders = await db.Orders
    .FromSqlRaw("SELECT * FROM Orders WHERE Status = {0}", status)
    .OrderBy(o => o.CreatedAt)
    .Skip(skip)
    .Take(pageSize)
    .ToListAsync(ct);
// SQL: SELECT … FROM (SELECT * FROM Orders WHERE Status = @p0) o ORDER BY … OFFSET … FETCH …
```

### `FromSqlInterpolated` — Safe Interpolated Syntax

Uses `FormattableString` — the interpolated values are **automatically parameterized**, never string-interpolated:

```csharp
// ✅ Safe — same parameterization as FromSqlRaw but cleaner syntax
var orders = await db.Orders
    .FromSqlInterpolated($"SELECT * FROM Orders WHERE CustomerId = {customerId}")
    .ToListAsync(ct);

// ❌ DO NOT use string interpolation with FromSqlRaw:
var sql = $"SELECT * FROM Orders WHERE CustomerId = {customerId}";  // SQL injection risk!
db.Orders.FromSqlRaw(sql);  // ← NEVER do this
```

### `SqlQuery<T>` — EF Core 7+: Arbitrary Result Types

Returns a `IQueryable<T>` for any type — doesn't need to be a mapped entity:

```csharp
// Return a non-entity DTO
var results = await db.Database
    .SqlQuery<OrderRevenueSummary>($"""
        SELECT CustomerId, SUM(Total) AS Revenue, COUNT(*) AS OrderCount
        FROM   Orders
        WHERE  CreatedAt >= {from}
        GROUP BY CustomerId
        """)
    .OrderByDescending(r => r.Revenue)
    .Take(10)
    .ToListAsync(ct);

public record OrderRevenueSummary(int CustomerId, decimal Revenue, int OrderCount);
```

EF Core 7+ also added `SqlQuery<T>` for scalar values:

```csharp
var nextSeq = await db.Database
    .SqlQuery<int>($"SELECT NEXT VALUE FOR OrderSequence")
    .FirstAsync(ct);
```

### `ExecuteSqlRaw` / `ExecuteSqlInterpolated` — Non-Query Statements

For INSERT, UPDATE, DELETE, or stored procedures that don't return rows:

```csharp
// ✅ Bulk update via raw SQL (EF Core 7+ also has ExecuteUpdate — use that instead)
var affected = await db.Database.ExecuteSqlInterpolated(
    $"UPDATE Orders SET Status = 'Archived' WHERE CreatedAt < {cutoffDate}", ct);

// Stored procedure with parameters
await db.Database.ExecuteSqlInterpolated(
    $"EXEC sp_CloseOrder @OrderId = {orderId}, @ClosedBy = {userId}", ct);
```

> **EF Core 7+ alternative:** `ExecuteUpdateAsync` / `ExecuteDeleteAsync` are type-safe and don't require raw SQL for most bulk mutations:
> ```csharp
> await db.Orders
>     .Where(o => o.CreatedAt < cutoff)
>     .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Archived"), ct);
> ```

### SQL Injection Prevention Summary

| API | Safe? | Notes |
|-----|-------|-------|
| `FromSqlInterpolated($"...{var}...")` | ✅ | Params auto-extracted |
| `FromSqlRaw("... {0}", var)` | ✅ | Uses positional params |
| `ExecuteSqlInterpolated` | ✅ | Same as above |
| `FromSqlRaw($"... {var}")` | ❌ **INJECTION** | `$""` = C# string interpolation, not safe |
| `FromSqlRaw("... " + var)` | ❌ **INJECTION** | String concat |

### Stored Procedures

```csharp
// Stored procedure returning entity rows
var orders = await db.Orders
    .FromSqlInterpolated($"EXEC sp_GetOrdersByCustomer {customerId}")
    .ToListAsync(ct);

// Stored procedure with output parameter (requires ADO.NET)
var outputParam = new SqlParameter("@Result", SqlDbType.Int)
    { Direction = ParameterDirection.Output };

await db.Database.ExecuteSqlRawAsync(
    "EXEC sp_ProcessOrder @OrderId = {0}, @Result = @Result OUTPUT",
    orderId, outputParam);

var result = (int)outputParam.Value;
```

## Code Example

```csharp
// Full example: CTE query not expressible in LINQ
public async Task<List<OrderWithRankDto>> GetTopOrdersPerCustomerAsync(
    int topN, CancellationToken ct)
{
    return await db.Database
        .SqlQuery<OrderWithRankDto>($"""
            WITH ranked AS (
                SELECT
                    o.Id,
                    o.CustomerId,
                    o.Total,
                    ROW_NUMBER() OVER (PARTITION BY o.CustomerId ORDER BY o.Total DESC) AS rnk
                FROM Orders o
                WHERE o.IsDeleted = 0
            )
            SELECT Id, CustomerId, Total, rnk AS Rank
            FROM   ranked
            WHERE  rnk <= {topN}
            ORDER BY CustomerId, rnk
            """)
        .ToListAsync(ct);
}

public record OrderWithRankDto(int Id, int CustomerId, decimal Total, int Rank);
```

## Common Follow-up Questions

- When you compose LINQ on top of `FromSqlRaw`, does EF Core send two queries to the database or wrap the SQL as a subquery?
- Does `FromSqlRaw` participate in global query filters (e.g., soft delete), or does it bypass them?
- How do you call a stored procedure that returns multiple result sets in EF Core?
- What is the difference between `ExecuteSqlRaw` and EF Core 7's `ExecuteUpdateAsync` / `ExecuteDeleteAsync`?
- Can you use `FromSqlRaw` to query views, and does it support composing `Where` on top of the view?

## Common Mistakes / Pitfalls

- **C# string interpolation (`$""`) with `FromSqlRaw`**: The most dangerous mistake — looks safe but is SQL injection. Always use `FromSqlInterpolated` for interpolation syntax.
- **Forgetting that `FromSqlRaw` must return all entity columns**: If you omit a required non-nullable column, EF Core throws at materialization. Either return all columns or use `SqlQuery<DTO>`.
- **Not calling `ToListAsync()` after `FromSqlRaw`**: `FromSqlRaw` returns `IQueryable<T>` — it executes lazily. The raw SQL doesn't run until materialized.
- **Tracking side effects with raw UPDATE**: After `ExecuteSqlInterpolated`, EF Core's change tracker doesn't know about the changes — if you've already loaded those entities in the same context, you'll have stale cached values. Call `db.ChangeTracker.Clear()` or re-query.
- **Using `FromSqlRaw` with stored procedures that use `SET NOCOUNT ON`**: `FromSqlRaw` expects the SP to return a result set without extraneous row count messages. Some configurations require `SET NOCOUNT ON` in the SP body.

## References

- [Raw SQL queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/sql-queries)
- [SqlQuery<T> (EF Core 7) — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew#raw-sql-queries-for-unmapped-types)
- [ExecuteUpdate/Delete (EF Core 7) — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew#executeupdate-and-executedelete-bulk-updates)
- [See: basic-linq-queries.md](./basic-linq-queries.md)
