# Service Lifetimes — Singleton, Scoped, and Transient

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟢 Junior
**Tags:** `DI`, `singleton`, `scoped`, `transient`, `lifetime`, `scope-validation`

## Question

> Explain the difference between Singleton, Scoped, and Transient service lifetimes in ASP.NET Core. When should you use each?

## Short Answer

**Singleton** — one instance shared for the entire application lifetime; use for stateless/thread-safe services (configuration, caches, HTTP clients). **Scoped** — one instance per DI scope (one per HTTP request in web apps); use for DbContext, repositories, per-request state. **Transient** — a new instance on every resolution; use for lightweight stateless operations where sharing would cause issues. The most common source of bugs is accidentally creating a captive dependency by injecting a shorter-lived service into a longer-lived one.

## Detailed Explanation

### Singleton

```csharp
services.AddSingleton<IMemoryCache, MemoryCache>();
```

- Created **once** at first resolution; reused for the application's entire lifetime.
- Disposed only when the root `IServiceProvider` is disposed (app shutdown).
- Must be **thread-safe** — multiple requests access the same instance concurrently.
- Ideal for: caches, configuration wrappers, `HttpClient` wrappers, connection pools.

### Scoped

```csharp
services.AddScoped<AppDbContext>();
services.AddScoped<IUnitOfWork, UnitOfWork>();
```

- Created **once per scope**. In ASP.NET Core, one scope = one HTTP request.
- Disposed at the end of the scope (end of request).
- All components resolved within the same scope share the same instance.
- Ideal for: `DbContext`, repositories, per-request state, transaction coordinators.

### Transient

```csharp
services.AddTransient<IEmailSender, SmtpEmailSender>();
```

- A **new instance** every time `GetService<T>()` is called.
- Disposed at the end of the enclosing scope (not immediately on resolution).
- Ideal for: stateless services, lightweight operations, validators.
- **Caution:** each resolution allocates a new instance; avoid for heavyweight objects.

### The captive dependency problem

A **captive dependency** occurs when a longer-lived service holds a reference to a shorter-lived one:

```
Singleton  →  Scoped   ← PROBLEM: Scoped is captured for app lifetime
Singleton  →  Transient ← PROBLEM: Transient becomes effectively Singleton
Scoped     →  Transient ← OK: Transient disposed with scope
```

```csharp
// BUG: ApplicationCache is Singleton, but IUserRepository is Scoped
public sealed class ApplicationCache(IUserRepository repo) { ... }
// IUserRepository is captured at first resolve and reused across all requests
```

**Fix:** Use `IServiceScopeFactory` to create a scope on demand inside Singleton services.

### Scope validation (catch problems early)

```csharp
// Enabled automatically in Development via CreateDefaultBuilder
builder.Host.UseDefaultServiceProvider(opts =>
{
    opts.ValidateScopes = true;   // throws if Scoped resolved from root
    opts.ValidateOnBuild = true;  // throws if missing registrations at startup
});
```

Without scope validation, captive dependency bugs silently cause stale data, incorrect behavior, or `ObjectDisposedException` at runtime.

### Instance-per-call vs per-scope comparison

```csharp
// Demonstrate with a counter service
public sealed class CounterService
{
    private static int _count = 0;
    public int Id { get; } = Interlocked.Increment(ref _count);
}

services.AddTransient<CounterService>(); // each resolve: new Id
// services.AddScoped<CounterService>(); // same Id within a request
// services.AddSingleton<CounterService>(); // same Id for entire app
```

## Code Example

```csharp
// Program.cs — canonical lifetime assignments

// Singleton: thread-safe, stateless, shared globally
builder.Services.AddSingleton<IConfiguration>(builder.Configuration);
builder.Services.AddSingleton<ICacheProvider, RedisCacheProvider>();

// Scoped: per-request state, DbContext, UoW
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IUnitOfWork, EfUnitOfWork>();
builder.Services.AddScoped<IOrderService, OrderService>();

// Transient: stateless helpers, validators
builder.Services.AddTransient<IOrderValidator, OrderValidator>();
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
```

```csharp
// Safely using a Scoped service from a Singleton via IServiceScopeFactory
public sealed class OrderCleanupJob(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
            await uow.Orders.DeleteOldDraftOrdersAsync(stoppingToken);
            await uow.SaveChangesAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
```

### Quick decision guide

```
Is it stateless and thread-safe?
  → Singleton (fastest, no allocation per request)

Does it hold per-request state (e.g., DbContext, current user context)?
  → Scoped

Is it cheap to create and must not be shared (e.g., holds mutable state per-call)?
  → Transient
```

## Common Follow-up Questions

- What happens if you call `services.AddScoped<T>()` inside a `BackgroundService`?
- How does scope validation work — what exactly is checked at startup vs at runtime?
- Can a Transient service hold a Singleton dependency? (Yes — safe; Singleton outlives Transient.)
- How do you verify service lifetimes are correct without running the app?
- What is `IServiceScope` and when do you create one manually?

## Common Mistakes / Pitfalls

- **Singleton `DbContext`** — `DbContext` tracks entities in memory and is not thread-safe. As Singleton it causes corrupted state under concurrent requests.
- **Transient with expensive construction** — e.g., `AddTransient<HttpClient>()` creates a new socket per resolution; use `IHttpClientFactory` instead.
- **Scoped service in a `BackgroundService`** — `BackgroundService` is Singleton; inject `IServiceScopeFactory` and create a scope per work item.
- **Multiple `AddSingleton` calls for the same interface** — each call adds to the list; the last one "wins" for single-resolution, but `GetServices<T>()` returns all.
- **Assuming Transient means "disposed immediately"** — Transient instances are disposed when their enclosing scope ends, not when the reference is set to null.

## References

- [Microsoft Learn — Service lifetimes](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection#service-lifetimes)
- [Microsoft Learn — Dependency injection in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-8.0)
- [Microsoft Learn — Scope validation](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines#scope-validation)
- [Andrew Lock — Service lifetimes deep dive](https://andrewlock.net/tag/di/) (verify URL)
- [Mark Seemann — Captive Dependency](https://blog.ploeh.dk/2014/06/02/captive-dependency/) (verify URL)
