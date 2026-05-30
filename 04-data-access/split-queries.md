# Split Queries in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `AsSplitQuery`, `cartesian-explosion`, `Include`, `performance`, `single-query`

## Question

> What is cartesian explosion in EF Core, and how does `AsSplitQuery` solve it? What are the trade-offs between single queries and split queries, and when should you use each?

## Short Answer

Cartesian explosion occurs when you `Include` multiple collection navigations in a single SQL query — the result set grows to `root_rows × collection_A_rows × collection_B_rows` because SQL JOINs produce a cross product. For an order with 50 lines and 10 tags, EF Core returns 500 rows but only needs 61. `AsSplitQuery` solves this by issuing a separate `SELECT` per included navigation, then stitching results together in memory — trading one large query for multiple focused ones. The trade-off is multiple round-trips vs large data transfer, and loss of snapshot isolation across the split queries.

## Detailed Explanation

### The Cartesian Explosion Problem

```csharp
var orders = await db.Orders
    .Include(o => o.Lines)   // each order has 50 lines
    .Include(o => o.Tags)    // each order has 10 tags
    .ToListAsync(ct);
```

Generated SQL (single query):

```sql
SELECT o.*, l.*, t.*
FROM   Orders o
LEFT   JOIN OrderLines l ON l.OrderId = o.Id
LEFT   JOIN OrderTags  ot ON ot.OrderId = o.Id
LEFT   JOIN Tags t ON t.Id = ot.TagId
```

For 10 orders × 50 lines × 10 tags = **5,000 rows** returned to the application. EF Core correctly deduplicates into 10 `Order` objects each with 50 lines and 10 tags, but **5,000 rows** were transferred from the DB.

The more collection navigations you include, and the more rows each has, the worse this gets.

### `AsSplitQuery` — Separate Queries per Navigation

```csharp
var orders = await db.Orders
    .Include(o => o.Lines)
    .Include(o => o.Tags)
    .AsSplitQuery()
    .ToListAsync(ct);
```

EF Core issues 3 queries:

```sql
-- Query 1: root rows
SELECT o.*
FROM   Orders o;

-- Query 2: first collection
SELECT l.*
FROM   OrderLines l
WHERE  l.OrderId IN (SELECT Id FROM Orders);

-- Query 3: second collection
SELECT t.*, ot.OrderId
FROM   Tags t
JOIN   OrderTags ot ON t.Id = ot.TagId
WHERE  ot.OrderId IN (SELECT Id FROM Orders);
```

Total rows: 10 + 500 + 100 = 610 — vs 5,000 for the single query. The data transfer is roughly 8× smaller.

### When Split Queries Win

| Scenario | Winner | Reason |
|----------|--------|--------|
| Multiple collection navigations (≥2), each with many rows | Split | Massive reduction in duplicate data |
| Deep hierarchy: Orders → Lines → Products → Categories | Split | Exponential explosion per level |
| Small collections (< 5 rows each) | Single | Round-trip overhead exceeds savings |
| Single collection navigation | Single | No explosion; single query is simpler |
| Strong consistency required (snapshot) | Single | Split queries aren't transactional by default |
| Network with high latency (e.g., Azure region hop) | Single | Multiple round-trips are expensive |

### The Consistency Trade-off

Split queries are NOT atomic:

```
Time: Query 1 executes → new OrderLine inserted → Query 2 executes
Result: Order object has the new line even though the root snapshot didn't include it
```

For read-heavy APIs where slight staleness is acceptable, this is usually fine. For financial or audit-sensitive operations, wrap in an explicit transaction:

```csharp
await using var tx = await db.Database.BeginTransactionAsync(
    IsolationLevel.RepeatableRead, ct);

var orders = await db.Orders
    .Include(o => o.Lines)
    .AsSplitQuery()
    .ToListAsync(ct);

await tx.CommitAsync(ct);  // or just let it scope — no modifications, no need to commit
```

### Global Split Query Default (EF Core 5+)

Set split query as the default for all queries in the context:

```csharp
options.UseSqlServer(connStr,
    sql => sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery));
```

Then opt back to single query for specific queries where consistency matters:

```csharp
var order = await db.Orders
    .Include(o => o.Lines)
    .AsSingleQuery()   // opt out of global default
    .FirstAsync(o => o.Id == id, ct);
```

### Detecting Cartesian Explosion

Look for the warning in EF Core logs:

```
Microsoft.EntityFrameworkCore.Query: Warning: Compiling a query which loads related
collections for more than one collection navigation, either via 'Include' or through
projection. Consider using 'AsSplitQuery()' to avoid generating a Cartesian product.
```

Enable warnings-as-errors for this in tests:

```csharp
options.ConfigureWarnings(w =>
    w.Throw(RelationalEventId.MultipleCollectionIncludeWarning));
```

## Code Example

```csharp
// Demonstrating the explosion and the fix

// ❌ Explosion: 100 orders × 50 lines × 10 tags = 50,000 rows
var bad = await db.Orders
    .Include(o => o.Lines)
        .ThenInclude(l => l.Product)
    .Include(o => o.Tags)
    .ToListAsync(ct);
// EF Core logs: "Compiling a query which loads related collections for more than one
//               collection navigation... Consider using AsSplitQuery()"

// ✅ Split: 100 + 5000 + 1000 = 6,100 rows across 3 queries
var good = await db.Orders
    .Include(o => o.Lines)
        .ThenInclude(l => l.Product)
    .Include(o => o.Tags)
    .AsSplitQuery()
    .ToListAsync(ct);

// ✅ Even better: projection avoids Include entirely
var best = await db.Orders
    .Select(o => new OrderViewModel(
        o.Id,
        o.Reference,
        o.Lines.Select(l => new LineDto(l.ProductId, l.Quantity)).ToList(),
        o.Tags.Select(t => t.Name).ToList()))
    .ToListAsync(ct);
// EF Core generates efficient correlated subqueries — no cartesian product
```

## Common Follow-up Questions

- Does `AsSplitQuery` work with filtered `Include` (`.Include(o => o.Lines.Where(...))`)?
- How does split query interact with `Skip`/`Take` pagination — does each split query respect the paging?
- What is the performance difference between `AsSplitQuery` and manually writing separate queries?
- Is there a scenario where projection (`Select`) is always better than `Include` for collections?
- How do split queries interact with global query filters (e.g., soft delete)?

## Common Mistakes / Pitfalls

- **Assuming split queries are always faster**: For small collections or single-navigation includes, the extra round-trip is slower. Benchmark before switching globally.
- **Using `AsSplitQuery` without a transaction for write-read operations**: Reading with `AsSplitQuery` after a write in the same request may see inconsistent state if the DB is under load.
- **`AsSplitQuery` with `Skip`/`Take`**: The root query paging is applied to the first split query. Child queries use `WHERE ParentId IN (...)` scoped to the paged root rows — this is correct, but the `IN` list can get large for big pages.
- **Setting `SplitQuery` globally without testing all queries**: Some queries that were fast as single queries become slower as split queries (extra round-trips). Test your hot paths after switching the default.
- **Not configuring `MultipleCollectionIncludeWarning`**: The cartesian explosion warning is a `Warning` by default — it won't break your app. Consider promoting it to an error in tests to catch new occurrences.

## References

- [Single vs split queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/single-split-queries)
- [Eager loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager)
- [See: filtered-include.md](./filtered-include.md)
- [See: n-plus-one-problem.md](./n-plus-one-problem.md)
