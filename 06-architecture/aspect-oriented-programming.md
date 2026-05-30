# Aspect-Oriented Programming

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🔴 Senior
**Tags:** `AOP`, `Castle-DynamicProxy`, `Decorator`, `interceptors`, `cross-cutting-concerns`, `IL-weaving`, `PostSharp`

## Question

> What is aspect-oriented programming (AOP) in .NET? Compare runtime proxy-based AOP (Castle DynamicProxy), compile-time IL weaving (PostSharp), and the Decorator pattern — trade-offs and when to use each.

## Short Answer

AOP separates cross-cutting concerns (logging, caching, transactions) from business logic by applying "aspects" — behaviors that execute before/after method calls. In .NET: **Castle DynamicProxy** generates proxy classes at runtime that intercept method calls, applied at DI registration (interface-based only). **PostSharp** weaves IL at compile time — can decorate any method without interface requirement, more powerful but adds build tooling. The **Decorator pattern** is AOP with compile-time type safety and no framework dependency — verbose but explicit and testable. For most .NET teams: Decorator via `Scrutor` is the pragmatic choice.

## Detailed Explanation

### Castle DynamicProxy (Runtime AOP)

```csharp
// NuGet: Castle.Core
// Works by generating a dynamic subclass/proxy that wraps all virtual method calls

// 1. Define an interceptor (the "aspect")
public class LoggingInterceptor(ILogger<LoggingInterceptor> log) : IInterceptor
{
    public void Intercept(IInvocation invocation)
    {
        var method = $"{invocation.TargetType.Name}.{invocation.Method.Name}";
        log.LogInformation("Before {Method}({Args})", method,
            string.Join(", ", invocation.Arguments));

        try
        {
            invocation.Proceed(); // ← call the real method

            // Handle async methods: invocation.ReturnValue is Task/ValueTask
            if (invocation.ReturnValue is Task task)
                invocation.ReturnValue = LogAfterAsync(task, method, log);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Exception in {Method}", method);
            throw;
        }
    }

    private static async Task LogAfterAsync(Task task, string method, ILogger log)
    {
        await task;
        log.LogInformation("After {Method}", method);
    }
}

// 2. Register with DI using Castle ProxyGenerator
builder.Services.AddSingleton<ProxyGenerator>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.Decorate<IOrderRepository>((inner, sp) =>
{
    var generator = sp.GetRequiredService<ProxyGenerator>();
    var interceptor = sp.GetRequiredService<LoggingInterceptor>();
    return generator.CreateInterfaceProxyWithTarget<IOrderRepository>(inner, interceptor);
});
```

### Decorator Pattern (Compile-Time AOP)

```csharp
// Type-safe, no framework required, works without interfaces
// Verbose but perfectly transparent to readers and IDEs

public class LoggingOrderRepository(
    IOrderRepository inner,
    ILogger<LoggingOrderRepository> log) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct)
    {
        log.LogDebug("GetById({Id}) starting", id);
        var result = await inner.GetByIdAsync(id, ct);
        log.LogDebug("GetById({Id}) → {Found}", id, result is not null ? "found" : "null");
        return result;
    }

    public Task AddAsync(Order order, CancellationToken ct) => inner.AddAsync(order, ct);
    public Task<IReadOnlyList<Order>> GetByCustomerAsync(int customerId, CancellationToken ct)
        => inner.GetByCustomerAsync(customerId, ct);
}

// Scrutor: auto-wires decorator without manual factory registration
services.AddScoped<IOrderRepository, OrderRepository>();
services.Decorate<IOrderRepository, LoggingOrderRepository>(); // ← wraps automatically
```

### PostSharp / AspectInjector (Compile-Time IL Weaving)

```csharp
// NuGet: AspectInjector (free, open-source alternative to PostSharp)
// Weaves aspects into IL at build time — no runtime overhead, no interface requirement

[Aspect(Scope.Global)]
[Injection(typeof(LoggingAspect))]
public class LoggingAspect : Attribute
{
    [Advice(Kind.Before, Targets = Target.Method)]
    public void Before([Argument(Source.Name)] string methodName,
                       [Argument(Source.Arguments)] object[] args)
        => Console.WriteLine($"Before {methodName}({string.Join(", ", args)})");

    [Advice(Kind.After, Targets = Target.Method)]
    public void After([Argument(Source.Name)] string methodName)
        => Console.WriteLine($"After {methodName}");
}

// Apply to any class/method — no interface required
[LoggingAspect]
public class OrderService
{
    public async Task<int> PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // ← Before() called here automatically by woven IL
        var order = await _orders.CreateAsync(cmd, ct);
        return order.Id;
        // ← After() called here automatically
    }
}
```

### Comparison

| | Decorator | Castle DynamicProxy | PostSharp/AspectInjector |
|--|-----------|--------------------|-----------------------|
| **Interface required** | ✅ Yes | ✅ Yes (or virtual) | ❌ No |
| **Type safety** | ✅ Full | ❌ Runtime | ✅ Compile-time |
| **IDE visibility** | ✅ Explicit | ❌ Hidden in proxy | ⚠️ Hidden in weaving |
| **Performance** | ✅ No overhead | 🟡 Reflection + proxy | ✅ Compiled in |
| **NuGet dependencies** | ❌ None needed | `Castle.Core` | `AspectInjector`/PostSharp |
| **Debugging** | ✅ Easy | 🟡 Stack trace includes proxy | ⚠️ IL modified |
| **Use for** | Most cases | Legacy DI decoration | Non-interface classes |

## Code Example

```csharp
// Scrutor Decorator + Castle Proxy: hybrid approach
// Use Decorator for well-defined interfaces, Castle Proxy for batch decoration

builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();

// Scrutor: explicit, type-safe decorator for critical interface
builder.Services.Decorate<IOrderRepository, CachingOrderRepository>();
builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();

// Castle Proxy: batch-apply logging to ALL services implementing IApplicationService
builder.Services.AddScoped<ProxyGenerator>();
// (Register all IApplicationService implementations, then decorate via loop with Castle)
foreach (var serviceType in GetApplicationServiceTypes())
{
    builder.Services.Decorate(serviceType, (inner, sp) =>
        sp.GetRequiredService<ProxyGenerator>()
          .CreateInterfaceProxyWithTarget(serviceType, inner,
            sp.GetRequiredService<LoggingInterceptor>()));
}
```

## Common Follow-up Questions

- How does Castle DynamicProxy handle async methods — is there a special interceptor base class?
- What is the difference between `IInterceptor.Proceed()` for async vs sync methods?
- How do you test code decorated with AOP aspects — do the aspects fire in unit tests?
- When is compile-time IL weaving worth the tooling investment?
- How does `DispatchProxy` in .NET relate to Castle DynamicProxy?

## Common Mistakes / Pitfalls

- **Castle DynamicProxy on non-virtual methods**: DynamicProxy can only intercept `virtual` or `interface` methods. Non-virtual methods are silently bypassed — use AspectInjector or Decorator for those.
- **Async interceptors that don't await**: a synchronous interceptor calling `invocation.Proceed()` where the return value is `Task` — if you don't `await task`, exceptions are swallowed and logging is inaccurate.
- **AOP hiding important side effects**: `[Transactional]` applied via AOP makes it non-obvious that a method is wrapped in a DB transaction. Prefer explicit transaction management in application handlers unless the team is well-trained in AOP conventions.
- **Decorator stack explosion**: registering 5+ decorators on one interface creates deep call stacks, making debugging painful. Keep decorator layers shallow (2–3 max per interface).

## References

- [Castle DynamicProxy](https://github.com/castleproject/Core)
- [AspectInjector](https://github.com/pamidur/aspect-injector)
- [Scrutor — Decorator extension](https://github.com/khellang/Scrutor)
- [See: cross-cutting-concerns-overview.md](./cross-cutting-concerns-overview.md)
- [See: cross-cutting-via-pipeline.md](./cross-cutting-via-pipeline.md)
