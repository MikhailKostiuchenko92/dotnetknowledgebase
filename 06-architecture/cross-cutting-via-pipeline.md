# Cross-Cutting Concerns via Pipeline

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🟡 Middle
**Tags:** `MediatR`, `IPipelineBehavior`, `cross-cutting`, `AOP`, `decorator`, `validation`, `logging`, `caching`, `transaction`

## Question

> What cross-cutting concerns are best handled via the MediatR pipeline, and how does this relate to the Decorator pattern and AOP? Give examples of validation, logging, caching, and transaction behaviors.

## Short Answer

The MediatR pipeline is an implementation of the **Decorator pattern** (or chain of responsibility): each `IPipelineBehavior<TRequest, TResponse>` wraps the next handler, adding behavior before and after. This achieves **Aspect-Oriented Programming (AOP)** without IL weaving — cross-cutting concerns (validation, logging, caching, transactions) are added to the pipeline once and apply to all matching requests. This keeps individual handlers clean: `PlaceOrderHandler` only has business logic — no try/catch, no logging calls, no validation code.

## Detailed Explanation

### The Decorator Pattern Connection

```
Before MediatR pipeline (manual decorators):
  LoggingOrderHandler wraps ValidationOrderHandler wraps PlaceOrderHandler
  → Needed for every handler — extreme boilerplate

With MediatR pipeline:
  LoggingBehavior<TRequest, TResponse>    (registered once — wraps ALL handlers)
  ValidationBehavior<TRequest, TResponse> (registered once — validates ALL requests)
  PlaceOrderHandler                       (pure business logic only)
```

### AOP Without IL Weaving

Traditional AOP (PostSharp, Castle DynamicProxy) modifies compiled IL or uses runtime proxies. MediatR's pipeline achieves the same effect:

```csharp
// Before AOP/pipeline: validation scattered everywhere
public class OrderHandler { 
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Cross-cutting code in every handler:
        if (cmd.CustomerId <= 0) throw new ValidationException("Invalid customer");
        if (cmd.Total <= 0) throw new ValidationException("Invalid total");
        _logger.LogInformation("Handling {Request}", cmd);
        // ... actual business logic
    }
}

// After pipeline: handler is pure business logic
public class OrderHandler : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Only business logic — validation/logging done by pipeline
        var order = Order.Create(new CustomerId(cmd.CustomerId), new Money(cmd.Total));
        await _orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}
```

### Validation Behavior (FluentValidation)

```csharp
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var failures = validators
            .Select(v => v.Validate(new ValidationContext<TRequest>(req)))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0) throw new ValidationException(failures);
        return await next();
    }
}

// FluentValidation validator co-located with the command
public class PlaceOrderCommandValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).GreaterThan(0).WithMessage("Customer ID is required");
        RuleFor(x => x.Total).GreaterThan(0).WithMessage("Order total must be positive");
    }
}
```

### Transaction Behavior (Commands Only)

```csharp
// Marker interface: only commands get transaction wrapping
public interface ITransactionalCommand { }

public class TransactionBehavior<TRequest, TResponse>(IUnitOfWork uow)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ITransactionalCommand
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var response = await next();    // ← handler executes, accumulates EF Core changes
        await uow.SaveChangesAsync(ct); // ← commit once after handler completes
        return response;
    }
}

// Command opts in with marker interface
public record PlaceOrderCommand(int CustomerId, decimal Total)
    : IRequest<int>, ITransactionalCommand; // ← gets wrapped in TransactionBehavior
```

### Caching Behavior (Queries Only)

```csharp
public interface ICacheable
{
    string CacheKey { get; }
    TimeSpan Ttl { get; }
}

public class CachingBehavior<TRequest, TResponse>(IDistributedCache cache, ILogger<CachingBehavior<TRequest, TResponse>> log)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICacheable
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var cachedBytes = await cache.GetAsync(req.CacheKey, ct);
        if (cachedBytes is not null)
        {
            log.LogDebug("Cache hit for {Key}", req.CacheKey);
            return JsonSerializer.Deserialize<TResponse>(cachedBytes)!;
        }

        var result = await next();
        await cache.SetAsync(req.CacheKey,
            JsonSerializer.SerializeToUtf8Bytes(result),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = req.Ttl }, ct);
        return result;
    }
}

public record GetProductsQuery(string? Category) : IRequest<List<ProductDto>>, ICacheable
{
    public string CacheKey => $"products:{Category ?? "all"}";
    public TimeSpan Ttl => TimeSpan.FromMinutes(5);
}
```

## Code Example

```csharp
// Registration order determines pipeline order (first = outermost)
// Recommended order for most applications:
services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());
services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));       // ← 1st: log all
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(PerformanceBehavior<,>));   // ← 2nd: measure
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));    // ← 3rd: validate
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(CachingBehavior<,>));       // ← 4th: cache check (queries)
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));   // ← 5th: transaction (commands)
```

## Common Follow-up Questions

- How do you apply a behavior to only a subset of request types?
- What is `RequestPreProcessor<T>` and `RequestPostProcessor<T>` — how do they differ from `IPipelineBehavior`?
- How do you unit test pipeline behaviors in isolation?
- Can behaviors be conditionally registered or enabled?
- How do you pass correlation data (e.g., current user) through the pipeline without cluttering every request type?

## Common Mistakes / Pitfalls

- **Heavy behaviors on all requests**: a caching behavior on every `IRequest` including commands that should never be cached. Use marker interfaces (`ICacheable`) to restrict behaviors.
- **Behaviors that swallow exceptions**: a catch-all behavior that returns `default(TResponse)` on any exception prevents proper HTTP status codes and error logging.
- **Logging sensitive request data**: `{@Request}` in Serilog serializes the entire command, including passwords, card numbers, and PII. Implement `IDestructuringPolicy` or exclude sensitive properties.
- **Transaction behavior before validation**: if `TransactionBehavior` is registered before `ValidationBehavior`, invalid requests open DB transactions before failing validation — wasteful.

## References

- [MediatR pipeline behaviors — GitHub Wiki](https://github.com/jbogard/MediatR/wiki/Behaviors)
- [Decorator pattern as AOP — refactoring.guru](https://refactoring.guru/design-patterns/decorator) (verify URL)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
