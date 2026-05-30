# CQRS Without Event Sourcing

**Category:** Architecture / CQRS
**Difficulty:** 🟡 Middle
**Tags:** `CQRS`, `relational-database`, `single-database`, `read-write-separation`, `EF-Core`, `Dapper`

## Question

> How do you implement CQRS on a single relational database without Event Sourcing? What are the practical patterns for separating read and write models when both sides share the same SQL Server database?

## Short Answer

CQRS doesn't require Event Sourcing or separate databases. On a single relational database, the separation is at the **model level**: the write side uses EF Core tracked entities with domain aggregates; the read side uses `AsNoTracking` + DTO projections or Dapper queries bypassing the aggregate entirely. The write side commits, then either synchronously updates a denormalized read view, or relies on the read side querying the same tables with optimized SQL projections. The key benefit: write handlers stay clean (domain rules only), read handlers stay fast (no aggregate loading, direct SQL).

## Detailed Explanation

### The Practical Separation

```
Single SQL Server database

Write side (EF Core with tracking):           Read side (Dapper or AsNoTracking):
  PlaceOrderCommand                             GetOrdersQuery
    → Load Order aggregate (tracked)              → Dapper: SELECT + JOIN → DTO
    → order.Submit() (domain logic)               → AsNoTracking + Select projection
    → SaveChangesAsync                            → DB view
    → (indexes, FK constraints)
```

Both sides read from and write to the **same tables**. The "separation" is in the application code, not the database.

### Option 1: EF Core `AsNoTracking` with DTO Projection

The simplest read-side approach — no extra infrastructure:

```csharp
// Write side: uses tracked EF Core entities
public class SubmitOrderHandler(AppDbContext db) : IRequestHandler<SubmitOrderCommand>
{
    public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
    {
        var order = await db.Orders
            .Include(o => o.Lines)
            .FirstAsync(o => o.Id == cmd.OrderId, ct);
        order.Submit();  // ← tracked, domain logic enforced
        await db.SaveChangesAsync(ct);
    }
}

// Read side: no tracking, direct DTO projection
public class GetOrdersHandler(AppDbContext db)
    : IRequestHandler<GetOrdersQuery, PagedResult<OrderSummaryDto>>
{
    public async Task<PagedResult<OrderSummaryDto>> Handle(GetOrdersQuery q, CancellationToken ct)
        => new PagedResult<OrderSummaryDto>(
            await db.Orders
                .AsNoTracking()
                .Where(o => q.CustomerId == null || o.CustomerId == q.CustomerId)
                .Select(o => new OrderSummaryDto(
                    o.Id, o.Status.ToString(), o.Total.Amount, o.CreatedAt))
                .OrderByDescending(o => o.CreatedAt)
                .Skip((q.Page - 1) * q.PageSize).Take(q.PageSize)
                .ToListAsync(ct),
            q.Page);
}
```

### Option 2: Dapper for Read Side, EF Core for Write Side

Use the right tool for each job:

```csharp
// Read side: Dapper — direct SQL, fastest possible for complex projections
public class GetOrderDashboardHandler(IDbConnectionFactory factory)
    : IRequestHandler<GetOrderDashboardQuery, OrderDashboardDto>
{
    public async Task<OrderDashboardDto> Handle(GetOrderDashboardQuery q, CancellationToken ct)
    {
        using var conn = factory.CreateConnection();
        var rows = await conn.QueryAsync<OrderSummaryDto>("""
            SELECT o.Id, o.Status, o.TotalAmount,
                   c.Name AS CustomerName,
                   COUNT(l.Id) AS LineCount
            FROM Orders o
            JOIN Customers c ON o.CustomerId = c.Id
            LEFT JOIN OrderLines l ON l.OrderId = o.Id
            GROUP BY o.Id, o.Status, o.TotalAmount, c.Name
            ORDER BY o.Id DESC
            OFFSET @Offset ROWS FETCH NEXT 20 ROWS ONLY
            """, new { Offset = (q.Page - 1) * 20 });
        return new OrderDashboardDto(rows.ToList());
    }
}

// Write side: EF Core — domain aggregate, tracked, business rules
public class PlaceOrderHandler(IOrderRepository orders, IUnitOfWork uow)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        foreach (var line in cmd.Lines)
            order.AddLine(new ProductId(line.ProductId), line.Quantity, new Money(line.Price));
        order.Submit();
        await orders.AddAsync(order, ct);
        await uow.SaveChangesAsync(ct);
        return order.Id.Value;
    }
}
```

### Option 3: DB Views for Read Models

Pre-computed DB views eliminate complex join logic from application code:

```sql
-- ReadModels/vw_OrderSummaries.sql (committed to source control)
CREATE OR ALTER VIEW vw_OrderSummaries AS
SELECT o.Id, o.Status, o.TotalAmount, o.TotalCurrency,
       c.Name AS CustomerName, COUNT(l.Id) AS LineCount,
       o.CreatedAt, o.UpdatedAt
FROM Orders o
JOIN Customers c ON o.CustomerId = c.Id
LEFT JOIN OrderLines l ON l.OrderId = o.Id
GROUP BY o.Id, o.Status, o.TotalAmount, o.TotalCurrency, c.Name, o.CreatedAt, o.UpdatedAt;
```

```csharp
// Map the view in EF Core (keyless entity = no tracking, no CUD)
modelBuilder.Entity<OrderSummaryView>()
    .HasNoKey()
    .ToView("vw_OrderSummaries");

// Query via EF Core (or Dapper)
public async Task<List<OrderSummaryView>> Handle(GetOrdersQuery q, CancellationToken ct)
    => await db.Set<OrderSummaryView>().ToListAsync(ct);
```

### When Is a Separate Read DB Needed?

For a single-instance SQL Server database:
- Separate read/write models **within the same DB** handles most loads
- When read query load overwhelms the single DB: add a **read replica** (Azure SQL read scale-out, AlwaysOn secondary)
- Only for extreme scale or geo-distribution: maintain a completely separate read store (Cosmos, Elasticsearch)

## Code Example

```csharp
// Registration: separate DbContext registrations for read and write
// Write context: change tracking, domain entities
services.AddDbContext<WriteDbContext>(o => o.UseSqlServer(conn));

// Read context: no tracking by default, optimised for queries
services.AddDbContext<ReadDbContext>(o =>
    o.UseSqlServer(conn,
        sql => sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery))
    // .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking) — set globally
);

// Or: use the same DbContext with AsNoTracking on all read queries
services.AddDbContext<AppDbContext>(o => o.UseSqlServer(conn));
```

## Common Follow-up Questions

- When does the read/write separation on a single database become a read replica setup?
- How do you handle transactions that involve both the write model and a denormalized read table?
- What is the performance impact of using EF Core `AsNoTracking` vs Dapper for read queries?
- How do you implement eventual consistency when the read model is a denormalized table updated via domain events?
- How do you measure whether CQRS complexity is paying off in a given application?

## Common Mistakes / Pitfalls

- **Using tracked queries for read operations**: EF Core loads change tracking overhead for every tracked entity — even for data that will only be read. Always use `AsNoTracking()` or Dapper for query-side handlers.
- **Returning the write model DTO from a command**: `PlaceOrderHandler` returning a full `OrderDto` merges command and query concerns — the handler must now also query the read model.
- **The "shared DbContext" god context**: a single `AppDbContext` with 50 `DbSet<T>` properties becomes a maintenance problem. Split into focused contexts (WriteDbContext, ReadDbContext) for large solutions.
- **Circular CQRS**: a query handler that calls a command (side effect) or a command handler that issues a query and returns its result — this breaks the clean separation.

## References

- [CQRS on a single database — Martin Fowler](https://martinfowler.com/bliki/CQRS.html) (verify URL)
- [CQRS with EF Core — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/apply-simplified-microservice-cqrs-ddd-patterns)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: cqrs-read-models.md](./cqrs-read-models.md)
- [See: cqrs-write-models.md](./cqrs-write-models.md)
