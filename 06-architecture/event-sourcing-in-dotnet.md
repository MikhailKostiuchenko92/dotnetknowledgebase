# Event Sourcing in .NET

**Category:** Architecture / Event Sourcing
**Difficulty:** 🟡 Middle
**Tags:** `event-sourcing`, `EventStoreDB`, `Marten`, `PostgreSQL`, `ESDB`, `.NET`, `NEventStore`

## Question

> What are the main options for implementing Event Sourcing in .NET? Compare EventStoreDB, Marten (PostgreSQL), and a custom SQL implementation — when would you choose each?

## Short Answer

In .NET, the three main Event Sourcing options are: **EventStoreDB** (purpose-built, high performance, excellent .NET client), **Marten** (uses PostgreSQL as an event store — lower operational overhead if you already run Postgres), and a **custom SQL implementation** (minimal external dependencies, full control, but more code to write). For most greenfield projects on PostgreSQL, Marten is the pragmatic choice. For high-throughput pure event sourcing with rich subscription features, EventStoreDB. For teams constrained to SQL Server with no new infrastructure, a custom table-based store.

## Detailed Explanation

### EventStoreDB

A database purpose-built for event sourcing, with first-class .NET support:

```bash
# Run EventStoreDB in Docker
docker run -d --name esdb \
  -p 2113:2113 -p 1113:1113 \
  eventstore/eventstore:latest \
  --insecure --run-projections=All
```

```csharp
// NuGet: EventStore.Client.Grpc.Streams
var settings = EventStoreClientSettings.Create("esdb://localhost:2113?tls=false");
var client = new EventStoreClient(settings);

// Append events
var orderCreated = new EventData(
    Uuid.NewUuid(),
    "OrderCreated",
    JsonSerializer.SerializeToUtf8Bytes(new OrderCreatedEvent(42, 7)));

await client.AppendToStreamAsync(
    "order-42",
    StreamState.NoStream,         // ← creates new stream; use StreamRevision for updates
    [orderCreated]);

// Read all events for aggregate
var result = client.ReadStreamAsync(Direction.Forwards, "order-42", StreamPosition.Start);
await foreach (var evt in result)
{
    var type = Type.GetType(evt.Event.EventType)!;
    var payload = JsonSerializer.Deserialize(evt.Event.Data.Span, type)!;
    // Apply to aggregate...
}
```

**Strengths**: purpose-built, persistent/catch-up subscriptions, server-side projections (JavaScript), clustering, high throughput.  
**Weaknesses**: extra infrastructure to operate, no relational queries (need a separate read DB).

### Marten (PostgreSQL)

Marten turns PostgreSQL into an event store + document store — no extra infrastructure:

```bash
dotnet add package Marten
```

```csharp
// Registration
builder.Services.AddMarten(options =>
{
    options.Connection(builder.Configuration.GetConnectionString("Postgres")!);
    // Register event types for proper deserialization
    options.Events.AddEventTypes([
        typeof(OrderCreatedEvent),
        typeof(OrderSubmittedEvent),
        typeof(OrderConfirmedEvent)
    ]);
}).UseLightweightSessions();

// Repository using Marten's IDocumentSession
public class MartenOrderRepository(IDocumentStore store) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
    {
        await using var session = store.LightweightSession();
        // Marten replays all events in the stream and applies them via Order.Apply()
        return await session.Events.AggregateStreamAsync<Order>(id.Value, token: ct);
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        await using var session = store.LightweightSession();
        session.Events.Append(order.Id.Value, order.GetNewEvents().ToArray());
        await session.SaveChangesAsync(ct);
    }
}

// Marten calls Apply() for each event type — convention-based
public class Order
{
    public Guid Id { get; private set; }
    public OrderStatus Status { get; private set; }

    // Marten calls these Apply() methods during stream aggregation
    public void Apply(OrderCreatedEvent e) { Id = e.OrderId; Status = OrderStatus.Draft; }
    public void Apply(OrderSubmittedEvent e) { Status = OrderStatus.Submitted; }
    public void Apply(OrderConfirmedEvent e) { Status = OrderStatus.Confirmed; }
}
```

**Strengths**: uses existing PostgreSQL, rich .NET API, inline projections, snapshot support, good performance.  
**Weaknesses**: PostgreSQL-only, not a pure event store (shares DB with other data).

### Marten Inline Projections

Marten can maintain projections automatically:

```csharp
options.Projections.Snapshot<Order>(SnapshotLifecycle.Inline);   // sync snapshot
options.Projections.Add<OrderSummaryProjection>(ProjectionLifecycle.Async); // async
```

### Custom SQL Event Store (SQL Server)

```csharp
// Minimal table — see event-store-design.md for full schema
// When to use: SQL Server-only, no new infrastructure allowed
public class SqlServerEventStore(string conn) : IEventStore
{
    public async Task AppendToStreamAsync(string streamId, int expectedVersion,
        IEnumerable<object> events, CancellationToken ct)
    {
        // Unique constraint on (StreamId, Version) handles concurrency
        using var connection = new SqlConnection(conn);
        // ... INSERT with version check (see event-store-design.md)
    }
}
```

### Comparison

| | EventStoreDB | Marten | Custom SQL |
|--|-------------|--------|------------|
| **Infra** | Separate server | PostgreSQL only | SQL Server / any |
| **Setup** | High | Medium | Low |
| **Performance** | Highest | High | Medium |
| **Subscriptions** | Native (persistent) | Daemon/async | Manual polling |
| **Projections** | Server-side JS + .NET | Inline/async C# | Manual |
| **Snapshots** | Native | Built-in | Manual |
| **Best for** | Pure ES, high throughput | PostgreSQL shops | SQL Server constraint |

## Code Example

```csharp
// Marten: end-to-end aggregate load + command + save
public class PlaceOrderHandler(IDocumentStore store) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        await using var session = store.LightweightSession();

        var orderId = Guid.NewGuid();
        var events = new object[]
        {
            new OrderCreatedEvent(orderId, cmd.CustomerId, DateTime.UtcNow),
            new OrderLineAddedEvent(orderId, cmd.ProductId, cmd.Quantity, cmd.Price)
        };

        // Append to new stream — optimistic concurrency: IsNew check
        session.Events.StartStream<Order>(orderId, events);
        await session.SaveChangesAsync(ct);
        return (int)orderId.GetHashCode(); // In real code: use int ID from event
    }
}
```

## Common Follow-up Questions

- How does Marten handle optimistic concurrency — what is its equivalent of `expectedVersion`?
- How do you migrate from a custom SQL event store to EventStoreDB without losing events?
- How do you handle Marten projection rebuilds when the event schema changes?
- What is the performance difference between Marten and EventStoreDB for 1 million events?
- When would you use NEventStore instead of EventStoreDB or Marten?

## Common Mistakes / Pitfalls

- **Storing CLR type names as event type strings**: `typeof(OrderCreatedEvent).AssemblyQualifiedName` breaks when you rename or move the event class. Use a short discriminator string registered in options.
- **No event type versioning from day one**: starting without a versioning strategy makes event schema evolution painful. Register `"OrderCreated"` not the full type name from the start.
- **Loading entire stream for every read on large aggregates**: 10,000 events per aggregate needs snapshots. Marten and EventStoreDB both support snapshots — plan ahead.
- **Using Marten Document Store and Event Store without separation**: Marten can store both documents and events in the same PostgreSQL database. Use separate schemas (`schema.For<OrderSummary>()`) to keep read models and event streams organized.

## References

- [EventStoreDB .NET Client documentation](https://developers.eventstore.com/clients/grpc/getting-started/)
- [Marten documentation — Event Sourcing](https://martendb.io/events/)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-store-design.md](./event-store-design.md)
- [See: snapshots-in-event-sourcing.md](./snapshots-in-event-sourcing.md)
