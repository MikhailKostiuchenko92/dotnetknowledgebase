# LINQ Queries in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `linq`, `querying`, `translation`, `sql`, `common-gotchas`

## Question

> How do `Where`, `Select`, `OrderBy`, and `GroupBy` translate to SQL in EF Core? What are the common interview traps and translation gotchas you should know?

## Short Answer

EF Core translates LINQ operators to SQL by walking the expression tree your query composes. `Where` → `WHERE`, `Select` → `SELECT` (with column projection), `OrderBy`/`OrderByDescending` → `ORDER BY`, `Take`/`Skip` → `FETCH NEXT`/`OFFSET`. `GroupBy` is special — it translates when followed by an aggregate (`Sum`, `Count`, `Max`) but falls back to client evaluation if you try to materialize the groups themselves. Common traps: using string methods that aren't translatable, mixing `IEnumerable<T>` after early materialization, and forgetting that `Contains` on a local list generates an `IN` clause.

## Detailed Explanation

### Basic Operator Translations

```csharp
// WHERE
db.Orders.Where(o => o.Status == "Pending")
// → SELECT … FROM Orders WHERE Status = 'Pending'

// SELECT (projection)
db.Orders.Select(o => new { o.Id, o.Reference })
// → SELECT Id, Reference FROM Orders

// ORDER BY
db.Orders.OrderByDescending(o => o.CreatedAt)
// → SELECT … FROM Orders ORDER BY CreatedAt DESC

// SKIP + TAKE (pagination)
db.Orders.Skip(20).Take(10)
// → SELECT … FROM Orders ORDER BY … OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY

// FIRST/SINGLE
db.Orders.FirstOrDefault(o => o.Id == id)
// → SELECT TOP 1 … FROM Orders WHERE Id = @id

// ANY
db.Orders.Any(o => o.Status == "Pending")
// → SELECT CASE WHEN EXISTS (SELECT 1 FROM Orders WHERE Status='Pending') THEN 1 ELSE 0 END

// COUNT
db.Orders.Count(o => o.Status == "Pending")
// → SELECT COUNT(*) FROM Orders WHERE Status = 'Pending'
```

### GroupBy Translations (and Traps)

`GroupBy` translates to SQL `GROUP BY` **only when followed by an aggregate**:

```csharp
// ✅ Translates: SELECT Status, COUNT(*) FROM Orders GROUP BY Status
var counts = await db.Orders
    .GroupBy(o => o.Status)
    .Select(g => new { Status = g.Key, Count = g.Count() })
    .ToListAsync(ct);

// ✅ Translates: aggregate with sum
var revenue = await db.Orders
    .GroupBy(o => o.CustomerId)
    .Select(g => new { CustomerId = g.Key, Total = g.Sum(o => o.Amount) })
    .ToListAsync(ct);

// ❌ Does NOT translate in most cases: trying to project group members
var grouped = await db.Orders
    .GroupBy(o => o.Status)
    .ToListAsync(ct);  // EF Core 6+: throws; earlier: client eval warning
```

> EF Core 6+ throws `InvalidOperationException` when it cannot translate `GroupBy` to SQL and client evaluation is disabled (the default). If you need grouped collections in memory, use `ToListAsync()` first and then `GroupBy` in LINQ to Objects.

### `Contains` with Local Collections → `IN`

```csharp
var statuses = new[] { "Pending", "Processing" };

// ✅ Translates to: WHERE Status IN ('Pending', 'Processing')
var orders = await db.Orders
    .Where(o => statuses.Contains(o.Status))
    .ToListAsync(ct);
```

> **Limit:** Very large local collections (thousands of items) generate huge `IN` clauses. For large sets, use a temp table or `JOIN` instead.

### String Method Translations

EF Core translates many `string` methods to SQL functions. Knowing what translates and what doesn't is a common interview topic:

| C# | SQL Server | Translates? |
|----|-----------|-------------|
| `s.ToLower()` | `LOWER(s)` | ✅ |
| `s.ToUpper()` | `UPPER(s)` | ✅ |
| `s.Contains("x")` | `s LIKE '%x%'` | ✅ |
| `s.StartsWith("x")` | `s LIKE 'x%'` | ✅ |
| `s.EndsWith("x")` | `s LIKE '%x'` | ✅ |
| `s.Length` | `LEN(s)` | ✅ |
| `string.IsNullOrEmpty(s)` | `s IS NULL OR s = ''` | ✅ |
| `s.Substring(1, 3)` | `SUBSTRING(s, 2, 3)` | ✅ (note: 0-indexed → 1-indexed) |
| `s.Replace("a","b")` | `REPLACE(s,'a','b')` | ✅ |
| `Regex.IsMatch(s, p)` | ❌ | ❌ (client eval) |
| Custom method `MyFormat(s)` | ❌ | ❌ (client eval) |

### `DateTime` Translations

```csharp
// ✅ Translates
.Where(o => o.CreatedAt.Year == 2024)
.Where(o => o.CreatedAt >= DateTime.UtcNow.AddDays(-7))
.Where(o => o.CreatedAt.Date == DateTime.Today)

// ✅ EF Core function helpers (strongly typed)
.Where(o => EF.Functions.DateDiffDay(o.CreatedAt, DateTime.UtcNow) <= 7)
```

### `EF.Functions` — Provider-Specific Functions

`EF.Functions` exposes SQL functions that have no C# equivalent:

```csharp
// LIKE with wildcards (more control than StartsWith/Contains)
.Where(o => EF.Functions.Like(o.Reference, "ORD-%"))

// SQL Server full-text search
.Where(o => EF.Functions.Contains(o.Notes, "urgent"))

// Date diff
.Where(o => EF.Functions.DateDiffDay(o.CreatedAt, DateTime.UtcNow) < 30)
```

### Null Handling

EF Core generates `IS NULL` checks for nullable comparisons:

```csharp
// Where Notes is null
.Where(o => o.Notes == null)
// → WHERE Notes IS NULL

// Where Notes is not null
.Where(o => o.Notes != null)
// → WHERE Notes IS NOT NULL
```

## Code Example

```csharp
// Full query composition example
public async Task<PagedResult<OrderSummaryDto>> SearchOrdersAsync(
    OrderSearchRequest req, CancellationToken ct)
{
    IQueryable<Order> query = db.Orders
        .Include(o => o.Customer);

    // Dynamic filters — all pushed to SQL
    if (!string.IsNullOrEmpty(req.Status))
        query = query.Where(o => o.Status == req.Status);

    if (req.CustomerId.HasValue)
        query = query.Where(o => o.CustomerId == req.CustomerId);

    if (req.From.HasValue)
        query = query.Where(o => o.CreatedAt >= req.From.Value);

    if (!string.IsNullOrEmpty(req.ReferenceSearch))
        query = query.Where(o => o.Reference.StartsWith(req.ReferenceSearch));

    // Total count (separate SQL COUNT(*) query)
    var total = await query.CountAsync(ct);

    // Projection to DTO + pagination — all in SQL
    var items = await query
        .OrderByDescending(o => o.CreatedAt)
        .Skip((req.Page - 1) * req.PageSize)
        .Take(req.PageSize)
        .Select(o => new OrderSummaryDto(
            o.Id,
            o.Reference,
            o.Customer.Name,     // joined via Include
            o.Status,
            o.Total))
        .ToListAsync(ct);

    return new PagedResult<OrderSummaryDto>(items, total, req.Page, req.PageSize);
}
```

## Common Follow-up Questions

- Why does `GroupBy` with a collection projection fail in EF Core 6+ but work as a warning in EF Core 5?
- How does EF Core handle `null` propagation in LINQ expressions — does it generate SQL `IS NULL` checks automatically?
- What happens when you call a C# method inside a `Where` predicate that EF Core can't translate?
- How does `EF.Functions.Like` differ from `string.Contains` for pattern matching in SQL?
- How does EF Core handle `Select` projections that reference navigation properties not explicitly `Include`d?

## Common Mistakes / Pitfalls

- **`GroupBy` without aggregate**: Materializing group members with `GroupBy().ToList()` triggers client evaluation (or an exception in EF Core 6+). Always follow `GroupBy` with `Select(g => new { Key, Agg = g.Count() })`.
- **Non-translatable methods inside predicates**: Calling `MyHelper.Format(o.Reference)` in a `Where` clause → EF Core can't translate → either throws or silently pulls all rows to the client.
- **Case sensitivity**: `string.Equals(s, "value", StringComparison.OrdinalIgnoreCase)` is not translatable. Use `s.ToLower() == "value"` or provider-specific collation settings.
- **`DateTime.Now` vs `DateTime.UtcNow`**: `DateTime.Now` in a LINQ predicate is captured as a constant at translation time and may differ from the DB server's notion of "now". Prefer `DateTime.UtcNow` and ensure the DB column is also stored as UTC.
- **Forgetting to materialize before complex C# logic**: Calling business-logic methods on lazily-loaded navigations inside a LINQ pipeline triggers N+1 queries or client evaluation.

## References

- [Basic querying — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/basic)
- [Complex query operators — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/complex-query-operators)
- [Client vs server evaluation — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/client-eval)
- [See: iqueryable-vs-ienumerable.md](./iqueryable-vs-ienumerable.md)
