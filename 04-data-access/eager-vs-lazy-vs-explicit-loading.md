# Eager vs Lazy vs Explicit Loading in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `eager-loading`, `lazy-loading`, `explicit-loading`, `Include`, `navigation-properties`

## Question

> What are the three strategies for loading related data in EF Core — eager, lazy, and explicit? How do they differ, what are the trade-offs, and when should you choose each?

## Short Answer

EF Core offers three navigation-loading strategies. **Eager loading** (`Include`/`ThenInclude`) loads related data in the same SQL query — predictable but potentially over-fetching. **Lazy loading** (proxy or `ILazyLoader` injection) loads navigation properties on first access, transparent but prone to N+1 and disposed-context exceptions. **Explicit loading** (`entry.Reference().LoadAsync()`) gives you precise control: you load a specific navigation when you actually need it, making the SQL visible at the call site. For most ASP.NET Core scenarios, eager loading or projection is preferred; lazy loading is a trap.

## Detailed Explanation

### Eager Loading — `Include` / `ThenInclude`

Eager loading adds a SQL JOIN (or a second query with `AsSplitQuery`) to load related entities at query time:

```csharp
var orders = await db.Orders
    .Include(o => o.Customer)            // JOIN Customers
    .Include(o => o.Lines)               // JOIN OrderLines
        .ThenInclude(l => l.Product)     // JOIN Products (via OrderLines)
    .Where(o => o.Status == "Pending")
    .ToListAsync(ct);
```

**Generated SQL (single query mode):**
```sql
SELECT o.*, c.*, l.*, p.*
FROM Orders o
JOIN Customers c ON c.Id = o.CustomerId
LEFT JOIN OrderLines l ON l.OrderId = o.Id
LEFT JOIN Products p ON p.Id = l.ProductId
WHERE o.Status = 'Pending'
```

With multiple collection includes this produces a cartesian product. Use `AsSplitQuery()` for those cases ([See: split-queries.md](./split-queries.md)).

**Pros:** Predictable query count, works with async, no disposed-context risks.
**Cons:** Loads full entities even if you only need a few columns. Can over-fetch.

---

### Lazy Loading — Proxy or ILazyLoader

Lazy loading defers SQL to the first access of a navigation property. Two mechanisms:

**Option A — Proxy (NuGet: `Microsoft.EntityFrameworkCore.Proxies`):**

```csharp
// Setup
services.AddDbContext<AppDb>(opt =>
    opt.UseLazyLoadingProxies().UseSqlServer(conn));

// Domain entity must have virtual navigations
public class Order
{
    public virtual Customer Customer { get; set; } = null!;
    public virtual ICollection<OrderLine> Lines { get; set; } = [];
}

// Usage — transparently fires SQL on first access
var order = await db.Orders.FirstAsync(o => o.Id == 1, ct);
var name = order.Customer.Name;  // ← SQL fired here: SELECT * FROM Customers WHERE Id = @id
```

**Option B — `ILazyLoader` injection (no proxies, but still lazy):**

```csharp
public class Order(ILazyLoader lazyLoader)
{
    private Customer? _customer;
    public Customer Customer
    {
        get => lazyLoader.Load(this, ref _customer);
        set => _customer = value;
    }
}
```

**Pros:** Zero-ceremony access to navigations.
**Cons:**
- N+1 is invisible at the call site ([See: n-plus-one-problem.md](./n-plus-one-problem.md)).
- Requires `virtual` navigations — leaks ORM concern into the domain model.
- Fires synchronous queries (async lazy loading isn't supported by proxies).
- Breaks when the `DbContext` is disposed (serialization in controllers).

> **Warning:** Never use lazy loading with serializers (e.g., `System.Text.Json`, `Newtonsoft.Json`). The serializer accesses all public properties, triggering queries on a potentially disposed context.

---

### Explicit Loading — `entry.Reference().LoadAsync()`

Load a specific navigation on demand:

```csharp
var order = await db.Orders.FindAsync(id, ct);

// Load only when actually needed
await db.Entry(order).Reference(o => o.Customer).LoadAsync(ct);
await db.Entry(order).Collection(o => o.Lines).LoadAsync(ct);

// Can also filter a collection before loading
await db.Entry(order)
    .Collection(o => o.Lines)
    .Query()
    .Where(l => l.Quantity > 1)  // adds a WHERE clause to the load query
    .LoadAsync(ct);
```

**Pros:** SQL is at the call site (auditable, easy to understand). No N+1 if used in aggregate (not in a loop). Works async. No proxy requirement.
**Cons:** Verbose. Easy to forget a load. Not composable like LINQ queries.

---

### Comparison Table

| | Eager (`Include`) | Lazy (Proxy) | Explicit (`LoadAsync`) |
|--|------------------|--------------|-----------------------|
| SQL executed at | Query time | Property access | Explicit call |
| N+1 risk | Low | **High** | Medium (if in loop) |
| Async support | ✅ | ❌ (sync only) | ✅ |
| Column control | Limited (full entity) | Limited | Limited |
| Code readability | Declarative | Implicit | Verbose but explicit |
| Works with projections | Use `Select` instead | N/A | N/A |
| Best for | Known navigation needs upfront | Avoid in web apps | Conditional loading |

---

### Recommendation for ASP.NET Core

1. **Default to projections** (`Select` into DTOs) — no navigation loading needed, fetches minimum columns.
2. **Use `Include`** when you need the full entity graph and know which navigations are required.
3. **Use explicit loading** for large or conditional navigations that aren't always needed.
4. **Avoid lazy loading** in web applications entirely — N+1 and disposed-context issues outweigh the convenience.

## Code Example

```csharp
// Eager loading — load everything upfront
var invoice = await db.Invoices
    .Include(i => i.Customer)
    .Include(i => i.Lines).ThenInclude(l => l.Product)
    .AsNoTracking()
    .FirstAsync(i => i.Id == id, ct);

// Explicit loading — load customer only if invoice is unpaid
var invoice = await db.Invoices.FindAsync(id, ct)
    ?? throw new NotFoundException(id);

if (invoice.Status == InvoiceStatus.Unpaid)
{
    await db.Entry(invoice)
        .Reference(i => i.Customer)
        .LoadAsync(ct);
    // send reminder email using invoice.Customer
}

// Projection — best for read-only APIs
var dto = await db.Invoices
    .Where(i => i.Id == id)
    .Select(i => new InvoiceDto(
        i.Id,
        i.Customer.Name,           // translated to JOIN in SQL
        i.Lines.Sum(l => l.Total), // translated to SUM() in SQL
        i.Status))
    .FirstOrDefaultAsync(ct);
```

## Common Follow-up Questions

- How does `AsNoTracking` interact with eager vs lazy loading?
- Can explicit loading filter collection navigations? (Yes — via `.Query().Where(...)`)
- What happens when you call `Include` on a navigation that is already loaded in the identity map?
- Is there a global way to disable lazy loading without removing `UseLazyLoadingProxies`?
- How do split queries work when combined with `ThenInclude`?

## Common Mistakes / Pitfalls

- **Using lazy loading in serialization paths**: When `JsonSerializer` (or any serializer) traverses a lazy entity, it fires database queries on every property — potential N+1 + disposed-context crash.
- **Chaining `ThenInclude` on a reference navigation unnecessarily**: `Include(o => o.Customer).ThenInclude(c => c.Country)` loads the entire `Country` row. If you only need `Country.Name`, use a `Select` projection.
- **Explicit loading in a loop**: Calling `db.Entry(order).Reference(o => o.Customer).LoadAsync(ct)` inside a `foreach` is explicit N+1 — still 1 query per entity.
- **Forgetting `AsSplitQuery` when including multiple collections**: Two `Include` calls on collections generate a cartesian product that multiplies row counts multiplicatively, silently returning duplicated data.
- **Mixing lazy and eager**: Adding `Include(o => o.Customer)` while `UseLazyLoadingProxies` is enabled still works, but any navigation you *didn't* include will fire lazy queries later — giving you inconsistent loading patterns.

## References

- [Eager loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/eager)
- [Lazy loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/lazy)
- [Explicit loading — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/related-data/explicit)
- [See: n-plus-one-problem.md](./n-plus-one-problem.md)
- [See: split-queries.md](./split-queries.md)
