# CQRS Read Models

**Category:** Architecture / CQRS
**Difficulty:** 🟡 Middle
**Tags:** `CQRS`, `read-models`, `projections`, `denormalization`, `query-side`, `Dapper`, `eventual-consistency`

## Question

> What is a read model in CQRS? How do you design denormalized projections for the query side? How do you keep read models updated when the write side changes?

## Short Answer

A **read model** (also called a "projection" or "query model") is a data structure optimised for a specific read use case — often denormalized and shaped exactly like the response DTO. On a single database, a read model can be a DB view, a separate denormalized table, or just a Dapper query that joins and projects directly. On a separate read store (for scale), read models are updated by subscribing to domain events from the write side. The key property: read models are disposable and rebuilable — they're derived from the write side and can be regenerated from domain events.

## Detailed Explanation

### The Problem Read Models Solve

The write model (aggregate) is normalised for consistency — `Order` + `OrderLine` + `Customer` in separate tables. A typical query ("show order list with customer name, line count, total") would require a join across 3 tables. Doing this via the domain aggregate loads the full object graph with change tracking overhead.

A read model collapses this: a denormalized `OrderSummary` table (or view) has all the fields needed for the list query in one row, no join, no aggregate loading.

### Read Model Options on a Single Database

**Option 1: Direct Dapper query projection** (simplest)

```csharp
// No read model table — just a fast direct query, no EF Core change tracking
public class GetOrdersHandler(IDbConnectionFactory db)
    : IRequestHandler<GetOrdersQuery, PagedResult<OrderSummaryDto>>
{
    public async Task<PagedResult<OrderSummaryDto>> Handle(GetOrdersQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        var sql = """
            SELECT o.Id, o.Status, o.TotalAmount, o.TotalCurrency,
                   c.Name AS CustomerName, COUNT(l.Id) AS LineCount
            FROM Orders o
            JOIN Customers c ON o.CustomerId = c.Id
            LEFT JOIN OrderLines l ON l.OrderId = o.Id
            WHERE (@Status IS NULL OR o.Status = @Status)
            GROUP BY o.Id, o.Status, o.TotalAmount, o.TotalCurrency, c.Name
            ORDER BY o.CreatedAt DESC
            OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY
            """;
        var rows = await conn.QueryAsync<OrderSummaryDto>(sql,
            new { Status = q.StatusFilter, Offset = (q.Page - 1) * 20, PageSize = 20 });
        return new PagedResult<OrderSummaryDto>(rows.ToList(), q.Page);
    }
}
```

**Option 2: DB View** (fast reads, no application code to maintain)

```sql
-- Read model as a DB view
CREATE VIEW vw_OrderSummaries AS
SELECT o.Id, o.Status, o.TotalAmount, o.TotalCurrency,
       c.Name AS CustomerName, COUNT(l.Id) AS LineCount
FROM Orders o
JOIN Customers c ON o.CustomerId = c.Id
LEFT JOIN OrderLines l ON l.OrderId = o.Id
GROUP BY o.Id, o.Status, o.TotalAmount, o.TotalCurrency, c.Name;
```

**Option 3: Denormalized table updated by domain events** (best read performance)

```csharp
// Separate OrderSummaries table — updated when orders change
public class OrderSummary
{
    public int Id { get; set; }
    public string Status { get; set; } = "";
    public decimal TotalAmount { get; set; }
    public string CustomerName { get; set; } = "";
    public int LineCount { get; set; }
    public DateTime LastUpdated { get; set; }
}

// Updated by a domain event handler
public class UpdateOrderSummaryOnSubmitted(AppDbContext db)
    : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        var summary = await db.Set<OrderSummary>().FindAsync([e.OrderId.Value], ct);
        if (summary is null) return;
        summary.Status = "Submitted";
        summary.LastUpdated = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }
}
```

### Separate Read Store (Scale)

For high-scale systems, the read store is completely separate — Redis, Elasticsearch, Cosmos DB, or a read replica:

```
Write side (SQL Server):  Order aggregate → SaveChanges → OrderSubmittedEvent
                                                         ↓ (via Outbox / message bus)
Read side (Elasticsearch): OrderSummaryProjection handler → updates search index
```

```csharp
// Projection that updates Elasticsearch when orders change
public class OrderSearchProjection(IElasticClient elastic)
    : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        var doc = new OrderSearchDocument(
            Id: e.OrderId.Value,
            CustomerId: e.CustomerId.Value,
            Total: e.Total.Amount,
            Status: "Submitted",
            IndexedAt: DateTime.UtcNow);

        await elastic.IndexDocumentAsync(doc, ct);
    }
}
```

### Rebuilding Read Models

Because read models are derived from events/writes, they can be rebuilt:

```csharp
// Projection rebuild service — reprocesses all events
public class ProjectionRebuildService(
    IEventStore events,
    OrderSearchProjection projection)
{
    public async Task RebuildAsync(CancellationToken ct)
    {
        await foreach (var @event in events.GetAllEventsAsync(ct))
        {
            if (@event is OrderSubmittedEvent e)
                await projection.Handle(e, ct);
        }
    }
}
```

### Staleness and Eventual Consistency

In async read model updates, there's a window where the read model is stale:

```csharp
// After POST /orders, redirect to GET /orders/{id}
// The read model may not have the new order yet
// Options:
// 1. Return the write result directly (bypass read model for the immediate response)
// 2. Wait for projection (polling or WebSocket notification)
// 3. Accept that the list page may be slightly stale (1–2 seconds)
```

## Code Example

```csharp
// Query handler using AsNoTracking + direct projection — best balance of simplicity and performance
public class GetOrderDashboardHandler(AppDbContext db)
    : IRequestHandler<GetOrderDashboardQuery, OrderDashboardDto>
{
    public async Task<OrderDashboardDto> Handle(GetOrderDashboardQuery q, CancellationToken ct)
    {
        // Direct SQL projection — no aggregate loading, no change tracking
        var pending = await db.Orders
            .AsNoTracking()
            .Where(o => o.Status == OrderStatus.Pending)
            .Select(o => new OrderSummaryDto(o.Id, o.Total.Amount, o.Status.ToString(), o.CreatedAt))
            .OrderByDescending(o => o.CreatedAt)
            .Take(10)
            .ToListAsync(ct);

        var stats = await db.Orders
            .AsNoTracking()
            .GroupBy(_ => _.Status)
            .Select(g => new { Status = g.Key, Count = g.Count(), Total = g.Sum(o => o.Total.Amount) })
            .ToListAsync(ct);

        return new OrderDashboardDto(pending, stats.ToDictionary(s => s.Status.ToString(), s => s.Count));
    }
}
```

## Common Follow-up Questions

- When should a read model be updated synchronously vs asynchronously (via domain events)?
- How do you handle read model consistency when multiple domain events must be processed in order?
- How do you version read model schemas when the projection changes?
- What is the difference between a "projection" in Event Sourcing and a "read model" in CQRS?
- How do you test read model handlers that use Dapper or raw SQL?

## Common Mistakes / Pitfalls

- **Loading aggregates for read queries**: using the full EF Core aggregate (with `Include`) just to project to a DTO loads 10x more data than needed. Use direct SQL or `AsNoTracking + Select` projections.
- **Read model updating via polling**: updating a denormalized table by polling `Orders` for changes is fragile and slow. Use domain events or change data capture (CDC) instead.
- **Treating read models as permanent data**: read model data is derived and can be rebuilt. Treating it as a source of truth (writing directly to read model tables from business code) corrupts the separation.
- **Over-normalizing the read model**: a read model that requires joins to serve its intended query defeats the purpose. Denormalize what you need — duplicate data is expected and intentional on the read side.

## References

- [CQRS read models — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [CQRS documents — Martin Fowler](https://martinfowler.com/bliki/CQRS.html) (verify URL)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: projections-and-read-models.md](./projections-and-read-models.md)
- [See: cqrs-without-event-sourcing.md](./cqrs-without-event-sourcing.md)
