# CQRS Fundamentals

**Category:** Architecture / CQRS
**Difficulty:** 🟢 Junior
**Tags:** `CQRS`, `command`, `query`, `CQS`, `Greg-Young`, `Bertrand-Meyer`, `read-write-separation`

## Question

> What is CQRS? Where did it originate, and what problem does it solve? What is the difference between CQS (Command Query Separation) and CQRS?

## Short Answer

**CQRS** (Command Query Responsibility Segregation) separates the model for writing data (**commands**: change state, return nothing or just an ID) from the model for reading data (**queries**: return data, never change state). It was popularised by Greg Young (2010) as an evolution of Bertrand Meyer's **CQS** (Command Query Separation) principle. CQS is a method-level principle; CQRS is an architectural pattern that separates entire write and read models — often using different classes, databases, or even services. The primary problem solved: a single model that serves both reads and writes becomes a compromise satisfying neither well.

## Detailed Explanation

### Bertrand Meyer's CQS (1988)

CQS is a design principle at the **method level**:
- **Commands**: change state, return `void` (or an ID if necessary)
- **Queries**: return data, have no side effects

```csharp
// CQS at method level:
void SubmitOrder(SubmitOrderCommand cmd);   // ← command: changes state, void
Order GetOrder(int id);                     // ← query: returns data, no state change

// Violation:
Order SubmitOrder(SubmitOrderCommand cmd);  // ← returns Order AND changes state — violates CQS
```

### Greg Young's CQRS (2010)

CQRS elevates CQS to the **architectural level** — separate classes (or entire stacks) for commands and queries:

```
COMMAND SIDE (Write Model)                 QUERY SIDE (Read Model)
─────────────────────────────              ──────────────────────────
PlaceOrderCommand                          GetOrdersQuery
  → PlaceOrderHandler                        → GetOrdersHandler
    → Order aggregate (DDD)                    → Dapper/direct SQL
    → DB write                                 → DTO projection
    → Domain events                            → Read DB/view
```

The two sides can evolve independently. The read model can be highly denormalized for fast reads; the write model can be normalized for consistency.

### Why CQRS Exists

A traditional repository or service that handles both reads and writes must satisfy both:
- **Write requirements**: consistency, business rules, optimistic locking, event sourcing
- **Read requirements**: joins across tables, pagination, sorting, DTO projections, high throughput

These requirements often conflict. CQRS lets each side optimise independently:

```csharp
// BEFORE CQRS: one model serves both reads and writes
public class OrderService
{
    public Order GetOrder(int id) => _repo.GetById(id);     // ← pulls full entity with all children
    public List<OrderSummary> GetOrderList() { ... }        // ← but also needs summary projections
    public void PlaceOrder(PlaceOrderCmd cmd) { ... }       // ← domain rules, events
    public void CancelOrder(int id) { ... }
    // One service trying to serve two very different concerns
}

// AFTER CQRS: completely separate
// Write side: domain aggregate, repository, events
public class PlaceOrderHandler(IOrderRepository orders) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId), cmd.Lines);
        await orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}

// Read side: direct SQL or Dapper — no aggregate, no domain rules
public class GetOrdersHandler(IDbConnectionFactory db) 
    : IRequestHandler<GetOrdersQuery, PagedResult<OrderSummaryDto>>
{
    public async Task<PagedResult<OrderSummaryDto>> Handle(GetOrdersQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        var rows = await conn.QueryAsync<OrderSummaryDto>(
            "SELECT Id, Status, TotalAmount, CreatedAt FROM Orders WHERE CustomerId = @cid ORDER BY CreatedAt DESC",
            new { cid = q.CustomerId });
        return new PagedResult<OrderSummaryDto>(rows.ToList(), q.Page);
    }
}
```

### CQRS Spectrum: How Far to Go

CQRS exists on a spectrum — you don't need separate databases to get benefit:

| Level | Description | When |
|-------|-------------|------|
| **1. Method level** | CQS: commands/queries as separate methods | Always good practice |
| **2. Handler level** | Separate command/query handler classes | Most apps — lowest cost |
| **3. Model level** | Separate read/write models (DTOs vs aggregates) | Complex domains |
| **4. DB view level** | Read side uses indexed DB views | Read-heavy systems |
| **5. Separate DB** | Event projection to separate read store | High scale, eventual consistency |

Most applications benefit from levels 1–3 without needing levels 4–5.

## Code Example

```csharp
// CQS demonstrated: commands return void (or minimal), queries return data

// Commands — return void or just the new ID
public record PlaceOrderCommand(int CustomerId, List<OrderLineDto> Lines) : IRequest<int>;
public record CancelOrderCommand(int OrderId, string Reason) : IRequest;
public record UpdateShippingAddressCommand(int OrderId, Address NewAddress) : IRequest;

// Queries — return data, never change state
public record GetOrderByIdQuery(int OrderId) : IRequest<OrderDto>;
public record GetOrdersByCustomerQuery(int CustomerId, int Page) : IRequest<PagedResult<OrderSummaryDto>>;
public record GetOrderCountQuery(OrderStatus? Status) : IRequest<int>;

// Usage: by type signature alone, callers know which side effects to expect
var orderId = await sender.Send(new PlaceOrderCommand(customerId: 1, lines)); // ← creates data
var order = await sender.Send(new GetOrderByIdQuery(orderId));                // ← reads data, no side effects
```

## Common Follow-up Questions

- How does CQRS relate to Event Sourcing — are they always used together?
- How does CQRS interact with a single relational database vs separate read/write databases?
- What is the difference between `ISender.Send()` and `IMediator.Send()` in MediatR?
- How do you handle eventual consistency between the write side and the read side?
- When does CQRS add more complexity than it removes?

## Common Mistakes / Pitfalls

- **Equating CQRS with Event Sourcing**: CQRS and Event Sourcing are complementary but independent. You can use CQRS with a traditional relational database and no events.
- **Making queries go through domain aggregates**: loading an EF Core `Order` aggregate just to return an `OrderDto` adds unnecessary load (all navigation properties) and change-tracking overhead. Queries should bypass aggregates and project directly.
- **CQRS for simple CRUD**: a straightforward admin panel with 5 entities doesn't benefit from separate command/query handlers. The pattern adds boilerplate for no domain complexity payoff.
- **Command handlers that return rich domain objects**: commands should return a minimal result (void, ID, or status). Returning the full entity from a command handler forces callers to combine read and write semantics.

## References

- [CQRS — Martin Fowler](https://martinfowler.com/bliki/CQRS.html) (verify URL)
- [CQRS journey — Microsoft patterns & practices](https://learn.microsoft.com/en-us/previous-versions/msp-n-p/jj554200(v=pandp.10)) (verify URL)
- [See: command-vs-query.md](./command-vs-query.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: cqrs-without-event-sourcing.md](./cqrs-without-event-sourcing.md)
