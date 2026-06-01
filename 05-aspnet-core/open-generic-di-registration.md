# Open-Generic DI Registration

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟡 Middle
**Tags:** `DI`, `open-generic`, `generic-registration`, `typeof`, `IRepository`, `conditional-registration`

## Question

> How do you register open-generic services in ASP.NET Core's DI container, and what are typical use cases?

## Short Answer

Open-generic registration maps an open generic interface (e.g., `IRepository<>`) to an open generic implementation (e.g., `EfRepository<>`) using `typeof(...)` syntax. The container automatically closes the generics when resolving a specific type like `IRepository<Order>`, creating `EfRepository<Order>`. This eliminates the need to manually register every `IRepository<T>` for each entity type.

## Detailed Explanation

### The problem

Without open-generic registration, you need a separate `AddScoped` call per entity:

```csharp
// Repetitive — one per entity type:
services.AddScoped<IRepository<Order>, EfRepository<Order>>();
services.AddScoped<IRepository<Product>, EfRepository<Product>>();
services.AddScoped<IRepository<Customer>, EfRepository<Customer>>();
// ... 20 more entity types
```

### Open-generic registration

```csharp
// Single registration covers all closed types
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
```

When `IRepository<Order>` is requested, the container:
1. Matches `IRepository<>` → `EfRepository<>`.
2. Closes to `EfRepository<Order>`.
3. Constructs the instance, injecting `EfRepository<Order>`'s dependencies.

### Type constraints

The concrete implementation can have type constraints — they are honored at construction time:

```csharp
public sealed class EfRepository<TEntity>(AppDbContext db) : IRepository<TEntity>
    where TEntity : class, IEntity
{
    public Task<TEntity?> GetByIdAsync(int id) =>
        db.Set<TEntity>().FindAsync(id).AsTask();
}
```

If you try to resolve `IRepository<string>` (which doesn't satisfy `where TEntity : class, IEntity`), the container throws a `InvalidOperationException` at resolution time.

### Conditional registration

Register different implementations based on the closed type:

```csharp
// Register specific override first (last registration wins for same key)
services.AddScoped<IRepository<AuditLog>, ReadOnlyAuditLogRepository>();

// Then the open-generic fallback
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
```

Wait — actually the DI container resolves **non-generic registrations before generic ones** when both exist. The specific `IRepository<AuditLog>` registration takes precedence over the open-generic one.

### `TryAddEnumerable` pattern for conditional registration

```csharp
// Only registers if no existing registration for the exact service type
services.TryAdd(ServiceDescriptor.Scoped(typeof(IRepository<>), typeof(EfRepository<>)));
```

### Open-generic vs closed-generic in `IEnumerable<T>`

When you call `GetServices<IRepository<Order>>()`, you get:
- All non-generic registrations for `IRepository<Order>`.
- The open-generic `IRepository<>` → `EfRepository<>` registration (as one closed instance).

### Open-generic with decorators (Scrutor)

```csharp
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
services.Decorate(typeof(IRepository<>), typeof(CachingRepository<>));
// All IRepository<T> now wrapped in CachingRepository<T>
```

See [scrutor-and-decorator-di.md](scrutor-and-decorator-di.md) for details.

## Code Example

```csharp
// IRepository.cs
public interface IRepository<TEntity> where TEntity : class
{
    Task<TEntity?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<TEntity>> GetAllAsync(CancellationToken ct = default);
    void Add(TEntity entity);
    void Remove(TEntity entity);
}

// EfRepository.cs
public class EfRepository<TEntity>(AppDbContext db) : IRepository<TEntity>
    where TEntity : class
{
    protected readonly DbSet<TEntity> Set = db.Set<TEntity>();

    public Task<TEntity?> GetByIdAsync(int id, CancellationToken ct)
        => Set.FindAsync([id], ct).AsTask();

    public async Task<IReadOnlyList<TEntity>> GetAllAsync(CancellationToken ct)
        => await Set.AsNoTracking().ToListAsync(ct);

    public void Add(TEntity entity)    => Set.Add(entity);
    public void Remove(TEntity entity) => Set.Remove(entity);
}

// OrderRepository.cs — specific override with extra methods
public sealed class OrderRepository(AppDbContext db)
    : EfRepository<Order>(db), IOrderRepository
{
    public Task<List<Order>> GetPendingAsync(CancellationToken ct)
        => Set.Where(o => o.Status == OrderStatus.Pending).ToListAsync(ct);
}
```

```csharp
// Program.cs
// Open-generic base (fallback for all entities)
builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));

// Specific override for Order (resolved instead of EfRepository<Order>)
builder.Services.AddScoped<IRepository<Order>, OrderRepository>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
```

```csharp
// Consumer — same for all entities
public class ProductService(IRepository<Product> repo) { ... }
public class OrderService(IOrderRepository orders) { ... }
```

### Verifying registrations

```csharp
// Debug helper — print all registrations in Program.cs
foreach (var svc in builder.Services
    .Where(s => s.ServiceType.IsGenericTypeDefinition))
{
    Console.WriteLine($"[Open-generic] {svc.ServiceType} → {svc.ImplementationType}");
}
```

## Common Follow-up Questions

- How does the container handle open-generic registrations alongside specific closed-generic registrations for the same interface?
- Can you register an open-generic service as a Singleton? What are the thread-safety implications?
- How does `TryAddEnumerable` differ from `TryAdd` for open-generic services?
- How does Scrutor's `Scan` work with open-generic interfaces?
- What happens when type constraints on the implementation are not satisfied at resolution time?

## Common Mistakes / Pitfalls

- **Registering a closed-generic after an open-generic and expecting the closed one to win** — registration order matters; specific registrations should come before the open-generic fallback, not after.
- **Using `typeof(IRepository<T>)` (closed) instead of `typeof(IRepository<>)` (open)** — this only registers for that specific `T`, not all types.
- **Registering as Singleton with a Scoped constructor dependency** — open-generic Singletons with Scoped inner services cause captive dependencies; use Scoped or Transient.
- **Forgetting `where TEntity : class` constraints** — the container may try to instantiate with a value type, causing `InvalidOperationException` at runtime.
- **Assuming open-generic registration shows up when introspecting `IServiceCollection`** — it does, via `ServiceDescriptor.ServiceType.IsGenericTypeDefinition == true`, but it's often overlooked in diagnostic tooling.

## References

- [Microsoft Learn — Open-generic dependency injection](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection#open-generic-types)
- [Microsoft — ServiceDescriptor source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection.Abstractions/src/ServiceDescriptor.cs)
- [Andrew Lock — Open-generic registrations in ASP.NET Core](https://andrewlock.net/tag/di/) (verify URL)
- [Scrutor — Decorate open generics](https://github.com/khellang/Scrutor)
