# CQRS Write Models

**Category:** Architecture / CQRS
**Difficulty:** 🟡 Middle
**Tags:** `CQRS`, `write-model`, `command-handler`, `aggregate`, `domain-events`, `persistence`

## Question

> What is the write model (command side) in CQRS? Describe the full flow from command receipt to persistence and event publication. How does the write model differ from the read model in terms of design goals?

## Short Answer

The **write model** in CQRS handles all state changes: a command handler loads the relevant aggregate from the repository, calls a domain method that enforces business rules and raises domain events, then persists the aggregate. The write model is optimised for **consistency and correctness** — normalized data, aggregate boundaries, transactional integrity. It never returns rich read data (only a result ID or status). Domain events raised during the command are dispatched after the transaction commits, potentially updating read models asynchronously.

## Detailed Explanation

### Write Model Flow

```
HTTP POST /orders
    → [PlaceOrderCommand]
        → PlaceOrderHandler (application layer)
            → IOrderRepository.GetByIdAsync (load aggregate)
            → order.AddLine(...) (domain method — validates invariants)
            → order.Submit()    (domain method — raises OrderSubmittedEvent)
            → IUnitOfWork.SaveChangesAsync
                → EF Core commits transaction
                → SaveChangesInterceptor dispatches OrderSubmittedEvent
                    → SendConfirmationEmail handler
                    → UpdateInventoryProjection handler
    ← Returns: orderId (not the full order DTO)
```

### Write Model Design Goals

| Goal | How it's achieved |
|------|------------------|
| **Correctness** | Domain aggregate enforces invariants, throws on violations |
| **Consistency** | One transaction per aggregate root |
| **Auditability** | Domain events record what happened |
| **Testability** | Aggregate unit-testable without infrastructure |
| **Minimal response** | Returns ID or void — not read data |

### A Complete Write Model Command Handler

```csharp
// Command definition
public record SubmitOrderCommand(int OrderId) : IRequest;

// Handler: orchestrates domain + persistence
public class SubmitOrderHandler(
    IOrderRepository orders,
    IUnitOfWork uow) : IRequestHandler<SubmitOrderCommand>
{
    public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
    {
        // 1. Load aggregate
        var order = await orders.GetByIdAsync(new OrderId(cmd.OrderId), ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);

        // 2. Execute domain logic (aggregate enforces invariants + raises events)
        order.Submit();

        // 3. Persist (events dispatched in SaveChangesAsync interceptor)
        await uow.SaveChangesAsync(ct);
    }
}
```

### Write Model vs Read Model Design Contrast

| Aspect | Write Model | Read Model |
|--------|------------|------------|
| **Purpose** | Enforce business rules, change state | Answer queries efficiently |
| **Shape** | Normalised aggregates | Denormalized projections |
| **EF Core** | Tracked entities, domain methods | AsNoTracking, direct Select projection |
| **Returns** | void / ID / status | DTO, list, count |
| **Dependencies** | Domain aggregates, repositories | DbContext / Dapper / read store |
| **Testing** | Unit tests on aggregates, integration tests for handler | Integration tests for query results |

### Handling Concurrency on the Write Side

```csharp
// Optimistic concurrency: rowversion check on save
public class Order
{
    [Timestamp]
    public byte[]? RowVersion { get; private set; }  // EF Core rowversion
}

// In the handler: catch and retry or surface conflict to caller
public async Task Handle(UpdateOrderCommand cmd, CancellationToken ct)
{
    var order = await orders.GetByIdAsync(cmd.OrderId, ct);
    order.UpdateShippingAddress(cmd.NewAddress);

    try { await uow.SaveChangesAsync(ct); }
    catch (DbUpdateConcurrencyException)
    {
        throw new ConflictException($"Order {cmd.OrderId} was modified concurrently.");
    }
}
```

### Write Model with Event Sourcing

When Event Sourcing is used on the write side, the write model stores events instead of state:

```csharp
// Write model: events append-only
public class EventSourcedOrderRepository(IEventStore store) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
    {
        var events = await store.GetEventsAsync(id.Value.ToString(), ct);
        if (!events.Any()) return null;
        return Order.ReplayFrom(events);  // ← rebuild state from events
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
        => await store.AppendEventsAsync(order.Id.Value.ToString(),
            order.DomainEvents, order.Version, ct);
}
```

## Code Example

```csharp
// Write model unit test — no infrastructure needed
[Fact]
public async Task SubmitOrder_WithLines_ChangesStatusAndRaisesEvent()
{
    // Arrange
    var order = Order.Create(new CustomerId(1));
    order.AddLine(new ProductId(10), quantity: 2, new Money(49.99m));

    var repo = new InMemoryOrderRepository().With(order);
    var uow = new InMemoryUnitOfWork();
    var handler = new SubmitOrderHandler(repo, uow);

    // Act
    await handler.Handle(new SubmitOrderCommand(order.Id.Value), CancellationToken.None);

    // Assert
    Assert.Equal(OrderStatus.Submitted, order.Status);
    Assert.Single(order.DomainEvents.OfType<OrderSubmittedEvent>());
    Assert.True(uow.WasSaved);
}
```

## Common Follow-up Questions

- Should the write model return the aggregate after modification, or should the client issue a separate read query?
- How do you handle long-running commands that can't complete in a single synchronous request?
- How do you test write model handlers that have complex domain interactions?
- When does the write model need an optimistic vs pessimistic locking strategy?
- How do you handle partial command failures — should partial successes be committed?

## Common Mistakes / Pitfalls

- **Returning the aggregate from a command handler**: `PlaceOrderHandler` returning an `OrderDto` requires projecting the full entity — this merges write and read concerns in the handler.
- **Business logic in the command handler**: checking "only admin users can cancel" in `CancelOrderHandler` is an application-layer authorization concern. Deep business rules ("can only cancel if payment hasn't cleared") belong in `Order.Cancel()`.
- **Multiple aggregates in one command handler**: loading `Order` and `Customer` and modifying both in a single `SaveChangesAsync` couples two aggregates in one transaction.
- **Events dispatched before commit**: dispatching domain events before `SaveChangesAsync` means handlers act on data that may not yet be committed — a crash between dispatch and commit leaves the system in an inconsistent state.

## References

- [CQRS command side — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-implementation-web-api)
- [See: cqrs-read-models.md](./cqrs-read-models.md)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: domain-events.md](./domain-events.md)
