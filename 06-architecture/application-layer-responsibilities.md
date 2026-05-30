# Application Layer Responsibilities

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `application-layer`, `use-cases`, `clean-architecture`, `orchestration`, `CQRS`, `MediatR`

## Question

> What is the responsibility of the Application layer in Clean Architecture? What belongs here and what does not? How does the Application layer differ from the Domain layer and the Infrastructure layer?

## Short Answer

The Application layer orchestrates use cases: it coordinates domain objects to fulfill a single user intent, without containing business rules itself. It calls domain objects (which own the rules), calls driven-port interfaces (which infrastructure implements), and returns results. It knows *what* needs to happen — the sequence of steps — but not *how* persistence, email, or HTTP actually work. Business rules live in the Domain; infrastructure details live in Infrastructure; the Application layer sits between them as a pure workflow coordinator.

## Detailed Explanation

### The Application Layer's Job

Think of the Application layer as the "use-case layer" — each handler represents one user scenario:

- Load an aggregate via a repository
- Call a domain method (which enforces business rules)
- Persist the result via a repository
- Raise/publish events or call external services via driven ports
- Return a DTO to the caller

**It does NOT:**
- Make persistence decisions (that's Infrastructure)
- Contain business rules that belong in the domain (price calculation, invariant enforcement)
- Reference EF Core, HTTP clients, or any external frameworks directly
- Know about HTTP verbs, request/response formats, or authentication

### What Lives in the Application Layer

| Item | Example |
|------|---------|
| Command/Query objects | `PlaceOrderCommand`, `GetOrderByIdQuery` |
| Handlers (MediatR or plain) | `PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, int>` |
| Application-layer DTOs | `OrderDto`, `ProductSummaryDto` |
| Driven-port interfaces | `IOrderRepository`, `IEmailSender`, `ICurrentUser` |
| Validators | `PlaceOrderCommandValidator : AbstractValidator<PlaceOrderCommand>` |
| Mapping configuration | AutoMapper profiles, manual projection methods |
| Pipeline behaviors | `ValidationBehavior<TReq, TRes> : IPipelineBehavior` |
| Application exceptions | `NotFoundException`, `ConflictException` |

### Orchestration vs Business Rules — The Crucial Distinction

```csharp
// ❌ WRONG: Business rule in Application handler
public class CancelOrderHandler(IOrderRepository orders) 
    : IRequestHandler<CancelOrderCommand>
{
    public async Task Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct);
        // ← RULE: "only pending orders can be cancelled" doesn't belong here
        if (order.Status != "Pending")
            throw new InvalidOperationException("Only pending orders can be cancelled.");
        order.Status = "Cancelled";  // ← mutating entity directly from handler
        await orders.SaveAsync(order, ct);
    }
}

// ✅ CORRECT: Application orchestrates; Domain enforces
public class CancelOrderHandler(IOrderRepository orders) 
    : IRequestHandler<CancelOrderCommand>
{
    public async Task Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);
        order.Cancel();              // ← rule is in Order.Cancel()
        await orders.SaveAsync(order, ct);
    }
}
```

### Application Layer vs Layers Above and Below

| Layer | Knows about | Does not know about |
|-------|-------------|---------------------|
| **Domain** | Business rules, invariants, domain events | Persistence, HTTP, application workflow |
| **Application** | Use-case workflow, domain interfaces | SQL, EF Core, SendGrid, framework types |
| **Infrastructure** | How to persist, send email, call APIs | Business rules, use-case sequence |
| **Presentation** | HTTP, gRPC, queues, auth, serialization | Business rules, domain model internals |

### CQRS Integration

The Application layer is the natural home for CQRS:

```csharp
// Commands mutate state — go through domain aggregate
public record CreateProductCommand(string Name, decimal Price) : IRequest<int>;

// Queries read state — can bypass domain and go straight to read model
public record GetProductsQuery(string? SearchTerm, int Page) 
    : IRequest<PagedResult<ProductDto>>;

// Query handler can use Dapper / direct SQL for reads — no domain objects needed
public class GetProductsHandler(IDbConnectionFactory db) 
    : IRequestHandler<GetProductsQuery, PagedResult<ProductDto>>
{
    public async Task<PagedResult<ProductDto>> Handle(GetProductsQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        var sql = "SELECT Id, Name, Price FROM Products WHERE (@Search IS NULL OR Name LIKE '%' + @Search + '%') ORDER BY Name OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";
        var rows = await conn.QueryAsync<ProductDto>(sql, new { Search = q.SearchTerm, Offset = (q.Page - 1) * 20, PageSize = 20 });
        return new PagedResult<ProductDto>(rows.ToList(), q.Page);
    }
}
```

## Code Example

```csharp
// ── Contracts (Application layer) ────────────────────────────────
public interface IOrderRepository
{
    Task AddAsync(Order order, CancellationToken ct = default);
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
}

public interface ICurrentUser
{
    int UserId { get; }
    bool IsAdmin { get; }
}

// ── Command + Handler ─────────────────────────────────────────────
public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

public class PlaceOrderValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderValidator()
    {
        RuleFor(x => x.CustomerId).GreaterThan(0);
        RuleFor(x => x.Total).GreaterThan(0).LessThan(1_000_000);
    }
}

public class PlaceOrderHandler(
    IOrderRepository orders,
    IEmailSender email,
    ICurrentUser currentUser) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Orchestration: load, call domain, persist, notify
        var order = new Order(cmd.CustomerId, cmd.Total); // domain enforces rules
        await orders.AddAsync(order, ct);
        await email.SendOrderConfirmationAsync(cmd.CustomerId, order.Id, ct);
        return order.Id;
    }
}
```

## Common Follow-up Questions

- When does logic belong in the Application handler vs the Domain aggregate?
- How do you handle cross-cutting concerns (auth checks, logging) without polluting every handler?
- What is the difference between an Application Service and a Domain Service?
- How do you test Application layer handlers without hitting the database?
- Should Application layer DTOs be the same as API response models?

## Common Mistakes / Pitfalls

- **Business rules in handlers**: conditions like "orders over $10,000 need approval" placed directly in a `PlaceOrderHandler` will be duplicated every time a command places an order from a different entry point (background job, CLI, another handler).
- **Repositories with LINQ `IQueryable` leaking to Application**: `IQueryable<Order>` in an Application-layer interface forces the handler to construct EF Core–specific queries, breaking infrastructure independence.
- **Application DTOs used as domain objects**: mapping a `PlaceOrderCommand` directly onto an EF Core entity in the handler skips domain construction and invariant enforcement.
- **Fat handlers**: handlers that directly call 5 different infrastructure services, apply business rules, do mapping, and transform results are orchestrating *and* doing domain work. Extract domain logic to the domain, cross-cutting work to pipeline behaviors.

## References

- [Application layer patterns — Microsoft .NET Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-implementation-web-api)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
