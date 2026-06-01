# DI Fundamentals in ASP.NET Core

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟢 Junior
**Tags:** `DI`, `IServiceCollection`, `IServiceProvider`, `AddSingleton`, `AddScoped`, `AddTransient`, `constructor-injection`

## Question

> How does dependency injection work in ASP.NET Core? What is the difference between `AddSingleton`, `AddScoped`, and `AddTransient`?

## Short Answer

ASP.NET Core has a built-in IoC container. Services are registered in `IServiceCollection` using `AddSingleton`, `AddScoped`, or `AddTransient` (controlling how many instances are created and their lifetime), and then resolved via constructor injection or `IServiceProvider`. The container is built once at startup and is immutable after that.

## Detailed Explanation

### Registration

```csharp
builder.Services.AddSingleton<IMyService, MyService>();    // one instance for app lifetime
builder.Services.AddScoped<IUserRepository, UserRepository>(); // one per request
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>(); // new instance each resolve
```

### The three lifetimes

| Lifetime | Instance created | Disposed |
|---|---|---|
| **Singleton** | Once per app lifetime | On app shutdown |
| **Scoped** | Once per DI scope (= per HTTP request in ASP.NET Core) | End of scope |
| **Transient** | Every time `GetService<T>()` is called | End of enclosing scope |

### Constructor injection

The container resolves dependencies automatically by inspecting constructor parameters:

```csharp
public class OrderService(IOrderRepository repo, IEmailSender emailSender)
{
    // Both dependencies injected automatically by the container
}
```

The container always picks the **greediest constructor** (most parameters it can satisfy). If no constructor can be fully satisfied, it throws at resolve time (or if scope validation is enabled, at build time).

### `IServiceProvider` — manual resolution

```csharp
// In non-DI contexts (middleware, program.cs)
var service = app.Services.GetRequiredService<IMyService>();
// GetService<T> returns null if not registered; GetRequiredService<T> throws
```

Avoid `IServiceProvider` in application code (service locator anti-pattern). Use it only in infrastructure code (factories, middleware activators).

### Key registration overloads

```csharp
// Implementation type only (resolved as itself)
services.AddSingleton<MyConcreteService>();

// Interface → implementation
services.AddScoped<IUserRepo, SqlUserRepo>();

// Factory delegate (for complex construction logic)
services.AddScoped<IUserRepo>(sp =>
{
    var config = sp.GetRequiredService<IOptions<DbOptions>>().Value;
    return new SqlUserRepo(config.ConnectionString);
});

// Instance (pre-created; always Singleton)
services.AddSingleton<IConfig>(new AppConfig { ApiKey = "..." });

// Multiple implementations for the same interface
services.AddTransient<INotifier, EmailNotifier>();
services.AddTransient<INotifier, SmsNotifier>();
// Resolve all: IEnumerable<INotifier>
```

### Scope validation

In Development, the container validates on `BuildServiceProvider(validateScopes: true)`:
- Detects Scoped services resolved from the root (Singleton) scope.
- Detects Transient services captured by Singletons.

```csharp
// Enable in production if needed:
builder.Host.UseDefaultServiceProvider(opts =>
    opts.ValidateScopes = true);
```

## Code Example

```csharp
// IOrderRepository.cs
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
}

// SqlOrderRepository.cs
public sealed class SqlOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders.FindAsync([id], ct).AsTask();
}

// OrderService.cs
public sealed class OrderService(
    IOrderRepository repo,
    ILogger<OrderService> logger)
{
    public async Task<Order> GetOrderAsync(int id)
    {
        logger.LogDebug("Fetching order {Id}", id);
        return await repo.GetByIdAsync(id)
            ?? throw new NotFoundException($"Order {id} not found");
    }
}

// Program.cs
builder.Services.AddDbContext<AppDbContext>(opts =>         // Scoped (default for DbContext)
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IOrderRepository, SqlOrderRepository>(); // Scoped
builder.Services.AddScoped<OrderService>();                          // Scoped

// Resolve in a controller (constructor injection — no service locator)
[ApiController, Route("api/orders")]
public class OrdersController(OrderService orderService) : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
        => Ok(await orderService.GetOrderAsync(id));
}
```

## Common Follow-up Questions

- What is the "captive dependency" problem, and how does scope validation help?
- When should you use a factory registration (`services.Add*(sp => ...)`) instead of a type mapping?
- How do you resolve all implementations of an interface (`IEnumerable<T>`)?
- What is the difference between `GetService<T>` and `GetRequiredService<T>`?
- How do you replace a service registration in tests with `WebApplicationFactory`?

## Common Mistakes / Pitfalls

- **Injecting Scoped into Singleton** — the Scoped instance is captured for the app lifetime, becoming effectively Singleton (captive dependency). Use `IServiceScopeFactory` in Singletons.
- **Using `IServiceProvider` inside business logic** — this is the Service Locator anti-pattern; it hides dependencies and makes testing harder.
- **Registering the wrong lifetime for `DbContext`** — `DbContext` is not thread-safe and must be Scoped. Registering as Singleton causes concurrency bugs.
- **Calling `BuildServiceProvider()` manually in `Program.cs`** — this creates a second root container, losing scope validation and potentially causing double-registration side effects.
- **Forgetting that `AddSingleton` with a factory captures the factory delegate, not the result** — the delegate runs once; if it has side effects, they run only on first resolve.

## References

- [Microsoft Learn — Dependency injection in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-8.0)
- [Microsoft Learn — Service lifetimes](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection#service-lifetimes)
- [Andrew Lock — Understanding service lifetimes in ASP.NET Core](https://andrewlock.net/tag/di/) (verify URL)
- [Microsoft — ServiceProvider source (GitHub)](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection/src/ServiceProvider.cs)
