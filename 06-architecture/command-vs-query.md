# Command vs Query

**Category:** Architecture / CQRS
**Difficulty:** 🟢 Junior
**Tags:** `CQRS`, `command`, `query`, `CQS`, `side-effects`, `idempotency`, `MediatR`

## Question

> What makes something a "command" vs a "query" in CQRS? What is the contract for each — what do they return, what side effects are allowed? How does this distinction affect API design and testing?

## Short Answer

A **command** expresses intent to change state: "Place this order", "Cancel this payment". It may have side effects (DB writes, events sent), and ideally returns only an ID or nothing. A **query** retrieves information without changing state: "Give me this order", "How many pending orders are there?". Queries must be **idempotent** and **side-effect free** — calling a query 100 times produces the same result and nothing changes. This clean separation makes queries safe to cache, retry, and call from anywhere, while commands carry the full weight of state-change contracts.

## Detailed Explanation

### The Contracts

**Command contract**:
- **Intent**: change system state
- **Returns**: `void`, a new entity ID, or a minimal result (success/failure status)
- **Side effects**: allowed and expected (DB write, event publication, email send)
- **Idempotency**: not guaranteed by default — placing the same order twice creates two orders; commands need explicit idempotency keys if required
- **Named**: imperative verb in present tense — `PlaceOrderCommand`, `CancelPaymentCommand`, `UpdateShippingAddressCommand`

**Query contract**:
- **Intent**: retrieve information
- **Returns**: data (DTO, list, count, bool)
- **Side effects**: none — must not change state
- **Idempotency**: always — `GetOrderById(42)` called 100 times always returns the same order (ignoring concurrent writes)
- **Named**: interrogative or noun — `GetOrderByIdQuery`, `GetCustomerOrdersQuery`, `OrderCountQuery`

### Why the Separation Matters

**Testing**:
```csharp
// Query: trivial to test — call once, assert result, no cleanup needed
[Fact]
public async Task GetOrderById_ExistingOrder_ReturnsDto()
{
    // No need to check side effects — there are none
    var result = await handler.Handle(new GetOrderByIdQuery(orderId: 1), ct);
    Assert.Equal(1, result.Id);
}

// Command: must verify state change AND clean up after test
[Fact]
public async Task PlaceOrder_ValidData_CreatesOrder()
{
    await handler.Handle(new PlaceOrderCommand(customerId: 1, total: 99m), ct);
    var savedOrder = await repo.GetByIdAsync(1, ct);
    Assert.NotNull(savedOrder); // ← verifying the side effect
    // cleanup required in DisposeAsync
}
```

**Caching**:
```csharp
// Queries can be safely cached — they have no side effects
public class CachingBehavior<TRequest, TResponse>(IMemoryCache cache)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IQuery<TResponse>  // ← only cache queries, never commands
{
    public async Task<TResponse> Handle(TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var key = $"query:{typeof(TRequest).Name}:{JsonSerializer.Serialize(req)}";
        if (cache.TryGetValue(key, out TResponse? cached)) return cached!;
        var result = await next();
        cache.Set(key, result, TimeSpan.FromMinutes(5));
        return result;
    }
}
```

**API Design**:
```csharp
// Commands → HTTP POST/PUT/PATCH/DELETE (state-changing)
app.MapPost("/api/orders", async (PlaceOrderCommand cmd, ISender s, CancellationToken ct)
    => Results.Created($"/api/orders/{await s.Send(cmd, ct)}", null));

app.MapDelete("/api/orders/{id}", async (int id, ISender s, CancellationToken ct)
    => { await s.Send(new CancelOrderCommand(id, "User request"), ct); return Results.NoContent(); });

// Queries → HTTP GET (idempotent, cacheable)
app.MapGet("/api/orders/{id}", async (int id, ISender s, CancellationToken ct)
    => Results.Ok(await s.Send(new GetOrderByIdQuery(id), ct)));

app.MapGet("/api/orders", async ([AsParameters] GetOrdersQuery q, ISender s, CancellationToken ct)
    => Results.Ok(await s.Send(q, ct)));
```

### Command Idempotency

When commands must be idempotent (e.g., payment processing, at-least-once delivery):

```csharp
// Idempotent command: include a client-supplied idempotency key
public record ProcessPaymentCommand(
    int OrderId,
    decimal Amount,
    Guid IdempotencyKey) : IRequest<PaymentResult>;  // ← client generates this key

public class ProcessPaymentHandler(IPaymentRepository payments)
    : IRequestHandler<ProcessPaymentCommand, PaymentResult>
{
    public async Task<PaymentResult> Handle(ProcessPaymentCommand cmd, CancellationToken ct)
    {
        // Check if already processed
        var existing = await payments.FindByIdempotencyKeyAsync(cmd.IdempotencyKey, ct);
        if (existing is not null) return existing.ToResult();  // ← idempotent replay

        var payment = Payment.Create(cmd.OrderId, cmd.Amount, cmd.IdempotencyKey);
        await payments.AddAsync(payment, ct);
        return new PaymentResult(payment.Id, PaymentStatus.Pending);
    }
}
```

## Code Example

```csharp
// Marker interfaces to separate commands from queries at the type level
public interface ICommand : IRequest { }
public interface ICommand<TResult> : IRequest<TResult> { }
public interface IQuery<TResult> : IRequest<TResult> { }

// Commands
public record PlaceOrderCommand(int CustomerId, decimal Total) : ICommand<int>;
public record CancelOrderCommand(int OrderId, string Reason) : ICommand;

// Queries
public record GetOrderQuery(int OrderId) : IQuery<OrderDto>;
public record GetOrdersQuery(int CustomerId, int Page = 1) : IQuery<PagedResult<OrderSummaryDto>>;

// Pipeline behavior applies ONLY to commands (not queries)
public class TransactionBehavior<TRequest, TResponse>(IUnitOfWork uow)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICommand  // ← only wraps commands in a transaction
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var result = await next();
        await uow.SaveChangesAsync(ct);  // ← safe: only for commands
        return result;
    }
}
```

## Common Follow-up Questions

- Should commands ever return data beyond an ID or status?
- How do you handle "fetch after create" — should a command return the created entity, or should the client issue a separate query?
- How do you implement idempotency for commands that must survive at-least-once delivery from a message broker?
- What happens to the query side in CQRS when the write side uses Event Sourcing?
- How do marker interfaces (ICommand, IQuery) help with pipeline behavior routing in MediatR?

## Common Mistakes / Pitfalls

- **Commands that return rich domain objects**: returning a full `OrderDto` from `PlaceOrderCommand` forces the handler to both change state and populate a read model, re-coupling the two sides.
- **Queries with side effects**: a `GetOrderQuery` that increments a view counter, logs access, or updates a last-accessed timestamp violates the query contract and makes the query non-cacheable.
- **Overloading queries as commands**: `GetOrCreateCustomerQuery` changes state ("create" if not exists) — it's actually a command, not a query.
- **Not applying idempotency to commands that need it**: in message-driven systems, any command might be delivered more than once. Commands that create resources (orders, payments) need idempotency key protection.

## References

- [CQS — Bertrand Meyer (Command Query Separation)](https://en.wikipedia.org/wiki/Command%E2%80%93query_separation) (verify URL)
- [CQRS — Martin Fowler](https://martinfowler.com/bliki/CQRS.html) (verify URL)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
