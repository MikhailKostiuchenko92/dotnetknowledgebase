# CQRS Consistency Challenges

**Category:** Architecture / CQRS
**Difficulty:** 🔴 Senior
**Tags:** `CQRS`, `eventual-consistency`, `stale-reads`, `read-after-write`, `projections`, `compensation`

## Question

> What are the consistency challenges introduced by CQRS, especially when using async read model updates? How do you handle stale reads after a command, and what strategies address read-after-write consistency?

## Short Answer

When the read model is updated asynchronously (via domain events after the write transaction commits), there's a window — typically milliseconds to seconds — where the read side shows stale data. This is **eventual consistency**. The main challenge: after a `POST /orders` the client immediately calls `GET /orders` and doesn't see the new order. Strategies: return enough data in the command response to avoid the immediate read, use optimistic UI updates, poll with a correlation ID, use a synchronous in-process projection for same-request consistency, or accept staleness with appropriate UX messaging.

## Detailed Explanation

### The Stale Read Problem

```
T=0: Client sends PlaceOrderCommand
T=1: Handler: Order.Create() → SaveChanges → OrderCreatedEvent → published to message bus
T=2: Client receives orderId=42
T=3: Client immediately calls GET /api/orders/42
T=4: ProjectionHandler hasn't processed OrderCreatedEvent yet
T=5: GET returns 404 — order exists in write DB but not in read model ← STALE READ
T=6: ProjectionHandler processes event, read model updated
T=7: GET /api/orders/42 returns the order ← eventually consistent
```

### Strategy 1: Return the Created Resource in the Command Response

The simplest fix — don't force a read-after-write:

```csharp
// Command returns enough data for the client to proceed
public class PlaceOrderHandler(IOrderRepository orders)
    : IRequestHandler<PlaceOrderCommand, PlaceOrderResult>
{
    public async Task<PlaceOrderResult> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        // ... add lines ...
        order.Submit();
        await orders.AddAsync(order, ct);
        return new PlaceOrderResult(
            OrderId: order.Id.Value,
            Status: order.Status.ToString(),
            Total: order.Total.Amount); // ← include key fields so client doesn't need to re-query
    }
}
```

### Strategy 2: Synchronous In-Process Projection

For same-request consistency, update the read model synchronously as part of the command pipeline:

```csharp
// Synchronous projection handler — runs in the same transaction
public class SyncOrderProjectionHandler(AppDbContext db)
    : INotificationHandler<OrderCreatedEvent>
{
    public async Task Handle(OrderCreatedEvent e, CancellationToken ct)
    {
        // Runs in the SaveChanges interceptor BEFORE the transaction is committed
        // Ensures read model is consistent with write model in the same transaction
        db.Set<OrderSummary>().Add(new OrderSummary
        {
            Id = e.OrderId.Value,
            Status = "Pending",
            TotalAmount = e.Total.Amount,
            CreatedAt = e.OccurredAt
        });
        // No extra SaveChanges needed — runs inside the same EF Core context
    }
}
```

### Strategy 3: Read-After-Write Consistency with Correlation IDs

For async projections, track whether the read model has caught up:

```csharp
// Command returns a correlation ID
public record PlaceOrderResult(int OrderId, Guid EventCorrelationId);

// Client polls until the read model includes this correlation ID
// GET /api/orders/42?correlationId={id} — returns 202 Accepted if not yet ready

[HttpGet("{id}")]
public async Task<IActionResult> Get(int id, Guid? correlationId, CancellationToken ct)
{
    var order = await _sender.Send(new GetOrderByIdQuery(id, correlationId), ct);
    if (order is null && correlationId.HasValue)
        return Accepted(new { message = "Order is being processed. Retry shortly." });
    return order is null ? NotFound() : Ok(order);
}
```

### Strategy 4: Optimistic UI Updates

Accept that the server may return stale data and use client-side optimistic state:

```javascript
// Client adds the order to local state immediately after the command response
// Even if the server read model is stale, the user sees the new order
store.dispatch(addOrderLocally(createOrderResult));
// Later, on next page load or after polling, sync with actual server state
```

### Strategy 5: Versioned Consistency Check

Track a version or timestamp on the read model and ensure clients only read "caught up" data:

```csharp
// Read model includes a version that maps to the write model version
public class OrderSummary
{
    public int Id { get; set; }
    public long WriteModelVersion { get; set; } // ← incremented on each write
    // ...
}

// Handler returns both the result and the write model version
// Client waits until the read model version >= write model version before accepting the read
```

### When to Accept Eventual Consistency

Not every use case needs read-after-write consistency:

| Scenario | Acceptable? |
|----------|-------------|
| "View my new order" immediately after placing | Often not — use Strategy 1 or 2 |
| "See dashboard statistics" (order count, total) | Yes — slight staleness acceptable |
| "Check if product is in stock" | Depends on business domain |
| "Payment status" | No — financial data must be accurate |
| "Browse product catalog" | Yes — seconds of staleness acceptable |

## Code Example

```csharp
// Strategy 1 + 2 combined: command returns resource + sync read model update
public class PlaceOrderHandler(
    IOrderRepository orders,
    AppDbContext db) : IRequestHandler<PlaceOrderCommand, PlaceOrderResult>
{
    public async Task<PlaceOrderResult> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        order.Submit();
        await orders.AddAsync(order, ct);

        // Synchronously update read model in the same transaction
        db.Set<OrderSummary>().Add(new OrderSummary
        {
            Id = order.Id.Value,
            Status = order.Status.ToString(),
            TotalAmount = order.Total.Amount,
            CreatedAt = DateTime.UtcNow
        });

        await db.SaveChangesAsync(ct);

        return new PlaceOrderResult(
            OrderId: order.Id.Value,
            Status: order.Status.ToString(),
            Total: order.Total.Amount);
        // ← client can now call GET /orders/{id} and find the order in both write and read DB
    }
}
```

## Common Follow-up Questions

- How do you handle eventual consistency in a mobile app where the user has a spotty connection?
- What is the "write-behind cache" pattern, and how does it relate to CQRS consistency?
- How do you implement compensating transactions when a saga step fails and the read model is already updated?
- How do you test eventually consistent systems — what does "test passes" mean when the projection may lag?
- Is strong consistency always better than eventual consistency, and why?

## Common Mistakes / Pitfalls

- **Assuming read-after-write is always needed**: many operations (background analytics, dashboards, reports) work perfectly with eventual consistency. Prematurely adding synchronous projection overhead for all commands is waste.
- **Synchronous projection in a separate transaction from the write**: if the read model update is a separate `SaveChangesAsync`, a failure between the two leaves the write committed but the read model stale permanently (not eventually consistent — just wrong).
- **Not documenting the consistency model to API consumers**: API clients need to know whether a `POST` response guarantees immediate `GET` consistency. Document this in OpenAPI descriptions or API style guides.
- **Building complex compensating transactions**: over-engineering compensation mechanisms for eventual consistency issues that could be solved by returning the command result directly.

## References

- [CQRS eventual consistency — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [CAP theorem and consistency trade-offs — Martin Kleppmann DDIA](https://dataintensive.net/) (verify URL)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: cqrs-read-models.md](./cqrs-read-models.md)
- [See: outbox-pattern-architecture.md](./outbox-pattern-architecture.md)
