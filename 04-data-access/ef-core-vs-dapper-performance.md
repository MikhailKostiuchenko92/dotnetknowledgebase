# EF Core vs Dapper Performance

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `dapper`, `performance`, `benchmarks`, `change-tracking`, `CQRS`, `micro-ORM`

## Question

> How does EF Core performance compare to Dapper in practice? What are the main sources of EF Core overhead, when does Dapper win decisively, and how do you design a system that uses both?

## Short Answer

Dapper is consistently 2–5× faster than EF Core for raw read queries because it skips change tracking, model metadata lookups, identity map management, and object materialization overhead. EF Core's overhead comes from four main sources: LINQ-to-SQL translation (amortized after first execution), snapshot-based change tracking, object materialization with model metadata, and transaction coordination. However, EF Core with `AsNoTracking` + `Select` projection narrows the gap significantly — often within 20–30% of Dapper. The best production pattern is CQRS-style: EF Core for commands (writes with business logic), Dapper for complex read queries where performance matters.

## Detailed Explanation

### Why Dapper Is Faster

Dapper is essentially a thin wrapper around ADO.NET `SqlDataReader`. It:
1. Executes raw SQL directly.
2. Uses `Reflection.Emit`-generated IL to map result columns to properties (faster than reflection).
3. Has no change tracker, no identity map, no model metadata, no navigation fixup.

EF Core does all of the above on every tracked query.

### EF Core Overhead Sources

| Source | Cost | Mitigatable? |
|--------|------|-------------|
| LINQ translation to SQL | Medium (amortized, compiled after first run) | Yes — `EF.CompileQuery` |
| Snapshot creation (change tracking) | High for large result sets | Yes — `AsNoTracking` |
| Identity map management | Medium | Yes — `AsNoTracking` |
| Navigation fixup | Medium | Yes — use projections |
| Object materialization via model | Low | Partially |
| DbContext activation (if not pooled) | Low | Yes — `AddDbContextPool` |

### Realistic Benchmark Numbers

Approximate results on a modern machine with a local SQL Server, 1 000 rows:

| Method | Time (relative) | Allocation |
|--------|----------------|-----------|
| Raw `SqlDataReader` | 1× (baseline) | Minimal |
| Dapper `Query<T>` | ~1.3× | Low |
| EF Core `AsNoTracking` + `Select` | ~1.5–1.8× | Low |
| EF Core `AsNoTracking` (full entity) | ~2–3× | Medium |
| EF Core tracked (full entity) | ~3–5× | High |

> Note: These are illustrative ratios. Actual numbers depend on entity size, column count, DB latency, and workload. Network latency dominates in real systems, often making the ORM difference negligible for most queries. Profile before optimizing.

### When Dapper Wins Decisively

1. **Complex reporting queries**: Multi-table JOINs with aggregations, window functions, CTEs — raw SQL + Dapper is simpler and faster.
2. **High-throughput read APIs**: Endpoints returning large datasets to clients where throughput matters.
3. **Stored procedure calls**: Dapper maps stored procedure results natively without model constraints.
4. **Multiple result sets**: `QueryMultiple` handles multiple result sets elegantly; EF Core can't.
5. **Read replica queries**: When using a separate read-only connection string, Dapper's lightweight setup suits per-query connection management.

### When EF Core Wins

1. **Write-heavy operations with business logic**: Tracked entities, relationships, cascade operations, concurrency tokens.
2. **Migrations and schema management**: EF Core migrations are far superior to manual SQL scripts for typical CRUD apps.
3. **Maintainability at scale**: EF Core's compile-time LINQ queries catch schema changes at build time; Dapper's string SQL breaks silently.
4. **Complex relationships**: Navigation properties, cascade delete, owned entities, TPH/TPT/TPC inheritance.

### The Hybrid CQRS Pattern

```
Command side (writes) → EF Core (tracked, business rules, migrations)
Query side (reads)    → Dapper or EF Core projected DTO (no tracking, fast)
```

```csharp
// Command handler — EF Core with full tracking
public async Task Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    var customer = await db.Customers.FindAsync([cmd.CustomerId], ct)
        ?? throw new NotFoundException(cmd.CustomerId);

    var order = customer.PlaceOrder(cmd.Items);  // domain logic
    db.Orders.Add(order);
    await db.SaveChangesAsync(ct);
}

// Query handler — Dapper for complex read with JOIN + aggregation
public async Task<OrderSummaryDto?> Handle(GetOrderSummaryQuery query, CancellationToken ct)
{
    using var conn = new SqlConnection(readConnStr);
    return await conn.QuerySingleOrDefaultAsync<OrderSummaryDto>(
        """
        SELECT o.Id, o.Reference, c.Name AS CustomerName,
               SUM(l.Total) AS GrandTotal, COUNT(l.Id) AS LineCount
        FROM   Orders o
        JOIN   Customers c ON c.Id = o.CustomerId
        JOIN   OrderLines l ON l.OrderId = o.Id
        WHERE  o.Id = @Id
        GROUP BY o.Id, o.Reference, c.Name
        """,
        new { query.Id });
}
```

### EF Core AsNoTracking + Projection Closes the Gap

```csharp
// This EF Core query is within 20–30% of Dapper for most workloads
var dtos = await db.Orders
    .AsNoTracking()
    .Where(o => o.Status == status)
    .Select(o => new OrderDto(
        o.Id, o.Customer.Name, o.Lines.Sum(l => l.Total)))
    .ToListAsync(ct);
```

For many CRUD applications the remaining performance difference is irrelevant — database I/O dominates.

## Code Example

```csharp
// EF Core optimized read — no tracking, projected, compiled
private static readonly Func<AppDb, string, IAsyncEnumerable<OrderListDto>> _getByStatus =
    EF.CompileAsyncQuery((AppDb db, string status) =>
        db.Orders
            .AsNoTracking()
            .Where(o => o.Status == status)
            .Select(o => new OrderListDto(o.Id, o.Reference, o.CreatedAt, o.Total)));

// Dapper equivalent for comparison
private async Task<IEnumerable<OrderListDto>> GetByStatusDapperAsync(
    string status, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    return await conn.QueryAsync<OrderListDto>(
        "SELECT Id, Reference, CreatedAt, Total FROM Orders WHERE Status = @Status",
        new { Status = status });
}
```

## Common Follow-up Questions

- How does EF Core's `EF.CompileQuery` change the performance profile — when does it matter?
- What is the performance impact of using EF Core interceptors on query throughput?
- How do you share a transaction between EF Core and Dapper on the same connection?
- When would you choose EF Core projections over Dapper for reads?
- How do you benchmark EF Core vs Dapper correctly — what pitfalls exist in micro-benchmarks?

## Common Mistakes / Pitfalls

- **Benchmarking the first query**: EF Core's first query includes LINQ compilation, model building, and JIT warm-up. Micro-benchmarks without warm-up make EF Core look far worse than it is in production.
- **Comparing tracked EF Core to Dapper**: This is fair but misleading — if you don't need tracking, use `AsNoTracking`. Always compare like-for-like (both read-only vs both read-only).
- **Using Dapper for writes in a DDD model**: Dapper bypasses domain logic, domain events, and EF Core's relationship management. Using it for writes leads to inconsistent state unless very carefully handled.
- **Abandoning EF Core entirely for "performance"**: Profiling rarely shows EF Core overhead as the bottleneck in real systems. Missing indexes, N+1 queries, and network latency are far more common culprits.
- **Not sharing connections between EF Core and Dapper**: If you need EF Core and Dapper in the same transaction, both must use the same `SqlConnection` and `SqlTransaction`. See [dapper-ef-core-hybrid.md](./dapper-ef-core-hybrid.md).

## References

- [EF Core performance documentation — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/)
- [Dapper — GitHub](https://github.com/DapperLib/Dapper)
- [BenchmarkDotNet — GitHub](https://github.com/dotnet/BenchmarkDotNet)
- [See: dapper-vs-ef-core.md](./dapper-vs-ef-core.md)
- [See: compiled-queries.md](./compiled-queries.md)
