# Projections and Select in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `projections`, `Select`, `DTO`, `AutoMapper`, `ProjectTo`, `performance`

## Question

> Why are projections important in EF Core, and how does `Select` reduce the amount of data fetched from the database? How does `AutoMapper`'s `ProjectTo<T>` work, and when should you prefer manual projections?

## Short Answer

A projection is a `Select` that maps query results to a shape you actually need — a DTO, an anonymous type, or a smaller view model — instead of loading full entity objects. Projections are crucial for performance: they reduce the columns fetched (`SELECT a, b` instead of `SELECT *`), avoid change tracker overhead, and let EF Core generate focused SQL. `AutoMapper.ProjectTo<T>()` automatically generates the `Select` expression from your map configuration, removing repetitive projection code. Manual projections are faster to compile and easier to debug but verbose for complex models.

## Detailed Explanation

### Why Full Entity Loading Is Often Wasteful

When you call `db.Orders.ToListAsync()`, EF Core:
1. Generates `SELECT * FROM Orders` (all columns).
2. Materializes `Order` objects with all properties.
3. Registers all entities in the change tracker.

If you only need `Id` and `Reference` for a list page, you've loaded 20 extra columns and paid change-tracker overhead for nothing.

### Manual Projection with `Select`

```csharp
// ❌ Over-fetches — loads full Order entity (all columns + change tracking)
var orders = await db.Orders
    .Where(o => o.Status == "Pending")
    .ToListAsync(ct);

var dtos = orders.Select(o => new OrderListItemDto(o.Id, o.Reference, o.Total));

// ✅ Projection — SQL: SELECT Id, Reference, Total FROM Orders WHERE Status='Pending'
var dtos = await db.Orders
    .Where(o => o.Status == "Pending")
    .Select(o => new OrderListItemDto(o.Id, o.Reference, o.Total))
    .ToListAsync(ct);
```

The second query fetches only 3 columns, skips the change tracker, and may be significantly faster on wide tables.

### Projecting Across Navigation Properties (No `Include` Needed)

When you project to a DTO that references a navigation property, EF Core **automatically JOINs** the related table — you don't need `Include`:

```csharp
// No .Include(o => o.Customer) needed — EF Core generates the JOIN automatically
var dtos = await db.Orders
    .Select(o => new OrderDetailDto(
        o.Id,
        o.Reference,
        o.Customer.Name,      // ← EF Core: LEFT JOIN Customers ON o.CustomerId = Customers.Id
        o.Customer.Email))
    .ToListAsync(ct);
```

> **Tip:** Using `Include` with a projection (`Select`) is redundant — EF Core ignores `Include` when you project. Only use `Include` when materializing full entity objects.

### Nested Projections

```csharp
var result = await db.Orders
    .Select(o => new OrderWithLinesDto(
        o.Id,
        o.Reference,
        o.Lines.Select(l => new OrderLineDto(l.ProductId, l.Quantity, l.UnitPrice)).ToList()))
    .ToListAsync(ct);
```

EF Core translates the nested `Select` to a subquery or JOIN depending on the provider. This avoids the cartesian explosion of `Include` on collections — [See: split-queries.md](./split-queries.md).

### Anonymous Types for One-Off Queries

For internal query results not worth a named DTO:

```csharp
var report = await db.Orders
    .Where(o => o.CreatedAt.Year == 2024)
    .GroupBy(o => o.Status)
    .Select(g => new { Status = g.Key, Count = g.Count(), Revenue = g.Sum(o => o.Total) })
    .ToListAsync(ct);
```

### `AutoMapper.ProjectTo<T>()`

`ProjectTo<T>` translates an AutoMapper mapping configuration into a LINQ `Select` expression at query build time:

```csharp
// AutoMapper profile
CreateMap<Order, OrderDto>()
    .ForMember(d => d.CustomerName, opt => opt.MapFrom(src => src.Customer.Name));

// Usage — generates exactly the same SQL as a manual Select
var dtos = await db.Orders
    .Where(o => o.Status == "Pending")
    .ProjectTo<OrderDto>(_mapper.ConfigurationProvider)
    .ToListAsync(ct);
```

AutoMapper inspects the map at startup and builds an expression tree equivalent to:

```csharp
.Select(o => new OrderDto
{
    Id           = o.Id,
    Reference    = o.Reference,
    CustomerName = o.Customer.Name,
    // ... all mapped members
})
```

**`ProjectTo<T>` vs `Map<T>` after `ToList`:**

| | `ProjectTo<T>` | `Map<T>` after `ToList` |
|--|----------------|------------------------|
| SQL columns | Only mapped columns | All columns (SELECT *) |
| Change tracking | No (projection bypasses it) | Yes (entities tracked) |
| Code | One line | Two steps |
| Debuggability | Harder (expression tree) | Easier (explicit code) |
| Custom logic in map | Limited (must be translatable) | Full C# |

### When to Use Manual Projections vs `ProjectTo<T>`

- **Manual projection**: when the mapping is complex, contains non-translatable C# logic, or the DTO shape is significantly different from the entity.
- **`ProjectTo<T>`**: when you have many similar read DTOs and want to avoid repetitive `Select` boilerplate; works best for straightforward property-to-property mappings.

## Code Example

```csharp
// Full projection example with pagination
public async Task<PagedResult<OrderSummaryDto>> GetOrderSummariesAsync(
    int page, int pageSize, CancellationToken ct)
{
    var query = db.Orders
        .Where(o => !o.IsDeleted)
        .OrderByDescending(o => o.CreatedAt);

    var total = await query.CountAsync(ct);

    // SQL: SELECT o.Id, o.Reference, o.CreatedAt, c.Name, SUM(l.UnitPrice * l.Qty) AS Total
    //      FROM Orders o
    //      JOIN Customers c ON o.CustomerId = c.Id
    //      LEFT JOIN OrderLines l ON l.OrderId = o.Id
    //      WHERE NOT o.IsDeleted
    //      GROUP BY o.Id, o.Reference, o.CreatedAt, c.Name
    //      ORDER BY o.CreatedAt DESC
    //      OFFSET x ROWS FETCH NEXT y ROWS ONLY
    var items = await query
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .Select(o => new OrderSummaryDto(
            o.Id,
            o.Reference,
            o.CreatedAt,
            o.Customer.Name,
            o.Lines.Sum(l => l.UnitPrice * l.Quantity)))  // aggregated in SQL
        .ToListAsync(ct);

    return new PagedResult<OrderSummaryDto>(items, total, page, pageSize);
}
```

## Common Follow-up Questions

- Why does EF Core ignore `Include` calls when you also call `Select`?
- How does `ProjectTo<T>` handle conditional mappings (`Condition`, `NullSubstitute`) in the expression tree?
- What happens when you project to a DTO that has a property EF Core can't translate (e.g., a computed method call)?
- Is there a performance difference between projecting to a named DTO class vs an anonymous type?
- How do you handle nullable navigation properties in projections to avoid `NullReferenceException` in the generated SQL?

## Common Mistakes / Pitfalls

- **`Include` + `Select` is redundant**: `Include` is ignored when you project with `Select`. The navigation will still be available because EF Core generates the appropriate JOIN in the projection. Calling both wastes model-building overhead.
- **Projecting after `ToList()`**: `db.Orders.ToList().Select(o => new Dto(...))` loads all columns and all entities into memory first. The `Select` to a DTO happens in C#, not SQL.
- **Non-translatable logic in `Select`**: Calling a helper method (e.g., `FormatCurrency(o.Total)`) inside a `Select` that isn't translatable causes client evaluation or an exception.
- **`ProjectTo<T>` with complex custom resolvers**: AutoMapper resolvers using `IValueResolver` can't be expressed as SQL — they silently fall back to client evaluation or throw.
- **Projecting partial-collection navigations**: `o.Lines.First().UnitPrice` in a `Select` is often not translatable (correlated subquery) — use `.Select(l => l.UnitPrice).FirstOrDefault()` or a nested projection.

## References

- [Projections — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/projections)
- [AutoMapper ProjectTo — AutoMapper docs](https://docs.automapper.org/en/stable/Queryable-Extensions.html)
- [See: iqueryable-vs-ienumerable.md](./iqueryable-vs-ienumerable.md)
- [See: n-plus-one-problem.md](./n-plus-one-problem.md)
