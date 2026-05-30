# DbContext Pooling

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `DbContext`, `pooling`, `AddDbContextPool`, `performance`, `DI`, `scoped`

## Question

> What is DbContext pooling in EF Core? How does `AddDbContextPool` differ from `AddDbContext`, what are the performance benefits, and what limitations does it impose?

## Short Answer

`AddDbContextPool` maintains a pool of pre-allocated `DbContext` instances that are reset and reused across requests, rather than creating and destroying one per request. This eliminates the allocation cost and GC pressure of constructing a `DbContext` on every HTTP request. The trade-off is that pooled contexts have restrictions: you cannot add constructor services with a shorter lifetime than the pool, cannot use per-request state stored in the context itself, and must implement `IDbContextFactory<T>` if you need a context outside the DI scope. For high-throughput APIs it can measurably improve throughput.

## Detailed Explanation

### How Normal `AddDbContext` Works

```csharp
services.AddDbContext<AppDb>(opt => opt.UseSqlServer(conn));
```

- On every HTTP request, DI creates a **new `AppDb` instance** (scoped lifetime).
- `AppDb` allocates internal state: change tracker, identity map, interceptor list, etc.
- At request end, `AppDb` is disposed and garbage collected.
- Allocation + GC pressure at scale.

### How `AddDbContextPool` Works

```csharp
services.AddDbContextPool<AppDb>(opt => opt.UseSqlServer(conn), poolSize: 128);
```

- EF Core pre-creates a pool of `AppDb` instances (default pool size: 1024; configurable).
- On each request, DI **checks out** an instance from the pool.
- At request end, EF Core **resets** the context (clears change tracker, detaches entities, resets state) and **returns it** to the pool.
- No allocation, no GC — only a pool checkout/return.

### Reset Semantics

When a context is returned to the pool, EF Core calls the internal `Reset()` method which:
- Clears the change tracker (`db.ChangeTracker.Clear()`).
- Resets `AutoDetectChangesEnabled` to its configured default.
- Clears any `Database.CurrentTransaction`.
- Calls `OnConfiguring` again if overridden to allow reconfiguration.

> **Important:** Any data stored as fields or properties on your custom `DbContext` subclass **survives the reset** unless you override `OnModelCreating` or implement `IDbContextPoolable.ResetState()`. Don't store request-scoped data in the DbContext.

### Limitations

| Limitation | Explanation |
|-----------|-------------|
| No scoped constructor dependencies | `AddDbContextPool` registers the context as a singleton under the hood. Injecting `IHttpContextAccessor` or any `Scoped` service into `AppDb`'s constructor will fail at runtime. |
| No per-request state in the context | Fields added to your `DbContext` subclass persist across requests. Use `IDbContextFactory<T>` for short-lived, independent contexts if you need per-operation state. |
| `OnConfiguring` called on every checkout | EF Core calls `OnConfiguring` each time a pooled context is activated, allowing connection string changes (e.g., multi-tenancy by connection) — but this adds overhead. |
| Change tracker may have stale state | Unlikely if reset works correctly, but do not rely on change tracker state at the start of a request in pooled contexts. |

### Injecting Scoped Services — The Problem

```csharp
// ❌ WILL THROW at runtime with AddDbContextPool
public class AppDb(
    DbContextOptions<AppDb> options,
    ITenantService tenantService)  // scoped — incompatible with pooling
    : DbContext(options) { }
```

**Fix:** Use `IDbContextFactory<T>` to resolve a context on demand from within a scoped service:

```csharp
// ✅ Factory pattern — compatible with pooling
public class OrderService(IDbContextFactory<AppDb> factory)
{
    public async Task<Order?> GetAsync(int id, CancellationToken ct)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        return await db.Orders.FindAsync([id], ct);
    }
}

// Registration
services.AddDbContextPool<AppDb>(opt => opt.UseSqlServer(conn));
services.AddDbContextFactory<AppDb>();  // adds factory on top of pool
```

### DbContext Pooling vs Database Connection Pooling

| | DbContext Pool | ADO.NET Connection Pool |
|--|---------------|------------------------|
| What's pooled | EF Core context object | Physical TCP connection to DB |
| Managed by | EF Core / DI | ADO.NET / SqlClient |
| Config | `AddDbContextPool(poolSize)` | `Max Pool Size` in connection string |
| Default size | 1024 | 100 |
| Independent? | Yes | Yes — each DbContext borrows from the connection pool separately |

Both pools work together. A single pooled `AppDb` instance may borrow different connection pool connections across requests.

## Code Example

```csharp
// Program.cs — enabling context pooling
builder.Services.AddDbContextPool<AppDb>(
    opt => opt.UseSqlServer(builder.Configuration.GetConnectionString("Default")),
    poolSize: 256);  // tune based on max concurrency

// If you also need per-scope context creation (e.g., background jobs):
builder.Services.AddDbContextFactory<AppDb>(
    opt => opt.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// ✅ Correct: resolve per-operation context from the factory
public class ReportJobService(IDbContextFactory<AppDb> factory)
{
    public async Task RunAsync(CancellationToken ct)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        var data = await db.Reports.AsNoTracking().ToListAsync(ct);
        // db is disposed here — returned to pool
    }
}

// ❌ Incorrect: storing per-request tenant ID in the DbContext
public class AppDb : DbContext
{
    public string? TenantId { get; set; }  // BAD — persists across requests in pool!

    // ✅ Correct pattern: use HasQueryFilter with a service injected at resolve time
}
```

## Common Follow-up Questions

- How does multi-tenancy work with DbContext pooling if you can't inject a scoped `ITenantService`?
- What happens if `poolSize` is smaller than concurrent request count — does the app throw or block?
- Is `IDbContextFactory<T>` always backed by the same pool as `AddDbContextPool`?
- Can you use `DbContext` pooling with EF Core interceptors that depend on scoped services?
- How do you reset custom per-request state on a pooled context — what interface should you implement?

## Common Mistakes / Pitfalls

- **Injecting a scoped service into a pooled DbContext constructor**: This causes a runtime exception (`Cannot consume scoped service … from singleton`). Use `IDbContextFactory<T>` and resolve scoped services separately.
- **Storing mutable state on the DbContext subclass**: Properties added to `AppDb` survive pool resets. A `TenantId` or `UserId` field set in request 1 will be present in request 2 unless you implement `IResettableService` to clear it.
- **Using `AddDbContextPool` for contexts with lazy loading proxies**: Proxies are generated per-type but attached per-instance. Pooled contexts with lazy loading proxies can behave unexpectedly — avoid this combination.
- **Setting pool size too small**: If `poolSize` is smaller than peak concurrency, DI creates new instances beyond the pool limit and they are discarded rather than returned, negating the benefit. Size the pool to match `Max Pool Size` in the connection string.
- **Not using `await using` with `IDbContextFactory<T>`**: Factory-created contexts are not managed by DI scope. Always `await using var db = await factory.CreateDbContextAsync(ct)` to ensure disposal.

## References

- [DbContext pooling — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics#dbcontext-pooling)
- [IDbContextFactory — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/#using-a-dbcontext-factory)
- [EF Core performance overview — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/)
- [See: dbcontext-overview.md](./dbcontext-overview.md)
