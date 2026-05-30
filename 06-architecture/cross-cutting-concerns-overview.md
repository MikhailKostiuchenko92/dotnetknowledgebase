# Cross-Cutting Concerns Overview

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟢 Junior
**Tags:** `cross-cutting-concerns`, `AOP`, `middleware`, `pipeline`, `separation-of-concerns`, `DRY`

## Question

> What are cross-cutting concerns in software architecture? Give common examples and explain the main strategies for handling them — middleware, decorators, pipeline behaviors, and AOP.

## Short Answer

Cross-cutting concerns are aspects of a program that affect multiple modules but cannot be cleanly decomposed using standard OOP decomposition — they "cut across" the primary decomposition. Examples: logging, authentication, validation, caching, error handling, transaction management, audit trails. The problem: if you put logging in every service method, you violate DRY and mix infrastructure code with business logic. Strategies: **Middleware** (HTTP pipeline), **Decorator pattern** (wrap any interface), **MediatR pipeline behaviors** (for CQRS), **AOP** (aspect-oriented: compile-time or runtime IL weaving).

## Detailed Explanation

### What Makes a Concern "Cross-Cutting"

```
Primary decomposition (by business capability):
  Orders module, Inventory module, Customers module

Cross-cutting concern: needs to appear in ALL modules
  ✗ Every OrderHandler needs logging
  ✗ Every handler needs validation
  ✗ Every DB call needs a transaction
  ✗ Every HTTP call needs auth check

Without cross-cutting handling:
  public class PlaceOrderHandler
  {
      public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
      {
          // Not business logic:
          _logger.LogInformation("Handling PlaceOrder for customer {Id}", cmd.CustomerId);
          var results = _validator.Validate(cmd);
          if (!results.IsValid) throw new ValidationException(results);
          using var tx = _db.BeginTransaction();

          // Actual business logic (3 lines):
          var order = Order.Create(cmd.CustomerId, cmd.Lines);
          await _orders.AddAsync(order, ct);
          await _db.SaveChangesAsync(ct);

          tx.Commit();
          return order.Id;
          // End not business logic:
      }
  }
```

### Strategy 1: Middleware (HTTP Pipeline)

```csharp
// Applied to all HTTP requests at the framework level
app.UseAuthentication();     // ← auth cross-cutting concern
app.UseAuthorization();      // ← authz cross-cutting concern
app.UseRequestLogging();     // ← logging for all requests
app.UseRateLimiting();        // ← rate limiting for all requests
app.UseExceptionHandler();   // ← global error handling

// Custom middleware
public class CorrelationIdMiddleware(RequestDelegate next) : IMiddleware
{
    public async Task InvokeAsync(HttpContext ctx, RequestDelegate _)
    {
        ctx.TraceIdentifier = ctx.Request.Headers["X-Correlation-Id"].FirstOrDefault()
            ?? Guid.NewGuid().ToString("N");
        ctx.Response.Headers["X-Correlation-Id"] = ctx.TraceIdentifier;
        await next(ctx);
    }
}
```

### Strategy 2: Decorator Pattern

```csharp
// Wrap a service to add cross-cutting behavior without modifying it
public class LoggingOrderRepository(IOrderRepository inner, ILogger<LoggingOrderRepository> log)
    : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct)
    {
        log.LogDebug("GetById {Id}", id);
        var result = await inner.GetByIdAsync(id, ct);
        log.LogDebug("GetById {Id} returned {Result}", id, result?.Id);
        return result;
    }
    // ... other methods delegate to inner
}

// Register with Scrutor (auto-wiring decorator)
services.AddScoped<IOrderRepository, OrderRepository>();
services.Decorate<IOrderRepository, LoggingOrderRepository>();
```

### Strategy 3: MediatR Pipeline Behaviors

```csharp
// Applied to ALL command/query handlers via registration order
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));

// Handler is now pure business logic — all cross-cutting in behaviors
public class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // ONLY business logic here
        var order = Order.Create(cmd.CustomerId, cmd.Lines);
        await _orders.AddAsync(order, ct);
        return order.Id;
    }
}
```

### Strategy 4: AOP (Aspect-Oriented Programming)

```
AOP approaches in .NET:
  1. Castle DynamicProxy (runtime): generates proxy at runtime via reflection
     → Intercepts method calls, applies interceptors
     → Works with interface-based injection
  
  2. PostSharp / AspectInjector (compile-time): weaves IL during build
     → Can decorate any method (even non-virtual)
     → More powerful, but adds build complexity

  3. Roslyn Source Generators (.NET 5+)
     → Generate boilerplate at compile time without runtime overhead
     → Custom tooling required
```

### Choosing the Right Strategy

| Concern | Best Strategy | Why |
|---------|--------------|-----|
| HTTP auth, CORS, rate limit | Middleware | Applied before routing, HTTP-level |
| CQRS command logging/validation | Pipeline behavior | Applied to all handlers uniformly |
| Service interface decoration | Decorator (Scrutor) | Wraps any interface |
| General cross-cutting (no interface) | AOP / source gen | Needed for non-interface code |
| Domain-level invariants | Domain guard clauses | Business logic, not cross-cutting |

## Code Example

```csharp
// Clean handler after separating cross-cutting concerns
// Before: handler with logging + validation + transaction = 30 lines
// After: handler is pure business logic

[HttpPost("api/orders")]
public Task<int> PlaceOrder([FromBody] PlaceOrderCommand cmd, CancellationToken ct)
    => _sender.Send(cmd, ct);
// ↑ Validation (ValidationBehavior), logging (LoggingBehavior),
//   transaction (TransactionBehavior) all happen before Handle() is called
```

## Common Follow-up Questions

- When does separating cross-cutting concerns into behaviors/middleware hurt readability?
- How do you debug when a cross-cutting behavior changes the expected outcome?
- What is the difference between AOP and the Decorator pattern?
- How do you apply a cross-cutting concern to only a subset of handlers or routes?
- What is the "Service Locator" anti-pattern, and how does it relate to cross-cutting concerns?

## Common Mistakes / Pitfalls

- **Business rules treated as cross-cutting concerns**: "only managers can cancel orders" is a business rule — it belongs in the domain or application handler, not in a generic behavior.
- **Too many pipeline behaviors**: registering 8 behaviors makes request traces hard to follow. Keep the number small (4–5 max) and well-named.
- **Middleware with business logic**: putting business logic in ASP.NET Core middleware couples it to HTTP — becomes untestable without an HTTP context. Keep middleware thin; delegate to application services.
- **AOP hiding critical side effects**: a method decorated with `[Transactional]` via AOP is less obvious to readers than `await _uow.SaveChangesAsync()` in code. Use AOP judiciously for truly horizontal concerns only.

## References

- [Cross-cutting concerns — Wikipedia](https://en.wikipedia.org/wiki/Cross-cutting_concern)
- [Scrutor — Decorator registration](https://github.com/khellang/Scrutor)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
- [See: cross-cutting-via-pipeline.md](./cross-cutting-via-pipeline.md)
- [See: aspect-oriented-programming.md](./aspect-oriented-programming.md)
