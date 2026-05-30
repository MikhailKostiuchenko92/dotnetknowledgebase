# Filtered Include in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `Include`, `filtered-include`, `ThenInclude`, `AsSplitQuery`, `eager-loading`

## Question

> How does `Include` work in EF Core, and what is filtered `Include`? When should you use `ThenInclude` for deep navigation paths, and when does `AsSplitQuery` help with cartesian explosion?

## Short Answer

`Include` eagerly loads related entities in the same query, adding a JOIN to the generated SQL. **Filtered `Include`** (EF Core 5+) lets you apply `Where`, `OrderBy`, `Take`, etc. inside the include so only a subset of related entities is loaded — e.g., only the 5 most recent order lines rather than all. `ThenInclude` extends the navigation chain to load nested related entities (e.g., `Orders → Lines → Product`). When you include multiple collection navigations, EF Core generates a query with a cartesian product (each root row multiplied by each child row) — `AsSplitQuery` avoids this by issuing separate SQL queries per navigation.

## Detailed Explanation

### Basic `Include`

```csharp
// LEFT JOIN Customers ON Orders.CustomerId = Customers.Id
var orders = await db.Orders
    .Include(o => o.Customer)
    .ToListAsync(ct);
```

EF Core generates:

```sql
SELECT o.*, c.*
FROM   Orders o
LEFT   JOIN Customers c ON o.CustomerId = c.Id
```

### `ThenInclude` — Deep Navigation

Load nested related data:

```csharp
// Orders → Lines → Product
var orders = await db.Orders
    .Include(o => o.Lines)
        .ThenInclude(l => l.Product)
    .Include(o => o.Customer)   // separate Include for a different navigation branch
    .ToListAsync(ct);
```

SQL: `Orders JOIN OrderLines ON ... JOIN Products ON ... LEFT JOIN Customers ON ...`

### Filtered Include (EF Core 5+)

Apply a predicate or ordering **inside** the include to limit which related entities are loaded:

```csharp
// Load only the 3 most recent lines per order
var orders = await db.Orders
    .Include(o => o.Lines
        .Where(l => !l.IsCancelled)   // filter
        .OrderByDescending(l => l.AddedAt)  // order
        .Take(3))                     // limit
    .ToListAsync(ct);
```

> **Supported operators in filtered Include**: `Where`, `OrderBy`/`OrderByDescending`, `ThenBy`/`ThenByDescending`, `Skip`, `Take`. Anything else throws.

Without filtered include (before EF Core 5), you'd load all lines and filter in memory — risking loading thousands of lines per order.

### Cartesian Explosion

When you `Include` **multiple collection navigations**, EF Core generates a `JOIN` for each. The result set has `(orders × lines × tags)` rows:

```csharp
// 10 orders × 100 lines × 5 tags = 5000 rows returned
var orders = await db.Orders
    .Include(o => o.Lines)   // 100 lines each
    .Include(o => o.Tags)    // 5 tags each
    .ToListAsync(ct);
```

EF Core deduplicates correctly (each `Order` object has exactly the right `Lines` and `Tags`), but the wire transfer and SQL processing of 5000 rows is wasteful.

### `AsSplitQuery` — Separate Queries per Navigation

Instead of one big JOIN, EF Core issues a separate `SELECT` per included navigation:

```csharp
var orders = await db.Orders
    .Include(o => o.Lines)
    .Include(o => o.Tags)
    .AsSplitQuery()    // ← 3 queries: 1 for Orders, 1 for Lines, 1 for Tags
    .ToListAsync(ct);
```

SQL issued:

```sql
-- Query 1: root
SELECT * FROM Orders;

-- Query 2: first navigation
SELECT ol.* FROM OrderLines ol
WHERE  ol.OrderId IN (SELECT Id FROM Orders);

-- Query 3: second navigation  
SELECT t.* FROM Tags t
JOIN OrderTags ot ON t.Id = ot.TagId
WHERE ot.OrderId IN (SELECT Id FROM Orders);
```

EF Core stitches the results together in memory.

**When `AsSplitQuery` wins:**

- Multiple collection `Include`s on each entity.
- Each entity has many child rows (lines, tags, events).
- Data transfer is the bottleneck.

**When `AsSplitQuery` loses:**

- Very large root result sets (each split query is a separate round-trip).
- The query is simple (single collection) — the extra round-trip costs more than the duplicate rows save.

> **Warning:** `AsSplitQuery` runs multiple queries in sequence — **not** in a transaction by default. If data changes between queries, you may get inconsistent results. Wrap in an explicit transaction for consistency.

### Global Split Query Default (EF Core 7+)

```csharp
// Set globally on the context options
options.UseSqlServer(connStr, sql => sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery));
// Then opt-in to single query per query:
db.Orders.Include(o => o.Lines).AsSingleQuery().ToListAsync(ct);
```

## Code Example

```csharp
// Filtered include: admin dashboard showing recent items per order
public async Task<List<OrderDetailView>> GetOrderDetailsAsync(
    List<int> orderIds, CancellationToken ct)
{
    return await db.Orders
        .Where(o => orderIds.Contains(o.Id))
        .Include(o => o.Customer)                      // reference nav: always single row
        .Include(o => o.Lines                          // filtered collection nav
            .Where(l => l.Status != "Cancelled")
            .OrderBy(l => l.ProductName)
            .Take(50))                                 // max 50 lines per order
        .Include(o => o.Tags)                          // another collection
        .AsSplitQuery()                                // avoid cartesian of Lines × Tags
        .Select(o => new OrderDetailView(
            o.Id,
            o.Reference,
            o.Customer.Name,
            o.Lines.Select(l => new LineView(l.ProductName, l.Quantity)).ToList(),
            o.Tags.Select(t => t.Name).ToList()))
        .ToListAsync(ct);
}
```

## Common Follow-up Questions

- Does EF Core `Include` work correctly when combined with `Select` (projection)? What happens to the include?
- How does filtered `Include` interact with global query filters — are both applied?
- When should you use `AsSplitQuery` globally vs per-query?
- How does `Include` on a many-to-many navigation with an implicit join table work?
- Is there a way to `Include` a navigation property conditionally based on a query parameter?

## Common Mistakes / Pitfalls

- **`Include` ignored with `Select`**: If you add `Select(o => new ...)` after `Include`, EF Core ignores the `Include` and generates appropriate JOINs from the projection instead. Don't add redundant `Include` before projections.
- **Loading too many levels**: `.Include(o => o.Orders).ThenInclude(o => o.Lines).ThenInclude(l => l.Product).ThenInclude(p => p.Category)` generates a massive JOIN producing millions of rows. Flatten with projections or limit depth.
- **`AsSplitQuery` without a transaction**: Multiple queries in a split query may see inconsistent data if rows are modified between them. Use an explicit `DbTransaction` when consistency matters.
- **Filtered `Include` on reference navigations**: Filtered include only works on **collection** navigations, not reference navigations. Trying to filter on a `HasOne` navigation throws at runtime.
- **Forgetting that `ThenInclude` syntax varies for collections vs references**: After a collection include (`Include(o => o.Lines)`), `ThenInclude` receives an element of the collection (`ThenInclude(l => l.Product)`), not the collection itself — a common IntelliSense confusion.

## References

- [Eager loading with Include — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager)
- [Filtered include — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager#filtered-include)
- [Split queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/single-split-queries)
- [See: eager-vs-lazy-vs-explicit-loading.md](./eager-vs-lazy-vs-explicit-loading.md)
- [See: n-plus-one-problem.md](./n-plus-one-problem.md)
