# IQueryable vs IEnumerable in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `IQueryable`, `IEnumerable`, `deferred-execution`, `client-evaluation`, `LINQ`

## Question

> What is the difference between `IQueryable<T>` and `IEnumerable<T>` in the context of EF Core? When does the SQL query actually execute, and what happens if you switch to `IEnumerable<T>` too early?

## Short Answer

`IQueryable<T>` represents a query that has not yet executed — it builds an expression tree that EF Core translates to SQL. The database query only runs when you materialize the result (e.g., `ToListAsync`, `FirstOrDefaultAsync`, `foreach`). `IEnumerable<T>` represents an in-memory sequence; once you convert to `IEnumerable<T>`, all further LINQ operators run in C# on the client, not in SQL. Switching to `IEnumerable<T>` too early (e.g., by calling `.AsEnumerable()` or returning `IEnumerable<T>` from a repository method) means EF Core fetches the entire table to memory and filters locally — a potentially catastrophic performance bug.

## Detailed Explanation

### Expression Trees vs Delegates

- **`IQueryable<T>`** stores a LINQ expression tree. Each chained operator adds nodes to the tree without executing anything. When the query is materialized, EF Core's query provider walks the tree and generates SQL.
- **`IEnumerable<T>`** works with delegates (`Func<T, bool>`). Operators like `Where` iterate the sequence in memory.

```csharp
// IQueryable<T> — builds expression tree, no SQL yet
IQueryable<Order> query = db.Orders.Where(o => o.Status == "Pending");
query = query.OrderByDescending(o => o.CreatedAt);  // still no SQL

// SQL executes HERE → SELECT … WHERE Status='Pending' ORDER BY CreatedAt DESC
var result = await query.ToListAsync(ct);
```

### When Does SQL Execute?

The query executes (is "materialized") when you call:

| Method | Executes? |
|--------|-----------|
| `ToListAsync()` / `ToArrayAsync()` | ✅ Yes |
| `FirstOrDefaultAsync()` | ✅ Yes |
| `SingleAsync()` | ✅ Yes |
| `AnyAsync()` / `CountAsync()` | ✅ Yes |
| `await foreach` (IAsyncEnumerable) | ✅ Yes (streaming) |
| `.Where()`, `.Select()`, `.OrderBy()` | ❌ No — deferred |
| `.AsEnumerable()` | ✅ Yes (immediately fetches) |
| `foreach` on `IQueryable` | ✅ Yes |

### The "Too Early" Trap

```csharp
// ❌ Returns IEnumerable<Order> — the ENTIRE orders table is loaded into memory
// Then filtered locally in C#
public IEnumerable<Order> GetPendingOrders()
{
    return db.Orders.AsEnumerable()           // ← FULL TABLE SCAN into memory
             .Where(o => o.Status == "Pending");  // ← C# filter
}

// ✅ Stays IQueryable<Order> — SQL WHERE clause is generated
public IQueryable<Order> GetPendingOrders()
{
    return db.Orders.Where(o => o.Status == "Pending");  // ← deferred SQL
}

// ✅ Materializes with bounds at the right layer
public async Task<List<Order>> GetPendingOrdersAsync(CancellationToken ct)
{
    return await db.Orders
        .Where(o => o.Status == "Pending")
        .OrderBy(o => o.CreatedAt)
        .Take(100)
        .ToListAsync(ct);
}
```

### Legitimate Uses of `AsEnumerable()` / `AsAsyncEnumerable()`

Sometimes you genuinely need to switch to client evaluation — when the LINQ expression can't be translated to SQL:

```csharp
// ✅ Intentional client evaluation: complex C# method not translatable to SQL
var enriched = await db.Orders
    .Where(o => o.Status == "Pending")          // SQL filter (narrow first)
    .Select(o => new { o.Id, o.Reference })     // SQL projection (minimal columns)
    .ToListAsync(ct)                            // ← materialize with SQL
    .ContinueWith(t => t.Result                 
        .Select(o => new OrderDto(o.Id, FormatRef(o.Reference))));  // C# enrichment

// ✅ Streaming large result sets without loading all into memory at once
await foreach (var order in db.Orders.AsAsyncEnumerable())
{
    await ProcessAsync(order, ct);
}
```

### `IQueryable<T>` Leaking from Repositories

A common debate: should repositories return `IQueryable<T>` or `IEnumerable<T>` / `List<T>`?

| Return type | Pros | Cons |
|-------------|------|------|
| `IQueryable<T>` | Caller can compose (add Where/Select/Include) | Leaks EF Core dependency; queries built outside of repository |
| `IEnumerable<T>` | Encapsulated; testable without EF | Caller can't add server-side predicates; risks loading too much |
| `List<T>` / `Task<List<T>>` | Clear contract; safe | Same as IEnumerable; no composition |

> Prefer returning concrete collections (`Task<List<T>>`) from repositories. If composition is needed, use the Specification pattern rather than leaking `IQueryable<T>`.

## Code Example

```csharp
// Comparing SQL generated for IQueryable vs IEnumerable

// Setup: 1 million orders in DB, 100 pending

// ❌ IEnumerable — one SQL: SELECT * FROM Orders (1M rows → memory)
// then C# filters 100 out of 1M in-process
var bad = db.Orders
    .AsEnumerable()
    .Where(o => o.Status == "Pending")
    .Take(10)
    .ToList();

// ✅ IQueryable — one SQL: SELECT TOP 10 * FROM Orders WHERE Status = 'Pending'
var good = await db.Orders
    .Where(o => o.Status == "Pending")
    .Take(10)
    .ToListAsync(ct);

// ✅ IQueryable composition: build query conditionally
IQueryable<Order> query = db.Orders;

if (!string.IsNullOrEmpty(filter.Status))
    query = query.Where(o => o.Status == filter.Status);

if (filter.CustomerId.HasValue)
    query = query.Where(o => o.CustomerId == filter.CustomerId.Value);

query = query.OrderByDescending(o => o.CreatedAt)
             .Skip((filter.Page - 1) * filter.PageSize)
             .Take(filter.PageSize);

// One SQL executed with all conditions
var orders = await query.ToListAsync(ct);
```

## Common Follow-up Questions

- How does EF Core decide whether to evaluate an expression in SQL or in C# (client evaluation)?
- What is the difference between `AsEnumerable()` and `ToList()` / `ToListAsync()` in terms of when the query executes?
- If a repository returns `IQueryable<T>`, how does that affect unit testability and the separation of concerns?
- What happens when you call `Count()` on an `IQueryable<T>` vs on a materialised `List<T>`?
- How does `AsAsyncEnumerable()` differ from `ToListAsync()` for large result sets?

## Common Mistakes / Pitfalls

- **`AsEnumerable()` in a repository**: Looks like lazy loading, but immediately fetches all rows. Any further LINQ runs in memory.
- **Materializing inside a loop**: `db.Orders.ToList()` inside a loop creates N+1 queries. Build the full query outside the loop.
- **Returning `IQueryable<T>` from a method after the `DbContext` is disposed**: The query can't execute after context disposal — yields `ObjectDisposedException` at enumeration.
- **Adding `Where` clauses after `ToListAsync()`**: Operators on `IEnumerable` after materialization are silent — they don't add to the SQL. A `.Where()` on a `List<T>` filters in memory only.
- **Using `Count()` on an `IQueryable<T>` when you only need `Any()`**: `Count()` fetches `COUNT(*)` with a full scan; `Any()` generates `SELECT TOP 1` — use `AnyAsync()` for existence checks.

## References

- [How queries work in EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/how-query-works)
- [Client vs server evaluation — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/client-eval)
- [IQueryable vs IEnumerable — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/linq/introduction-linq-queries)
- [See: client-side-evaluation.md](./client-side-evaluation.md)
