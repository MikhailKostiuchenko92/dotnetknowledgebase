# Event Sourcing vs CRUD

**Category:** System Design / Data Storage
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `CRUD`, `append-only`, `event-store`, `projections`, `snapshots`, `CQRS`

## Question

> What is event sourcing, and how does it differ from traditional CRUD? What are its advantages (audit log, replay, temporal queries) and disadvantages (complexity, query difficulty, snapshot management)?

## Short Answer

Event sourcing stores every state change as an immutable event in an append-only log, rather than overwriting the current state. The current state of an entity is derived by replaying its events. This gives you a complete, permanent audit trail, the ability to reconstruct state at any point in time, and a natural foundation for CQRS read models. The trade-offs are significant: queries require projections (read models) rather than direct table queries, schema evolution requires event upcasting, and performance requires periodic snapshots to avoid replaying thousands of events.

## Detailed Explanation

### CRUD Model

Traditional CRUD updates the current state in place:

```
INSERT INTO orders (id, status, total) VALUES (1, 'Pending', 100)
UPDATE orders SET status = 'Shipped'  WHERE id = 1
UPDATE orders SET status = 'Delivered' WHERE id = 1
```

**Result**: current state is `{ id: 1, status: 'Delivered', total: 100 }`.  
**Lost**: what it was before, when it changed, who changed it, and why.

### Event Sourcing Model

Every change is stored as an immutable event:

```
{ type: "OrderPlaced",   orderId: 1, total: 100,     by: "user-42", at: "2025-01-01 10:00" }
{ type: "OrderShipped",  orderId: 1, trackingId: "X", by: "ops-1",  at: "2025-01-02 14:00" }
{ type: "OrderDelivered",orderId: 1,                  by: "system", at: "2025-01-03 09:00" }
```

**Current state**: replay all events to compute `{ id: 1, status: 'Delivered', trackingId: 'X' }`.  
**Full history**: all three events are permanent and immutable.

### Advantages

**1. Audit log for free**: every state change is an event with who/when/why — GDPR, compliance, debugging.

**2. Temporal queries**: "What was the state of this order at noon yesterday?" — replay events up to that timestamp.

**3. Event replay**: fix a bug in the projection → rebuild the read model by replaying all events from the start.

**4. Natural CQRS foundation**: events are the write side; projections (read models) are the query side. [See: read-write-splitting.md](./read-write-splitting.md)

**5. Decoupled consumers**: new features subscribe to existing events without modifying the write path.

**6. Debugging production issues**: reproduce a bug by replaying the exact sequence of events that caused it.

### Disadvantages

**1. Query complexity**: you cannot `SELECT * FROM Orders WHERE status = 'Pending'`. You need a projection (a denormalised table updated by consuming events) to support read queries.

**2. Schema evolution**: changing an event's structure requires upcasting old events when loading (transforming old format to new format). Versioning event schemas is a discipline.

**3. Snapshot requirement**: replaying 100,000 events to get an entity's current state is slow. Periodic snapshots store the current state at a point in time; replay only events after the snapshot.

**4. Not suitable for all data**: reference data, large BLOBs, simple CRUD with no audit needs — overhead exceeds benefit.

**5. Eventual read model consistency**: projections lag behind the event store by milliseconds to seconds. [See: eventual-consistency.md](./eventual-consistency.md)

### Snapshots

After N events, a snapshot is saved:

```
{ aggregateId: 1, version: 100, state: { ... full state ... }, at: "..." }
```

On load: read the latest snapshot (version 100) → replay only events from version 101+.

Snapshot frequency: every 50–200 events is typical. Too frequent = write overhead. Too infrequent = slow load.

### Event Store Options for .NET

| Store | Type | Notes |
|-------|------|-------|
| **EventStoreDB** | Purpose-built event store | Persistent subscriptions, projections built-in |
| **SQL Server / PostgreSQL** | Relational (DIY) | Simple, familiar; no built-in subscriptions |
| **Cosmos DB** | Document + change feed | Change feed = event stream; global scale |
| **Marten** (PostgreSQL extension) | OSS .NET library | Full event sourcing + document store on top of PostgreSQL |

**Marten** is the most popular .NET-native event sourcing library, providing an event store and projection engine on top of PostgreSQL.

## Code Example

```csharp
// Event sourcing with Marten on PostgreSQL
// .NET 8 — JasperFx/Marten

using Marten;
using Marten.Events;

// ── Setup ─────────────────────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMarten(options =>
{
    options.Connection(builder.Configuration.GetConnectionString("Postgres")!);
    options.Projections.Add<OrderProjection>(ProjectionLifecycle.Inline);
    // Inline: projection updated synchronously in the same transaction as the event
    // Async: projection updated via background worker (eventual consistency)
});

// ── Domain events ─────────────────────────────────────────────────────
record OrderPlaced(Guid OrderId, string CustomerId, decimal Total);
record OrderShipped(Guid OrderId, string TrackingNumber);
record OrderCancelled(Guid OrderId, string Reason);

// ── Aggregate: derives current state from events ──────────────────────
public class OrderAggregate
{
    public Guid Id { get; private set; }
    public string CustomerId { get; private set; } = "";
    public decimal Total { get; private set; }
    public string Status { get; private set; } = "";
    public string? TrackingNumber { get; private set; }

    // Marten calls Apply() for each event in sequence
    public void Apply(OrderPlaced e)    { Id = e.OrderId; CustomerId = e.CustomerId; Total = e.Total; Status = "Pending"; }
    public void Apply(OrderShipped e)   { Status = "Shipped"; TrackingNumber = e.TrackingNumber; }
    public void Apply(OrderCancelled e) { Status = "Cancelled"; }

    public bool CanShip() => Status == "Pending";
    public bool CanCancel() => Status is "Pending" or "Shipped";
}

// ── Read model projection ─────────────────────────────────────────────
// Denormalised view for query-side — supports filtering by status, customerId, etc.
public record OrderSummary(Guid Id, string CustomerId, decimal Total, string Status, string? TrackingNumber);

public class OrderProjection : EventProjection
{
    public OrderSummary Create(OrderPlaced e) =>
        new(e.OrderId, e.CustomerId, e.Total, "Pending", null);

    public OrderSummary Apply(OrderShipped e, OrderSummary current) =>
        current with { Status = "Shipped", TrackingNumber = e.TrackingNumber };

    public OrderSummary Apply(OrderCancelled e, OrderSummary current) =>
        current with { Status = "Cancelled" };
}

// ── Endpoints ─────────────────────────────────────────────────────────
var app = builder.Build();

// Write: append events to the event stream
app.MapPost("/orders", async (CreateOrderRequest req, IDocumentSession session) =>
{
    var orderId = Guid.NewGuid();
    session.Events.StartStream<OrderAggregate>(orderId,
        new OrderPlaced(orderId, req.CustomerId, req.Total));
    await session.SaveChangesAsync();
    return Results.Created($"/orders/{orderId}", new { orderId });
});

app.MapPost("/orders/{id}/ship", async (Guid id, string trackingNumber, IDocumentSession session) =>
{
    // Load aggregate by replaying events (with snapshot if configured)
    var order = await session.Events.AggregateStreamAsync<OrderAggregate>(id);
    if (order is null)       return Results.NotFound();
    if (!order.CanShip())    return Results.Conflict($"Cannot ship: status={order.Status}");

    session.Events.Append(id, new OrderShipped(id, trackingNumber));
    await session.SaveChangesAsync();
    return Results.Ok();
});

// Query: read from projection (fast, no event replay)
app.MapGet("/orders", async (string? status, IQuerySession session) =>
{
    var query = session.Query<OrderSummary>();
    if (status is not null)
        query = (IMartenQueryable<OrderSummary>)query.Where(o => o.Status == status);
    return Results.Ok(await query.ToListAsync());
});

// Temporal: state of an order at a specific point in time
app.MapGet("/orders/{id}/at", async (Guid id, DateTime timestamp, IDocumentSession session) =>
{
    var state = await session.Events.AggregateStreamAsync<OrderAggregate>(id, timestamp: timestamp);
    return state is null ? Results.NotFound() : Results.Ok(state);
});

app.Run();
record CreateOrderRequest(string CustomerId, decimal Total);
```

## Common Follow-up Questions

- How do you handle schema evolution (renaming a field in an event that has millions of existing instances)?
- When does a snapshot strategy become necessary, and how do you implement it in Marten?
- How does event sourcing relate to CQRS — are they always used together?
- How do you delete a user's data for GDPR "right to erasure" in an event-sourced system where events are immutable?
- What is the "eventual consistency window" between event append and projection update, and how do you handle it in the UI?
- What is event versioning / upcasting, and how does Marten support it?

## Common Mistakes / Pitfalls

- **Storing commands as events**: an event is a fact ("OrderPlaced"); a command is an intent ("PlaceOrder"). Storing the command conflates intent and outcome — store only domain events that record what happened.
- **Overly granular events**: an event for each field change (`NameChanged`, `EmailChanged`, `PhoneChanged`) creates noise. Events should represent meaningful business transitions (`UserProfileUpdated`).
- **Not planning for schema evolution**: in a CRUD system, you rename a column with a migration. In event sourcing, old events still have the old schema. Every event change requires upcasting code that transforms old events to the new format when loading.
- **Using event sourcing for all entities**: stateless reference data (country lists, currency rates), user preferences that change frequently with no audit need, or simple CRUD entities add complexity without benefit.
- **GDPR compliance gap**: immutable events conflict with "right to erasure". Solutions: event tombstoning (null the PII field), encryption per user (delete the key to "erase" the data), or storing PII in a GDPR store with a reference in events.
- **Not benchmarking projection rebuild time**: if the event store has 500 million events and a projection rebuild takes 8 hours, a schema change becomes a multi-day operation. Plan for incremental rebuilds and dual projections.

## References

- [Marten — .NET event sourcing and document store](https://martendb.io/)
- [EventStoreDB documentation](https://developers.eventstore.com/)
- [Martin Fowler — Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Greg Young — CQRS Documents](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf)
- [See: read-write-splitting.md](./read-write-splitting.md) — CQRS read models built from event projections
