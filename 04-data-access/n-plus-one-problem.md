# The N+1 Problem in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `n-plus-one`, `eager-loading`, `Include`, `performance`, `SQL-logging`

## Question

> What is the N+1 query problem in EF Core? How do you detect it, and what are the main ways to fix it?

## Short Answer

The N+1 problem occurs when code loads a collection of N entities and then, for each entity, issues an additional query to load a related entity — resulting in N+1 database round-trips instead of one. In EF Core it most often happens with uninitialized navigation properties accessed in a loop, or with lazy loading enabled. Detection: enable SQL logging or MiniProfiler and look for many nearly-identical queries. Fix: use `Include`/`ThenInclude` for eager loading, or use projections with `Select`.

## Detailed Explanation

### Classic Example

```csharp
// ❌ N+1 — EF Core issues 1 query for orders, then N queries for customers
var orders = await db.Orders.ToListAsync(ct);      // SQL: SELECT * FROM Orders → N rows
foreach (var order in orders)
{
    Console.WriteLine(order.Customer.Name);         // SQL: SELECT * FROM Customers WHERE Id = @id
}                                                   // ← repeated N times
```

With 100 orders and lazy loading disabled, `order.Customer` returns `null` (NullReferenceException). With lazy loading enabled, each property access triggers a synchronous SQL round-trip — the worst combination of correctness (barely works) and performance (catastrophic).

### Why It's Dangerous

| Metric | 1 query with JOIN | N+1 queries |
|--------|------------------|-------------|
| Round-trips | 1 | N+1 |
| Total data transferred | ~same | Much more (headers, auth, framing) |
| Latency on Azure SQL | ~5ms | 5ms × (N+1) |
| 1 000 orders | ~5ms | ~5 000ms |

### Detection: SQL Logging

```csharp
// appsettings.Development.json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
}
// Symptom: you see the same query repeated hundreds of times with different Id values
```

Look for repeating patterns like:
```
Executed DbCommand (1ms) [SELECT … WHERE CustomerId = @p0] -- @p0 = 1
Executed DbCommand (1ms) [SELECT … WHERE CustomerId = @p0] -- @p0 = 2
Executed DbCommand (1ms) [SELECT … WHERE CustomerId = @p0] -- @p0 = 3
```

### Fix 1: Eager Loading with `Include`

```csharp
// ✅ 1 SQL query with JOIN (or 2 with AsSplitQuery)
var orders = await db.Orders
    .Include(o => o.Customer)
    .ToListAsync(ct);

foreach (var order in orders)
    Console.WriteLine(order.Customer.Name);  // already loaded — no extra SQL
```

### Fix 2: Projection to DTO (Best for Read-Only APIs)

```csharp
// ✅ Fetches only the columns you need — no tracking, no N+1
var dtos = await db.Orders
    .Select(o => new OrderDto(
        o.Id,
        o.Customer.Name,  // EF Core translates to SQL JOIN automatically
        o.Total))
    .ToListAsync(ct);
```

Select projection is often better than `Include` because:
- Only specified columns are fetched (less data).
- EF Core translates nested property access into SQL JOINs automatically.
- No tracked entity allocation overhead.

### Fix 3: Split Queries for Multiple Collections

When including multiple collection navigations, `Include` produces a cartesian product. Use `AsSplitQuery`:

```csharp
var customers = await db.Customers
    .Include(c => c.Orders)
    .Include(c => c.Addresses)
    .AsSplitQuery()          // 3 separate queries, no cartesian explosion
    .ToListAsync(ct);
```

[See: split-queries.md](./split-queries.md)

### Lazy Loading — The N+1 Enabler

Lazy loading (via proxies or `ILazyLoader`) is the primary enabler of accidental N+1:

```csharp
// ❌ Avoid: lazy loading makes N+1 invisible at the call site
services.AddDbContext<AppDb>(opt =>
    opt.UseLazyLoadingProxies()  // makes all navigations lazy by default
       .UseSqlServer(conn));
```

> **Warning:** In ASP.NET Core, the DbContext is disposed at the end of the request. If a serializer (e.g., System.Text.Json) accesses lazy-loading navigation properties during serialization, it will trigger queries on a disposed context — a hard-to-debug `ObjectDisposedException`.

## Code Example

```csharp
// ❌ N+1 with lazy loading proxies
var products = await db.Products.ToListAsync(ct);
foreach (var p in products)
    Console.WriteLine(p.Category.Name);  // each access = 1 SQL query

// ✅ Fix 1: eager loading
var products = await db.Products
    .Include(p => p.Category)
    .ToListAsync(ct);

// ✅ Fix 2: projection — no tracking, minimal columns
var summaries = await db.Products
    .Select(p => new { p.Name, CategoryName = p.Category.Name, p.Price })
    .ToListAsync(ct);

// ✅ Fix 3: load related data in bulk separately, then join in memory
var products = await db.Products.AsNoTracking().ToListAsync(ct);
var categoryIds = products.Select(p => p.CategoryId).Distinct().ToList();
var categories = await db.Categories
    .Where(c => categoryIds.Contains(c.Id))
    .AsNoTracking()
    .ToDictionaryAsync(c => c.Id, ct);

foreach (var p in products)
    Console.WriteLine(categories[p.CategoryId].Name);
// 2 queries total instead of N+1
```

## Common Follow-up Questions

- How does `AsSplitQuery` avoid the cartesian explosion, and what new problem can it introduce?
- When should you prefer projection over `Include`?
- How does lazy loading interact with async code and the disposed-context problem?
- Can N+1 happen without lazy loading? (Yes — explicit in-loop calls to `db.X.FindAsync`)
- How do you detect N+1 in a CI pipeline (before production)?

## Common Mistakes / Pitfalls

- **Relying on lazy loading in controllers/serializers**: Lazy loading makes N+1 easy to introduce and hard to see — navigations appear to "just work" in development but destroy production performance.
- **Using `Include` when only one column is needed**: `Include(o => o.Customer)` fetches the entire `Customer` row. If you only need `Customer.Name`, a `Select` projection is more efficient.
- **Testing with tiny data sets**: With 5 orders in a dev database, N+1 is imperceptibly fast. With 5 000 orders in production, it becomes a 5-second page load.
- **Missing nested N+1 inside LINQ operator chains**: `db.Orders.ToList().SelectMany(o => o.Lines)` — `o.Lines` accesses the navigation after materialization, re-triggering lazy loads for each order.
- **Assuming `Include` always generates a single SQL query**: Multiple `Include` calls on collection navigations produce a cartesian product unless `AsSplitQuery` is used.

## References

- [Loading related data — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data)
- [Eager loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager)
- [Lazy loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/lazy)
- [EF Core performance: efficient loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-querying#beware-of-lazy-loading)
- [See: eager-vs-lazy-vs-explicit-loading.md](./eager-vs-lazy-vs-explicit-loading.md)
