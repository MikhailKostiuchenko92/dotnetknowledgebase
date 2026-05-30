# DbContext Overview

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `dbcontext`, `dbset`, `dependency-injection`, `lifetime`

## Question

> What is `DbContext` in Entity Framework Core and what is its role? How should it be registered in ASP.NET Core DI, and why is the scoped lifetime the correct choice?

## Short Answer

`DbContext` is the primary class in EF Core that acts as a bridge between your domain objects and the database — it represents a unit of work and tracks changes to entities during a request. In ASP.NET Core it is registered as **scoped** (one instance per HTTP request), which matches the unit-of-work pattern: changes accumulate during a request, then `SaveChangesAsync()` commits them atomically. Singleton lifetime is dangerous because `DbContext` is not thread-safe; transient lifetime wastes resources by creating a new context — and therefore a new database connection — for every operation.

## Detailed Explanation

### What `DbContext` Is

`DbContext` combines two patterns:

- **Unit of Work** — tracks all entity changes (adds, updates, deletes) and commits them in a single `SaveChanges` call.
- **Repository** — exposes `DbSet<T>` properties through which you query and persist each entity type.

Every entity loaded through a `DbContext` is tracked by its **change tracker**, which records the original values and detects modifications. On `SaveChanges`, the change tracker generates the minimum SQL needed to persist all changes (INSERTs, UPDATEs, DELETEs).

### `DbSet<T>`

Each `DbSet<T>` represents a table (or view, or query). You query it with LINQ:

```csharp
var orders = await _context.Orders
    .Where(o => o.CustomerId == customerId)
    .ToListAsync(ct);
```

`DbSet<T>` implements `IQueryable<T>`, so LINQ operators build an expression tree that EF Core translates to SQL — the query doesn't execute until materialized (`ToListAsync`, `FirstOrDefaultAsync`, etc.).

### Registration in ASP.NET Core

```csharp
// Program.cs — standard registration
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
```

`AddDbContext` registers `AppDbContext` as **scoped** by default. One context instance is created at the start of each HTTP request and disposed at the end.

### Why Scoped Is Correct

| Lifetime | Effect | Problem |
|----------|--------|---------|
| **Scoped** (✅) | One context per request | Correct — matches unit-of-work scope |
| **Singleton** (❌) | One context for app lifetime | Not thread-safe; change tracker accumulates across requests; connection held forever |
| **Transient** (❌) | New context per injection | New DB connection per service; transactions don't span services; wasteful |

### DbContext Configuration

```csharp
public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
    : DbContext(options)                                   // primary constructor (.NET 8+)
{
    public DbSet<Order> Orders => Set<Order>();            // preferred: no field backing needed
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all IEntityTypeConfiguration<T> implementations in this assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

### DbContext Lifetime in Non-Web Scenarios

In background services (e.g., `IHostedService`) the DI scope is the entire process lifetime — injecting a scoped `DbContext` directly will fail. Use `IServiceScopeFactory` to create explicit scopes:

```csharp
public sealed class OrderProcessor(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var ctx = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            // ... process
        }
    }
}
```

> **Warning:** Never inject `DbContext` into a singleton service. The scoped context will be captured in the singleton's lifetime — EF Core will throw `InvalidOperationException` at startup if you have lifetime validation enabled (the default in development).

### `DbContextOptions<T>`

Options are configured once and immutable after construction. They carry the connection string, provider, retry policy, logging settings, etc. In tests, you swap the options (e.g., to use SQLite or InMemory) without changing the `DbContext` class itself.

## Code Example

```csharp
// AppDbContext.cs
namespace MyApp.Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order>    Orders    => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder builder) =>
        builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}

// Program.cs
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(
        builder.Configuration.GetConnectionString("Default"),
        sql => sql.EnableRetryOnFailure()));   // transient fault handling for Azure SQL

// OrderService.cs — correct: scoped service injecting scoped DbContext
public sealed class OrderService(AppDbContext db)
{
    public async Task<Order> CreateAsync(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Items);
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);   // commits INSERT
        return order;
    }
}
```

## Common Follow-up Questions

- How does `DbContext` pooling (`AddDbContextPool`) differ from the standard registration, and when should you use it?
- What happens to tracked entities if `SaveChangesAsync` throws halfway through?
- How do you share a `DbContext` across multiple repositories within the same request (unit of work)?
- What is the change tracker and how does it detect which properties changed?
- How do you configure a second `DbContext` (e.g., `ReadDbContext`) in the same application?

## Common Mistakes / Pitfalls

- **Singleton DbContext**: Injecting `DbContext` into a singleton causes cross-request data contamination and concurrency exceptions because `DbContext` is not thread-safe.
- **Transient DbContext**: Creates a new connection per injection point; if two services in the same request each inject the context independently, they get different instances and cannot share a transaction.
- **Not disposing in background services**: Forgetting `IServiceScopeFactory` in hosted services leaks open connections.
- **Calling `SaveChanges` in every repository method**: Repository methods should *not* call `SaveChanges` — the caller controls when to commit (unit of work pattern).
- **Exposing `DbContext` directly from controllers**: Bypass the service layer; couples presentation to persistence; makes testing harder.

## References

- [DbContext — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/)
- [DbContext lifetime in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/#using-a-dbcontext-factory-eg-for-blazor)
- [EF Core Change Tracking — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/)
- [EF Core DbContextPool — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics#dbcontext-pooling)
