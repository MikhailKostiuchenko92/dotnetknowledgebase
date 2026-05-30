# CQRS and Read Models

**Category:** System Design / Performance
**Difficulty:** Senior
**Tags:** `cqrs`, `read-model`, `projection`, `eventual-consistency`, `dapper`, `ef-core`

## Question

> What is CQRS? How does separating reads from writes improve scalability? What is a read model (projection) and how do you keep it up to date? What are the consistency trade-offs?

- When should you use full CQRS vs a simple query/command split?
- How do you rebuild a read model without downtime?

## Short Answer

CQRS (Command Query Responsibility Segregation) separates write operations (commands that mutate state) from read operations (queries that return data), allowing each side to be optimised independently. The write model enforces business invariants using rich domain objects and a normalised database; the read model is a denormalised, query-optimised projection rebuilt from domain events or CDC. This enables read replicas, different storage technologies per side, and independent scaling. The trade-off is **eventual consistency** — the read model lags slightly behind the write model.

## Detailed Explanation

### Why Separate Reads from Writes?

In a typical application, reads vastly outnumber writes (often 10:1 or 100:1), yet both share the same data model — one that must satisfy both:
- Write invariants (transactions, validation, referential integrity)
- Read requirements (joins, aggregations, projections for specific screens)

This forces compromises: the domain model is polluted with lazy-load navigation properties; queries are complex JOINs on a normalised schema; or the schema is denormalised for reads but makes writes awkward.

CQRS resolves this by having **two separate models**:

| Side | Purpose | Storage | Technology |
|------|---------|---------|-----------|
| **Command (write)** | Enforce invariants, persist events | Normalised relational or event store | EF Core, Marten, EventStoreDB |
| **Query (read)** | Return data for UI, reports | Denormalised, query-optimised | Dapper, Redis, Elasticsearch |

### Light CQRS (In-Process, Same DB)

You don't need event sourcing or separate databases to apply CQRS. The simplest form is just structuring code to separate commands from queries:

```
Commands → Domain Model (EF Core) → Normalised DB
Queries  → Thin Query Layer (Dapper) → Read Replicas / Same DB
```

Benefits: simpler queries, fewer joins, smaller query result sets, read replicas offload write DB.

### Full CQRS (Separate Read Models)

The write model emits domain events → a projection builds a denormalised read model:

```
Command → Domain Service → Write DB (normalised)
                        → Domain Event emitted
                              ↓
                     Event Handler / Projection
                              ↓
                     Read DB (denormalised — optimised for UI)
                              ↓
                     Query Handler → returns DTO directly
```

### Read Model (Projection) Design

A projection is a purpose-built view of data for a specific query. Example: order list view:

```sql
-- Write model: normalised
orders(id, customer_id, status, created_at)
order_lines(id, order_id, product_id, quantity, unit_price_cents)
customers(id, name, email)
products(id, name, sku)

-- Read model: denormalised projection for "order list" screen
CREATE TABLE order_list_view (
    order_id        UUID PRIMARY KEY,
    customer_name   TEXT,
    status          TEXT,
    item_count      INT,
    total_cents     BIGINT,
    created_at      TIMESTAMPTZ
);
```

The projection handler populates this on every relevant domain event:

```csharp
public sealed class OrderListProjection(IOrderListRepository repo) :
    IEventHandler<OrderPlaced>,
    IEventHandler<OrderStatusChanged>
{
    public async Task HandleAsync(OrderPlaced evt, CancellationToken ct) =>
        await repo.UpsertAsync(new OrderListEntry
        {
            OrderId      = evt.OrderId,
            CustomerName = evt.CustomerName,
            Status       = "Pending",
            ItemCount    = evt.Items.Count,
            TotalCents   = evt.Items.Sum(i => i.Quantity * i.UnitPriceCents),
            CreatedAt    = evt.OccurredAt,
        }, ct);

    public async Task HandleAsync(OrderStatusChanged evt, CancellationToken ct) =>
        await repo.UpdateStatusAsync(evt.OrderId, evt.NewStatus, ct);
}
```

### Consistency Model

The read model is **eventually consistent** with the write model:
- Event emitted → projection handler processes → read model updated.
- Lag is typically milliseconds to seconds.
- During lag: a user places an order, refreshes the page immediately, and might not see it in the list.

**Mitigations**:
1. **Read-your-writes**: after a command, the client waits for a confirmation (e.g., server-sent event) before redirecting to the list.
2. **Version/ETag in response**: client knows the order was created at version X; query side returns HTTP 202 Accepted until projection catches up.
3. **Write-through to read model**: update read model synchronously in the same transaction (defeats the purpose of separation but guarantees consistency for simple cases).

### Rebuilding a Read Model

When the projection logic changes or a bug is fixed, you need to rebuild from scratch:

1. **Create a new read model table** (`order_list_view_v2`).
2. **Replay all events** from the event log / Kafka topic from the beginning.
3. **Wait until the projection catches up** to the current event position.
4. **Atomic swap**: update the query layer to read from `v2`; drop `v1`.

This rebuild can be done in background while `v1` serves live traffic — zero downtime.

```csharp
// Replay projection from event store (Marten example)
await using var session = store.OpenSession();
var events = await session.Events.QueryAllRawEvents()
    .OrderBy(e => e.Sequence)
    .ToListAsync(ct);

foreach (var ev in events)
{
    await dispatcher.DispatchAsync(ev.Data, ct);
    // Checkpoint every 1000 events to resume on crash
    if (ev.Sequence % 1000 == 0)
        await checkpointStore.SaveAsync(ev.Sequence, ct);
}
```

### MediatR-based CQRS in .NET

MediatR is the standard .NET library for implementing command/query dispatch:

```csharp
// Command
public record PlaceOrderCommand(Guid CustomerId, IList<OrderLine> Lines)
    : IRequest<Guid>;

public sealed class PlaceOrderHandler(IOrderRepository orders) :
    IRequestHandler<PlaceOrderCommand, Guid>
{
    public async Task<Guid> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Place(cmd.CustomerId, cmd.Lines);
        await orders.SaveAsync(order, ct);
        return order.Id;
    }
}

// Query — uses Dapper directly, no domain model
public record GetOrderListQuery(Guid CustomerId, int Page) : IRequest<IList<OrderListDto>>;

public sealed class GetOrderListHandler(IDbConnection db) :
    IRequestHandler<GetOrderListQuery, IList<OrderListDto>>
{
    public async Task<IList<OrderListDto>> Handle(GetOrderListQuery q, CancellationToken ct)
    {
        return (await db.QueryAsync<OrderListDto>("""
            SELECT order_id, customer_name, status, item_count, total_cents, created_at
            FROM order_list_view
            WHERE customer_id = @CustomerId
            ORDER BY created_at DESC
            LIMIT 20 OFFSET @Offset
            """, new { q.CustomerId, Offset = q.Page * 20 })).ToList();
    }
}
```

> **Warning:** CQRS adds architectural complexity. A CRUD service with `IQueryable<T>` is often the right choice for simple domains. Apply CQRS where the read and write models genuinely diverge — high-volume reads, complex aggregations, or event sourcing — not as a default pattern for everything.

## Common Follow-up Questions

- What is event sourcing and how does it complement CQRS?
- How do you handle the case where a command must immediately return data from the read model (e.g., "order created, show me the order")?
- What happens to in-flight queries when you rebuild a read model?
- How do you handle schema evolution in a projection — if an event's shape changes, how do you replay old events?
- How does CQRS interact with distributed transactions across service boundaries?

## Common Mistakes / Pitfalls

- **CQRS everywhere**: applying CQRS to simple CRUD (create/read/update/delete with no domain logic) adds overhead with no benefit.
- **Updating the read model in the same HTTP request synchronously**: defeats the scalability purpose; emit an event and let the projection handle it asynchronously.
- **No projection checkpoint**: replaying millions of events without checkpointing means a crash restarts from the beginning; save position every N events.
- **Using EF Core for the query side**: EF Core navigates complex object graphs; for the query side, use Dapper or `IQueryable` projections directly to DTOs — no need to load full domain objects.
- **Not handling out-of-order events**: in distributed systems, events can arrive out of order; projections must be idempotent and handle late-arriving events.

## References

- [CQRS pattern — Microsoft Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [CQRS and Event Sourcing — Greg Young (video)](https://www.youtube.com/watch?v=8JKjvY4etTY) (verify URL)
- [MediatR — GitHub](https://github.com/jbogard/MediatR)
- [Marten — Document DB + Event Sourcing for .NET](https://martendb.io/)
- [See: event-sourcing-vs-crud.md](./event-sourcing-vs-crud.md)
- [See: event-driven-architecture.md](./event-driven-architecture.md)
