# Factory Registration in DI

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟡 Middle
**Tags:** `DI`, `factory`, `Func-factory`, `lazy-resolution`, `IServiceProvider`

## Question

> How do you register services with a factory delegate in ASP.NET Core DI, and when would you use `Func<T>` factory injection or `Lazy<T>` resolution?

## Short Answer

Factory registration (`services.AddScoped<T>(sp => new T(...))`  lets you inject services that require custom construction logic, runtime parameters, or conditional implementations. Injecting `Func<T>` as a factory delegate defers creation to call time and supports multiple instances per scope. `Lazy<T>` defers creation until first use. For named/keyed services in .NET 8+, prefer keyed services over `Func<string, T>` factories.

## Detailed Explanation

### Basic factory registration

```csharp
// Simple factory lambda
services.AddScoped<IDbConnection>(sp =>
{
    var config = sp.GetRequiredService<IOptions<DbOptions>>().Value;
    return new SqlConnection(config.ConnectionString);
});
```

The lambda receives `IServiceProvider` and returns the service instance. This is useful when:
- Construction requires parameters not available via DI (e.g., connection strings, runtime values).
- The service implements multiple interfaces and you need different registrations.
- You want conditional logic (e.g., mock vs real implementation based on config).

### Conditional factory

```csharp
services.AddSingleton<IEmailSender>(sp =>
{
    var env = sp.GetRequiredService<IWebHostEnvironment>();
    return env.IsDevelopment()
        ? new FileSystemEmailSender(sp.GetRequiredService<ILogger<FileSystemEmailSender>>())
        : new SmtpEmailSender(sp.GetRequiredService<IOptions<SmtpOptions>>());
});
```

### `Func<T>` factory injection

Register a `Func<T>` delegate when callers need to create multiple instances on demand:

```csharp
// Register factory function
services.AddTransient<IReport, PdfReport>(); // the concrete type

services.AddSingleton<Func<IReport>>(sp =>
    () => sp.GetRequiredService<IReport>());
```

```csharp
// Consumer — creates a new report on each call
public class ReportBatchProcessor(Func<IReport> reportFactory)
{
    public async Task ProcessAsync(IEnumerable<ReportRequest> requests)
    {
        foreach (var req in requests)
        {
            var report = reportFactory(); // fresh instance each time
            await report.GenerateAsync(req);
        }
    }
}
```

> **Warning:** When `Func<T>` resolves from the root `IServiceProvider`, Scoped services are resolved from the root scope — they never get disposed. Always resolve from a freshly created scope if the factory creates Scoped services.

### `Func<string, T>` named factory (pre-.NET 8 pattern)

```csharp
// Register named services via Func factory
services.AddTransient<IPaymentGateway, StripeGateway>();
services.AddTransient<IPaymentGateway, PayPalGateway>(); // last wins for direct resolve

services.AddSingleton<Func<string, IPaymentGateway>>(sp => name =>
    name switch
    {
        "stripe" => sp.GetServices<IPaymentGateway>().OfType<StripeGateway>().First(),
        "paypal" => sp.GetServices<IPaymentGateway>().OfType<PayPalGateway>().First(),
        _        => throw new ArgumentException($"Unknown gateway: {name}")
    });
```

In .NET 8+, prefer [keyed services](keyed-services.md) over this pattern.

### `Lazy<T>` for deferred resolution

The built-in container does not natively support `Lazy<T>`, but you can register it:

```csharp
services.AddTransient(typeof(Lazy<>), typeof(LazyService<>));

// Helper wrapper
public sealed class LazyService<T>(IServiceProvider sp) : Lazy<T>(() =>
    sp.GetRequiredService<T>());
```

```csharp
// Consumer — heavy service only created if the code path runs
public class OrderService(Lazy<IReportingService> lazyReporter)
{
    public async Task ProcessAsync(Order order)
    {
        if (order.RequiresAudit)
            lazyReporter.Value.LogOrderAsync(order);  // created on first access
    }
}
```

### When to use which pattern

| Pattern | Use when |
|---|---|
| Simple factory lambda | Construction needs custom logic or config |
| `Func<T>` injection | Multiple instances needed on demand |
| `Func<string, T>` | Named implementations (.NET 7 and earlier) |
| Keyed services (.NET 8+) | Named implementations (preferred, see [keyed-services.md](keyed-services.md)) |
| `Lazy<T>` | Expensive service that may not be needed |

## Code Example

```csharp
// ConnectionFactory.cs — proper factory with scope management
public sealed class ConnectionFactory(IServiceScopeFactory scopeFactory)
{
    public async Task<T> ExecuteAsync<T>(
        Func<IDbConnection, Task<T>> work)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var connection = scope.ServiceProvider.GetRequiredService<IDbConnection>();
        return await work(connection);
    }
}
```

```csharp
// Program.cs — registering with factory lambda
builder.Services.AddTransient<IDbConnection>(sp =>
{
    var opts = sp.GetRequiredService<IOptions<DatabaseOptions>>().Value;
    var conn = new SqlConnection(opts.ConnectionString);
    return conn;
    // Note: SqlConnection will be disposed when scope ends (it's IDisposable)
});

builder.Services.AddSingleton<ConnectionFactory>();

// Named cache factory (using Func<string, T>)
builder.Services.AddKeyedSingleton<ICache, MemoryCache>("local");
builder.Services.AddKeyedSingleton<ICache, RedisCache>("distributed");
// In .NET 8+, use keyed services instead of Func<string, ICache>
```

```csharp
// ICache implementations
public interface ICache
{
    Task<T?> GetAsync<T>(string key, CancellationToken ct = default);
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null, CancellationToken ct = default);
}

// Service using factory to pick cache implementation at runtime
public class ProductService(
    [FromKeyedServices("local")] ICache localCache,
    [FromKeyedServices("distributed")] ICache distributedCache,
    IProductRepository repo)
{
    public async Task<Product?> GetAsync(int id, bool useLocal = true)
    {
        var cache = useLocal ? localCache : distributedCache;
        return await cache.GetAsync<Product>($"product:{id}")
            ?? await repo.GetByIdAsync(id);
    }
}
```

## Common Follow-up Questions

- How does the `Func<T>` factory interact with scope lifetimes — is the created instance Scoped or Singleton?
- When does a factory-registered service get disposed — who calls `IDisposable.Dispose()`?
- How do you register a service that needs `async` initialization before it can be used?
- How do you mock a `Func<T>` factory in a unit test?
- What is the `ActivatorUtilities.CreateInstance<T>()` method and when is it useful?

## Common Mistakes / Pitfalls

- **Capturing `IServiceProvider` in a factory closure without creating a scope** — if the factory creates Scoped services from the root provider, they are never disposed (captive Scoped as root Singleton).
- **Registering `Func<T>` as Singleton but `T` as Scoped** — calling the factory from a Singleton creates a root-scoped instance of `T` that lives forever.
- **Using factory lambdas for simple type mappings** — `AddScoped<IFoo>(sp => new FooImpl(...))` when `AddScoped<IFoo, FooImpl>()` suffices adds unnecessary complexity.
- **`Func<T>` returning `new T()` without using `sp`** — bypasses the DI container, so `T`'s own dependencies are not injected.
- **Forgetting that `IDisposable` returned from a factory is still tracked** — the container disposes `IDisposable` instances it created, even via factory. Don't dispose them manually in the factory.

## References

- [Microsoft Learn — Service registration methods](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection#service-registration-methods)
- [Microsoft Learn — Dependency injection guidelines](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Andrew Lock — Factory-based registration patterns](https://andrewlock.net/tag/di/) (verify URL)
- [Microsoft — ActivatorUtilities](https://learn.microsoft.com/dotnet/api/microsoft.extensions.dependencyinjection.activatorutilities?view=dotnet-plat-ext-8.0)
