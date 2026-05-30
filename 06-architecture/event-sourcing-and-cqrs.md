# Event Sourcing and CQRS

**Category:** Architecture / Event Sourcing
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `CQRS`, `complementary`, `independent`, `read-models`, `write-models`, `combination`

## Question

> What is the relationship between Event Sourcing and CQRS? Are they the same thing? Can you use one without the other, and when does combining them make sense?

## Short Answer

Event Sourcing and CQRS are **complementary but independent** patterns. CQRS separates read and write models at the application layer — you can do it with a traditional relational database. Event Sourcing is a storage strategy — you can use it with or without CQRS. They combine naturally: the Event Sourcing write side stores events in an event store; CQRS keeps queries out of the aggregate entirely; domain events from the write side drive projection handlers that maintain read models. But this combination carries the complexity of both patterns — use it only when both are individually justified.

## Detailed Explanation

### CQRS Without Event Sourcing

The most common combination — separate read/write code paths, single relational database:

```
Write side:          PlaceOrderCommand → Order aggregate (EF Core tracked) → SaveChanges
Read side:           GetOrdersQuery → Dapper direct SQL → OrderSummaryDto

No event store. No event replay.
The "event sourcing part" is just domain events published in-process after SaveChanges.
```

This is what most .NET DDD applications actually do. See [cqrs-without-event-sourcing.md](./cqrs-without-event-sourcing.md).

### Event Sourcing Without CQRS

Event Sourcing only affects how state is stored — you can query the write model (the aggregate) directly:

```csharp
// Event Sourcing without CQRS — load aggregate and return a DTO
public async Task<OrderDto> GetOrderAsync(int orderId, CancellationToken ct)
{
    // Event Sourcing write model used for reads
    var events = await store.ReadStreamAsync($"order-{orderId}", ct: ct);
    var order = Order.LoadFrom(events.Select(e => e.Event));
    return new OrderDto(order.Id.Value, order.Status.ToString(), order.Total.Amount);
}
```

This works but is inefficient for list queries — you can't do `SELECT * FROM Orders WHERE Status = 'Pending'` without projections.

### CQRS + Event Sourcing Together (Classic Pattern)

The combination is most powerful for complex, high-audit domains:

```
Write side (Event Sourcing):
  PlaceOrderCommand
    → PlaceOrderHandler
      → IEventStore.ReadStreamAsync("order-42") → replay events → Order aggregate
      → order.Submit()  → raises OrderSubmittedEvent
      → IEventStore.AppendToStreamAsync("order-42", expectedVersion, [OrderSubmittedEvent])
                                ↓
Read side (CQRS projections):
  Background worker reads new events from global position
    → OrderSubmittedEvent → OrderSummaryProjection → UPDATE OrderSummaries SET Status='Submitted'
    → OrderSummaryProjection → ElasticSearch.IndexDocumentAsync(...)
    
Query side:
  GetOrdersQuery → Dapper → SELECT * FROM OrderSummaries → OrderSummaryDto
  SearchOrdersQuery → ElasticClient.SearchAsync → OrderSearchDto
```

### The "ES+CQRS Tax"

Using both patterns together means carrying the complexity cost of both:

| | CQRS alone | ES alone | ES + CQRS |
|--|-----------|---------|----------|
| **Complexity** | Medium | High | Very high |
| **Infrastructure** | Same DB | Event store + read DB | Event store + read DB + projection workers |
| **Developer ramp-up** | 1 week | 2+ weeks | 4+ weeks |
| **Justified when** | Rich domain, query perf | Audit, temporal queries | Both requirements exist |

### Decision Framework

```
Does your domain require a built-in audit trail and temporal queries?
  YES → Consider Event Sourcing
  NO  → Skip Event Sourcing

Does your domain have significant read/write asymmetry (complex queries, heavy load)?
  YES → Consider CQRS read model separation
  NO  → Single model or simple projections are enough

Both YES → ES + CQRS may be appropriate
One YES → Use only that pattern
Both NO  → Use neither — traditional CRUD is fine
```

## Code Example

```csharp
// Using both: EventStoreDB write side + Dapper read side
// The combination: writes go to event store; queries hit a SQL projection table

// Write side: pure event sourcing via EventStoreDB
public class OrderCommandHandler(EventStoreClient esdb) : IRequestHandler<SubmitOrderCommand>
{
    public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
    {
        // Load aggregate from events
        var events = await ReadStreamAsync(esdb, $"order-{cmd.OrderId}", ct);
        var order = Order.LoadFrom(events);
        order.Submit();

        // Append new events
        await esdb.AppendToStreamAsync($"order-{cmd.OrderId}",
            StreamRevision.FromInt64(order.Version - order.GetNewEvents().Count),
            order.GetNewEvents().Select(e => Serialize(e)), ct);
    }
}

// Read side: Dapper against SQL projection table (no event store involved)
public class GetOrdersHandler(IDbConnectionFactory db)
    : IRequestHandler<GetOrdersQuery, List<OrderSummaryDto>>
{
    public async Task<List<OrderSummaryDto>> Handle(GetOrdersQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        return (await conn.QueryAsync<OrderSummaryDto>(
            "SELECT Id, Status, TotalAmount, CustomerName FROM OrderSummaries ORDER BY CreatedAt DESC"
        )).ToList();
    }
}
```

## Common Follow-up Questions

- What is the "event sourcing without CQRS" smell — when does it indicate a design problem?
- How do you test an ES+CQRS system end-to-end?
- Can you add CQRS projections to an existing Event Sourcing system after launch?
- What is a process manager (saga) in the context of ES+CQRS?
- How do you migrate from CQRS with a relational DB to CQRS with an event store?

## Common Mistakes / Pitfalls

- **Treating ES and CQRS as inseparable**: many teams think "if I use CQRS I must use Event Sourcing" — this leads to adopting Event Sourcing complexity without genuine need.
- **Querying the event store for read use cases**: loading an aggregate from the event store to answer a list query (`GET /orders?status=Pending`) is a category error — maintain a SQL projection for list queries.
- **Building ES+CQRS for a simple REST CRUD API**: the combination makes sense for complex domains with audit and scalability requirements — not for a basic API with 10 entities and simple business rules.
- **Over-relying on the event store for consistency between services**: the event store is the source of truth within one bounded context. Cross-service consistency still requires an Outbox pattern + message bus.

## References

- [CQRS Documents — Greg Young](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) (verify URL)
- [CQRS and Event Sourcing — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: cqrs-without-event-sourcing.md](./cqrs-without-event-sourcing.md)
