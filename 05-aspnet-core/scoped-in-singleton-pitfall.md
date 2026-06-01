# Captive Dependency / Scoped-in-Singleton Pitfall

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🔴 Senior
**Tags:** `DI`, `captive-dependency`, `scoped-in-singleton`, `scope-validation`, `BuildServiceProvider`

## Question

> What is the "captive dependency" anti-pattern in ASP.NET Core DI? How does scope validation detect it, and how do you fix it?

## Short Answer

A captive dependency occurs when a Singleton service holds a direct reference to a Scoped or Transient service. Since the Singleton lives for the entire app lifetime, the shorter-lived service is "captured" and never disposed, effectively becoming a Singleton itself — leading to stale data, memory leaks, or thread-safety issues. ASP.NET Core's scope validation (enabled in Development) detects this by throwing at `BuildServiceProvider` time when a Scoped service is resolved from the root scope.

## Detailed Explanation

### The problem illustrated

```csharp
// WRONG: Singleton capturing Scoped service
public sealed class OrderSummaryCache(IOrderRepository repo) // repo is Scoped
{
    // repo is resolved once when OrderSummaryCache is first used
    // It's the same DbContext instance for the lifetime of the app
    // All requests share the same DbContext → race conditions, stale data
    private readonly Dictionary<int, OrderSummary> _cache = [];

    public async Task<OrderSummary> GetAsync(int orderId) =>
        _cache.TryGetValue(orderId, out var s) ? s
            : _cache[orderId] = await repo.GetSummaryAsync(orderId);
}

// Registration — bug is here
services.AddSingleton<OrderSummaryCache>();  // Singleton
services.AddScoped<IOrderRepository, EfOrderRepository>(); // Scoped
```

**Effects:**
- `EfOrderRepository` (and its `DbContext`) is created once, at first resolution.
- `DbContext` tracks entities from all requests in one instance — corrupted change tracker.
- `DbContext` is never disposed — connection pool exhaustion over time.
- Data returned is whatever was loaded on the first request, not fresh data.

### Lifetime violation table

| Outer (consumer) | Inner (dependency) | Safe? |
|---|---|---|
| Singleton | Singleton | ✅ |
| Singleton | Scoped | ❌ Captive |
| Singleton | Transient | ⚠️ Captive (Transient becomes Singleton) |
| Scoped | Singleton | ✅ (Singleton outlives Scoped) |
| Scoped | Scoped | ✅ (same scope) |
| Scoped | Transient | ✅ (Transient disposed with scope) |
| Transient | Singleton | ✅ |
| Transient | Scoped | ⚠️ Depends on where Transient is resolved |
| Transient | Transient | ✅ |

### Scope validation

```csharp
// Enabled automatically by CreateDefaultBuilder in Development
// Also available explicitly:
builder.Host.UseDefaultServiceProvider(opts =>
{
    opts.ValidateScopes = true;   // Detect Scoped resolved from root scope
    opts.ValidateOnBuild = true;  // Detect missing registrations at startup
});
```

When `ValidateScopes = true`, calling `serviceProvider.GetRequiredService<OrderSummaryCache>()` from the **root** provider (e.g., at app startup, in middleware, in Singletons) throws:

```
InvalidOperationException: Cannot consume scoped service 'IOrderRepository'
from singleton 'OrderSummaryCache'.
```

### `BuildServiceProvider(true)` — explicit validation

```csharp
// Force validation even in tests or custom code
var provider = services.BuildServiceProvider(new ServiceProviderOptions
{
    ValidateScopes = true,
    ValidateOnBuild = true
});
```

### Fixes

#### Option 1: Change lifetime of the dependency to Singleton

Only applicable if the service is truly stateless and thread-safe:

```csharp
services.AddSingleton<IOrderRepository, CachedOrderRepository>(); // if safe
```

#### Option 2: Inject `IServiceScopeFactory` into the Singleton

```csharp
public sealed class OrderSummaryCache(IServiceScopeFactory scopeFactory)
{
    private readonly MemoryCache _cache = new(new MemoryCacheOptions());

    public async Task<OrderSummary> GetAsync(int orderId)
    {
        return await _cache.GetOrCreateAsync($"order:{orderId}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);

            // Create a fresh scope for each cache miss
            await using var scope = scopeFactory.CreateAsyncScope();
            var repo = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
            return await repo.GetSummaryAsync(orderId);
        });
    }
}
```

#### Option 3: Change the Singleton to Scoped

If the consumer doesn't truly need Singleton lifetime, change it:

```csharp
services.AddScoped<OrderSummaryCache>(); // now gets a new IOrderRepository per request
```

### Detecting captive dependencies in tests

```csharp
// Integration test — verify no captive dependencies at build time
[Fact]
public void Services_Should_Have_No_CaptiveDependencies()
{
    var factory = new WebApplicationFactory<Program>()
        .WithWebHostBuilder(b =>
            b.UseEnvironment("Development")); // scope validation is ON in Development

    // Creating the server triggers BuildServiceProvider with ValidateScopes=true
    // Any captive dependency throws here, failing the test
    _ = factory.CreateClient();
}
```

## Code Example

```csharp
// BEFORE (broken): Singleton capturing Scoped DbContext
public sealed class UserCache(AppDbContext db) // ❌ db is Scoped
{
    private readonly ConcurrentDictionary<int, User> _cache = new();

    public async Task<User?> GetUserAsync(int id)
        => _cache.TryGetValue(id, out var u) ? u
            : _cache[id] = (await db.Users.FindAsync(id))!;
}
services.AddSingleton<UserCache>(); // ❌
```

```csharp
// AFTER (fixed): Use IServiceScopeFactory
public sealed class UserCache(IServiceScopeFactory scopeFactory,
    ILogger<UserCache> logger)
{
    private readonly MemoryCache _cache = new(new MemoryCacheOptions
    {
        SizeLimit = 1000
    });

    public async Task<User?> GetUserAsync(int id)
    {
        return await _cache.GetOrCreateAsync(id, async entry =>
        {
            entry.Size = 1;
            entry.SlidingExpiration = TimeSpan.FromMinutes(10);

            logger.LogDebug("Cache miss for user {UserId}", id);

            await using var scope = scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            return await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id);
        });
    }

    public void Invalidate(int userId) => _cache.Remove(userId);
}

services.AddSingleton<UserCache>(); // ✅ Safe: no Scoped dependencies in constructor
```

## Common Follow-up Questions

- How does the scope validation work internally — what does `ValidateScopes` actually check?
- Is it ever safe to have a Transient inside a Singleton? What are the risks?
- How would you design a cache service that needs to fetch from the database without the captive dependency issue?
- What is the difference between `ValidateScopes` and `ValidateOnBuild` — do they check for the same things?
- How do you detect captive dependencies in a large solution during CI?

## Common Mistakes / Pitfalls

- **Turning off scope validation** (`ValidateScopes = false`) to silence startup errors instead of fixing the root cause — this hides real bugs.
- **Fixing with `AddSingleton<IOrderRepository, EfOrderRepository>()`** — `EfRepository` wraps `DbContext`, which is not thread-safe as Singleton.
- **Creating one `IServiceScope` per Singleton instance** (in the constructor) and reusing it — the scope is shared across all requests, which is the same problem as the captive dependency.
- **Forgetting that middleware is effectively Singleton** — conventional middleware (activated by `UseMiddleware<T>`) is created once; injecting Scoped services in the constructor is a captive dependency.
- **Thinking `ValidateScopes` catches all problems at startup** — it detects attempts to resolve Scoped services from the root scope, but captive dependencies formed by manual captures (e.g., `var service = provider.GetService<T>()` stored in a field) may not be detected.

## References

- [Mark Seemann — Captive Dependency](https://blog.ploeh.dk/2014/06/02/captive-dependency/) (verify URL)
- [Microsoft Learn — Scope validation](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines#scope-validation)
- [Microsoft Learn — Dependency injection guidelines](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Andrew Lock — Captive dependencies in ASP.NET Core](https://andrewlock.net/tag/di/) (verify URL)
- [Microsoft — ServiceProvider scope validation source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection/src/ServiceProvider.cs)
