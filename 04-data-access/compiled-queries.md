# Compiled Queries in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `compiled-queries`, `EF.CompileQuery`, `performance`, `LINQ-translation`

## Question

> What are compiled queries in EF Core, and when do they provide a meaningful performance benefit? How do you create one with `EF.CompileQuery`, and what are the restrictions?

## Short Answer

Every LINQ query in EF Core goes through a **translation pipeline** — parsing the expression tree, building the SQL AST, and generating the SQL string. In EF Core 5+ this pipeline is cached per query shape, so repeated calls to the same LINQ query don't pay the translation cost again. A **compiled query** (`EF.CompileQuery`) pre-compiles a specific parameterized query into a delegate at startup, bypassing the cache lookup overhead on the hot path. The gain is small for most queries (microseconds) but measurable in high-throughput scenarios where a single query is called millions of times per second. The trade-off is reduced flexibility: compiled queries cannot use dynamic filters or be further composed with LINQ operators.

## Detailed Explanation

### How EF Core Caches Regular Queries

Since EF Core 5, every `IQueryable` expression tree is compiled on first execution and cached using the query shape as the key. Subsequent calls with the same shape but different parameter values use the cached SQL plan, substituting the new parameter values.

This means for most applications, regular LINQ queries are fast enough — the cache is hit on every call after the first.

### When Compiled Queries Help

Compiled queries eliminate even the **cache lookup** cost. They matter when:

- A specific query runs millions of times per second on a hot path.
- The query is simple and the overhead of the cache lookup is significant relative to the query execution time (e.g., looking up a single entity by PK).
- BenchmarkDotNet shows the query translation overhead is a bottleneck.

Benchmarks typically show compiled queries are **2–5× faster** than regular LINQ for very simple queries and negligible difference for complex, slow queries.

### `EF.CompileQuery` — Synchronous

```csharp
// Defined as a static field — compiled once at startup
private static readonly Func<AppDbContext, int, Order?> GetOrderById =
    EF.CompileQuery(
        (AppDbContext db, int id) =>
            db.Orders.FirstOrDefault(o => o.Id == id));

// Usage — zero translation overhead; db.Connection.Open() is still async-unsafe here
var order = GetOrderById(db, orderId);
```

### `EF.CompileAsyncQuery` — Asynchronous

```csharp
private static readonly Func<AppDbContext, int, CancellationToken, Task<Order?>> GetOrderByIdAsync =
    EF.CompileAsyncQuery(
        (AppDbContext db, int id) =>
            db.Orders.FirstOrDefault(o => o.Id == id));

// Usage
var order = await GetOrderByIdAsync(db, orderId, ct);
```

For queries that return collections, the signature uses `IAsyncEnumerable<T>`:

```csharp
private static readonly Func<AppDbContext, string, IAsyncEnumerable<Order>> GetOrdersByStatus =
    EF.CompileAsyncQuery(
        (AppDbContext db, string status) =>
            db.Orders.Where(o => o.Status == status).OrderBy(o => o.CreatedAt));

// Usage — must enumerate
await foreach (var order in GetOrdersByStatus(db, "Pending"))
{
    // process
}
```

### Restrictions on Compiled Queries

| Restriction | Detail |
|-------------|--------|
| No dynamic composition | Cannot call `.Where()` / `.Include()` on the compiled delegate at call time |
| No closure over variables | All parameters must be explicit function parameters — no captured lambdas |
| No `Include` on navigations (partially) | `Include` works at compile time but is baked in; can't add/remove at runtime |
| Parameters are limited | Up to 8 parameters (via `Func<T1,T2,...>` generic arity) |
| Not for one-off queries | Only worthwhile for hot-path queries called repeatedly with the same shape |

> **EF Core 9 note:** In EF Core 9 "pre-compiled queries" (AOT-friendly, distinct from `EF.CompileQuery`) were added to enable NativeAOT trimming. These are different from runtime compiled queries.

### Measuring the Benefit

Before adding compiled queries, benchmark with BenchmarkDotNet:

```csharp
[Benchmark(Baseline = true)]
public Order? RegularQuery() => _db.Orders.FirstOrDefault(o => o.Id == _id);

[Benchmark]
public Order? CompiledQuery() => GetOrderById(_db, _id);
```

If the regular query is already bottlenecked by I/O (the DB round-trip), the compiled query will show no significant improvement — the overhead is dwarfed by network latency.

## Code Example

```csharp
// Compiled queries as static fields on a repository or dedicated class
public static class OrderQueries
{
    // Single entity lookup — highest-value compiled query (hot path)
    public static readonly Func<AppDbContext, int, CancellationToken, Task<Order?>>
        ByIdAsync = EF.CompileAsyncQuery(
            (AppDbContext db, int id) =>
                db.Orders
                  .Include(o => o.Lines)
                  .FirstOrDefault(o => o.Id == id));

    // Collection by status — paged
    public static readonly Func<AppDbContext, string, int, int, IAsyncEnumerable<OrderSummary>>
        ByStatusPaged = EF.CompileAsyncQuery(
            (AppDbContext db, string status, int skip, int take) =>
                db.Orders
                  .Where(o => o.Status == status)
                  .OrderByDescending(o => o.CreatedAt)
                  .Skip(skip)
                  .Take(take)
                  .Select(o => new OrderSummary(o.Id, o.Reference, o.Total)));

    // Count query
    public static readonly Func<AppDbContext, string, CancellationToken, Task<int>>
        CountByStatus = EF.CompileAsyncQuery(
            (AppDbContext db, string status) =>
                db.Orders.Count(o => o.Status == status));
}

// Usage in service
public sealed class OrderService(AppDbContext db)
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct) =>
        await OrderQueries.ByIdAsync(db, id, ct);

    public async Task<List<OrderSummary>> GetByStatusAsync(
        string status, int page, int pageSize, CancellationToken ct)
    {
        var result = new List<OrderSummary>();
        await foreach (var item in OrderQueries.ByStatusPaged(db, status,
                           (page - 1) * pageSize, pageSize))
            result.Add(item);
        return result;
    }
}
```

## Common Follow-up Questions

- What is the difference between EF Core's automatic query plan cache and `EF.CompileQuery`?
- How do EF Core 9 pre-compiled queries (for AOT) differ from runtime compiled queries?
- Can you use `Include` inside a compiled query — does it compose correctly?
- If EF Core already caches query plans, in what real-world scenario does the microsecond saving from compiled queries matter?
- What happens if you update the EF Core model — do compiled queries need to be re-run?

## Common Mistakes / Pitfalls

- **Premature optimization**: Adding compiled queries without benchmarking first. For the vast majority of applications, EF Core's automatic caching is sufficient.
- **Capturing variables in the query body**: Writing `EF.CompileQuery((AppDbContext db) => db.Orders.Where(o => o.Id == externalVar))` captures `externalVar` at compile time — it doesn't vary per call. Always use explicit parameters.
- **Not storing as static field**: Creating a new compiled query on every request defeats the purpose — the compilation overhead occurs on every call. Store them as `static readonly` fields.
- **Expecting LINQ composition after compilation**: `GetOrderById(db, 1).Where(...)` doesn't work — the delegate returns `Order?` (or `Task<Order?>`), not `IQueryable<T>`. Compiled queries are terminal.
- **Incorrect async enumerable handling**: `CompileAsyncQuery` for collections returns `IAsyncEnumerable<T>`, not `Task<List<T>>`. You must `await foreach` or collect with `ToListAsync` — calling `.Result` on it blocks.

## References

- [Compiled queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics#compiled-queries)
- [Advanced performance topics — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics)
- [EF Core 9 pre-compiled queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-9.0/whatsnew#pre-compiled-queries)
