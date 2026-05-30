# Pipeline Behaviors in MediatR

**Category:** Architecture / CQRS
**Difficulty:** 🟡 Middle
**Tags:** `MediatR`, `IPipelineBehavior`, `cross-cutting`, `validation`, `logging`, `caching`, `transaction`, `pipeline`

## Question

> What is `IPipelineBehavior<TRequest, TResponse>` in MediatR? How do you implement common cross-cutting concerns — validation, logging, caching, and transactions — as pipeline behaviors? In what order do behaviors execute?

## Short Answer

`IPipelineBehavior<TRequest, TResponse>` is MediatR's middleware pattern for request handling — analogous to ASP.NET Core middleware for HTTP. Each behavior wraps the next handler in the chain: it can run code before the request (validation, logging start), call `next()` to proceed, and run code after (log duration, commit transaction, cache result). Behaviors are registered in DI and execute in **registration order**: the first registered is the outermost wrapper. Common behaviors: logging (outermost), validation (before handler), transaction (around handler), caching (bypass handler on hit).

## Detailed Explanation

### Pipeline Execution Order

```
Request
  → LoggingBehavior (registered first = outermost)
    → ValidationBehavior
      → TransactionBehavior (registered last = innermost)
        → Handler.Handle()
      ← TransactionBehavior (commit or rollback)
    ← ValidationBehavior
  ← LoggingBehavior (log elapsed time)
Response
```

Registration order determines wrapping order:
```csharp
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));      // outermost
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));   // innermost
```

### Logging Behavior

```csharp
public class LoggingBehavior<TRequest, TResponse>(ILogger<LoggingBehavior<TRequest, TResponse>> log)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var requestName = typeof(TRequest).Name;
        log.LogInformation("Handling {RequestName}: {@Request}", requestName, req);

        var sw = Stopwatch.StartNew();
        try
        {
            var response = await next();
            log.LogInformation("Handled {RequestName} in {ElapsedMs}ms", requestName, sw.ElapsedMilliseconds);
            return response;
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Error handling {RequestName}", requestName);
            throw;
        }
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

        var context = new ValidationContext<TRequest>(req);
        var failures = validators
            .Select(v => v.Validate(context))
            .SelectMany(r => r.Errors)
            .Where(e => e is not null)
            .ToList();

        if (failures.Count > 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### Transaction Behavior (Commands Only)

```csharp
// Apply only to commands, not queries — use marker interface
public interface ICommand : IRequest { }
public interface ICommand<T> : IRequest<T> { }

public class TransactionBehavior<TRequest, TResponse>(IUnitOfWork uow)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICommand  // ← only wraps commands
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var response = await next();
        await uow.SaveChangesAsync(ct);  // ← commit after handler succeeds
        return response;
    }
}
```

### Caching Behavior (Queries Only)

```csharp
public interface ICacheable
{
    string CacheKey { get; }
    TimeSpan CacheDuration { get; }
}

public class CachingBehavior<TRequest, TResponse>(IMemoryCache cache)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICacheable
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (cache.TryGetValue(req.CacheKey, out TResponse? cached))
        {
            return cached!;  // ← cache hit: bypass handler entirely
        }

        var result = await next();
        cache.Set(req.CacheKey, result, req.CacheDuration);
        return result;
    }
}

// Query opts into caching by implementing ICacheable
public record GetProductsQuery(string? Search) : IQuery<List<ProductDto>>, ICacheable
{
    public string CacheKey => $"products:{Search ?? "all"}";
    public TimeSpan CacheDuration => TimeSpan.FromMinutes(10);
}
```

### Performance Monitoring Behavior

```csharp
public class PerformanceBehavior<TRequest, TResponse>(ILogger<PerformanceBehavior<TRequest, TResponse>> log)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private const int SlowRequestThresholdMs = 500;

    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        var response = await next();

        if (sw.ElapsedMilliseconds > SlowRequestThresholdMs)
            log.LogWarning("Slow request: {RequestName} ({Elapsed}ms) — {@Request}",
                typeof(TRequest).Name, sw.ElapsedMilliseconds, req);

        return response;
    }
}
```

## Code Example

```csharp
// Full DI registration with recommended ordering
services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());

services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();

// Registration order = pipeline order (first = outermost)
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(PerformanceBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(CachingBehavior<,>));     // only for ICacheable
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>)); // only for ICommand
```

## Common Follow-up Questions

- How do you restrict a pipeline behavior to only certain request types (commands vs queries)?
- What is the difference between `IPipelineBehavior` and `RequestPreProcessor`/`RequestPostProcessor`?
- How do you unit test pipeline behaviors in isolation?
- How do you handle `CancellationToken` propagation through the behavior chain?
- What is the performance overhead of pipeline behaviors, and when is it worth optimizing?

## Common Mistakes / Pitfalls

- **Transaction behavior on queries**: wrapping `GetOrdersQuery` in a transaction behavior is wasteful. Use the `ICommand` marker interface to restrict transaction wrapping to commands only.
- **Behavior order placing validation after transaction**: registering `TransactionBehavior` before `ValidationBehavior` opens a DB transaction before knowing if the request is valid.
- **Logging sensitive data**: `log.LogInformation("{@Request}", req)` serializes the entire request object. Commands containing passwords, card numbers, or PII must be scrubbed before logging.
- **Exception handling behavior hiding important errors**: a behavior that catches all exceptions and returns default results prevents proper HTTP status codes and error tracking.

## References

- [MediatR Pipeline Behaviors — GitHub Wiki](https://github.com/jbogard/MediatR/wiki/Behaviors)
- [CQRS pipeline with FluentValidation — Andrew Lock](https://andrewlock.net/adding-validation-to-a-mediatr-pipeline-with-a-new-custom-notification-handler/) (verify URL)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: command-validation-pipeline.md](./command-validation-pipeline.md)
- [See: cross-cutting-via-pipeline.md](./cross-cutting-via-pipeline.md)
