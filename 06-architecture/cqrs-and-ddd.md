# CQRS and DDD

**Category:** Architecture / CQRS
**Difficulty:** 🔴 Senior
**Tags:** `CQRS`, `DDD`, `aggregates`, `domain-events`, `projections`, `command-side`, `query-side`, `integration`

## Question

> How do DDD and CQRS compose together in a .NET application? How does the command flow through aggregates and domain events to projections, and how do you structure a solution that uses both patterns?

## Short Answer

DDD and CQRS are complementary but independent. DDD's aggregates own the write model: a command loads the aggregate, calls a domain method, raises domain events. CQRS separates the read side from this write side. The composition: **command → aggregate method → domain event → projection handler (updates read model)**. The query side bypasses aggregates entirely and reads directly from a read model (DB view, denormalized table, or search index). The key integration point is the domain event: it's raised in the aggregate, dispatched after SaveChanges, and consumed by projection handlers that maintain the read model.

## Detailed Explanation

### The Full Flow

```
COMMAND SIDE (DDD + CQRS write)
──────────────────────────────────────────────────────────
PlaceOrderCommand
  → PlaceOrderHandler
    → IOrderRepository.GetByIdAsync  (load aggregate)
    → order.AddLine(...)             (domain method — invariant check)
    → order.Submit()                 (domain method — raises OrderSubmittedEvent)
    → IUnitOfWork.SaveChangesAsync
        → SaveChangesInterceptor dispatches OrderSubmittedEvent
              ↓
    ─────────────────────────────────────────────────────
    OrderSubmittedEvent handlers (INotificationHandler):
      → UpdateOrderReadModel        (sync projection — same transaction)
      → PublishIntegrationEvent     (outbox — async cross-service)
      → NotifyWarehouseWorker       (async — eventual consistency)
    ─────────────────────────────────────────────────────

QUERY SIDE (CQRS read — bypasses aggregates)
──────────────────────────────────────────────────────────
GetOrdersQuery
  → GetOrdersHandler
    → Dapper / AsNoTracking projection → OrderSummaryDto
    ← returns DTOs (no aggregate, no domain events, no tracking)
```

### Project Structure

```
YourApp.Domain/
  Entities/Order.cs              ← aggregate root
  Events/OrderSubmittedEvent.cs  ← domain event

YourApp.Application/
  Features/Orders/
    Commands/
      PlaceOrder/
        PlaceOrderCommand.cs     ← ICommand<int>
        PlaceOrderHandler.cs     ← loads aggregate, calls domain, saves
        PlaceOrderValidator.cs
    Queries/
      GetOrders/
        GetOrdersQuery.cs        ← IQuery<PagedResult<OrderSummaryDto>>
        GetOrdersHandler.cs      ← direct SQL / Dapper
        OrderSummaryDto.cs
    Projections/
      OrderReadModelProjection.cs ← INotificationHandler<OrderSubmittedEvent>
```

### Aggregate + Domain Event → Projection

```csharp
// Domain: aggregate raises event during Submit()
public class Order : AggregateRoot
{
    public void Submit()
    {
        if (!_lines.Any()) throw new DomainException("Empty order.");
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, CustomerId, Total, Lines.Count));
    }
}

// Application: projection handler updates the read model
public class OrderReadModelProjection(AppDbContext db)
    : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        var summary = await db.Set<OrderSummary>().FindAsync([e.OrderId.Value], ct);
        if (summary is null)
        {
            db.Set<OrderSummary>().Add(new OrderSummary
            {
                Id = e.OrderId.Value,
                CustomerId = e.CustomerId.Value,
                Status = "Submitted",
                TotalAmount = e.Total.Amount,
                LineCount = e.LineCount,
                LastUpdated = e.OccurredAt
            });
        }
        else
        {
            summary.Status = "Submitted";
            summary.LastUpdated = e.OccurredAt;
        }
    }
}
```

### Read Side: Bypassing Aggregates

```csharp
// Query handler: direct Dapper — no aggregate, no domain logic needed
public class GetOrdersByCustomerHandler(IDbConnectionFactory db)
    : IRequestHandler<GetOrdersByCustomerQuery, IReadOnlyList<OrderSummaryDto>>
{
    public async Task<IReadOnlyList<OrderSummaryDto>> Handle(
        GetOrdersByCustomerQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        var rows = await conn.QueryAsync<OrderSummaryDto>(
            "SELECT Id, Status, TotalAmount, LineCount FROM OrderSummaries WHERE CustomerId = @cid ORDER BY LastUpdated DESC",
            new { cid = q.CustomerId });
        return rows.ToList();
    }
}
```

### Where DDD and CQRS Diverge

DDD's repository pattern focuses on the **aggregate** (write side). CQRS' query side **does not use repositories** — it uses direct SQL, views, or read-model stores:

```csharp
// ❌ WRONG: Using aggregate repository for query
public class GetOrdersHandler(IOrderRepository orders) // ← repository is write-side concern
    : IRequestHandler<GetOrdersQuery, List<OrderDto>>
{
    public async Task<List<OrderDto>> Handle(GetOrdersQuery q, CancellationToken ct)
    {
        var orders = await orders.GetByCustomerAsync(q.CustomerId, ct);
        return orders.Select(o => new OrderDto(o.Id.Value, o.Total.Amount)).ToList();
        // ↑ Loads full aggregate including all OrderLines just to project to a DTO
    }
}

// ✅ CORRECT: Query side uses direct projection
public class GetOrdersHandler(IDbConnectionFactory db)
    : IRequestHandler<GetOrdersQuery, List<OrderSummaryDto>>
{
    public async Task<List<OrderSummaryDto>> Handle(GetOrdersQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        return (await conn.QueryAsync<OrderSummaryDto>(
            "SELECT Id, Status, TotalAmount FROM OrderSummaries WHERE CustomerId = @cid",
            new { cid = q.CustomerId })).ToList();
    }
}
```

## Code Example

```csharp
// Integration test: full DDD + CQRS flow end-to-end
[Fact]
public async Task PlaceOrder_Command_UpdatesReadModelViaEvent()
{
    var (db, sender) = await CreateTestContextAsync();

    // Command: goes through aggregate + domain event + projection
    var orderId = await sender.Send(new PlaceOrderCommand(CustomerId: 1, Total: 99.99m));

    // Query: reads from the projected read model (not from aggregate)
    var summaries = await sender.Send(new GetOrdersByCustomerQuery(CustomerId: 1));

    Assert.Contains(summaries, s => s.Id == orderId && s.Status == "Submitted");
}
```

## Common Follow-up Questions

- When does the projection run in the same transaction as the command vs asynchronously?
- How do you rebuild all read models from scratch if the projection logic changes?
- Can you use DDD without CQRS — and vice versa?
- How do you handle a query that needs to combine data from two bounded contexts?
- What is a "process manager" (saga), and how does it use domain events to coordinate multi-step workflows?

## Common Mistakes / Pitfalls

- **Using aggregate repositories on the query side**: loading a full `Order` aggregate with 30 `OrderLine` entities to return a 3-field `OrderSummaryDto` wastes memory and DB round-trips.
- **Mixing command and query logic in one handler**: a handler that both modifies state and returns a full read model projection (with joins) merges two concerns that should be separate.
- **Projection logic in the domain layer**: projection handlers that update read model tables use infrastructure (DbContext, Dapper) and belong in the Application or Infrastructure layer, not the Domain layer.
- **Forgetting to rebuild projections after schema changes**: if the `OrderSummary` table schema changes, existing rows need migration or rebuild from the event log.

## References

- [CQRS + DDD in microservices — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/apply-simplified-microservice-cqrs-ddd-patterns)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: domain-events.md](./domain-events.md)
- [See: cqrs-read-models.md](./cqrs-read-models.md)
