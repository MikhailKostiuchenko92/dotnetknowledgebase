# Shared Infrastructure in Modular Monolith

**Category:** Architecture / Modular Monolith
**Difficulty:** 🔴 Senior
**Tags:** `modular-monolith`, `shared-DB`, `DB-schema`, `outbox`, `auth`, `shared-infrastructure`, `module-isolation`

## Question

> How do you share infrastructure components (database, outbox, authentication) across modules in a modular monolith while maintaining module isolation? What are the trade-offs of shared vs per-module infrastructure?

## Short Answer

In a modular monolith, **shared infrastructure is acceptable when it's truly horizontal** — authentication tokens, distributed cache, a shared message bus, the application server itself. **What must NOT be shared**: DB tables (each module owns its own schema), domain models, business logic. Strategy: one physical database with **separate schemas per module** (`orders.*`, `inventory.*`) — modules can't query each other's tables. The **Outbox pattern** can be implemented in a shared schema (`outbox.*`) since it's infrastructure, not business domain. Authentication identity (user ID) flows via `IHttpContextAccessor` or a request context service.

## Detailed Explanation

### Database: Shared Instance, Separate Schemas

```sql
-- Single PostgreSQL/SQL Server instance, multiple schemas
-- Each module owns its schema — no cross-schema queries allowed

-- Orders module schema
CREATE SCHEMA orders;
CREATE TABLE orders.orders (id SERIAL PRIMARY KEY, customer_id INT, total DECIMAL, status VARCHAR);
CREATE TABLE orders.order_lines (id SERIAL PRIMARY KEY, order_id INT, product_id INT, qty INT);

-- Inventory module schema
CREATE SCHEMA inventory;
CREATE TABLE inventory.products (id SERIAL PRIMARY KEY, name VARCHAR, stock_level INT);

-- Outbox (shared infrastructure, not a business module)
CREATE SCHEMA outbox;
CREATE TABLE outbox.messages (id UUID PRIMARY KEY, type VARCHAR, payload JSONB, processed_at TIMESTAMPTZ);
```

```csharp
// Each module has its own DbContext scoped to its schema
namespace MyApp.Orders.Infrastructure;

internal class OrdersDbContext(DbContextOptions<OrdersDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderLine> OrderLines => Set<OrderLine>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.HasDefaultSchema("orders");  // ← all tables in 'orders' schema
        mb.ApplyConfigurationsFromAssembly(typeof(OrdersDbContext).Assembly);
    }
}

// Inventory has its own context with different schema
internal class InventoryDbContext(DbContextOptions<InventoryDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder mb)
        => mb.HasDefaultSchema("inventory");
}

// Registration: both contexts use the same connection string but different DbContextOptions
builder.Services.AddDbContext<OrdersDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("App")));
builder.Services.AddDbContext<InventoryDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("App")));
```

### Shared Outbox

```csharp
// Outbox: shared infrastructure — modules write to it, a single relay processes it
// OutboxDbContext lives in MyApp.SharedKernel.Infrastructure or a dedicated Outbox project

public class OutboxDbContext(DbContextOptions<OutboxDbContext> options) : DbContext(options)
{
    public DbSet<OutboxMessage> Messages => Set<OutboxMessage>();

    protected override void OnModelCreating(ModelBuilder mb)
        => mb.HasDefaultSchema("outbox");
}

// Outbox saves happen in the SAME transaction as module state changes
// Orders handler: SaveChanges on OrdersDbContext + write to Outbox in one transaction
// EF Core: use ambient transaction or share the same connection

// OrdersSaveChangesInterceptor: after saving, write integration events to outbox
public class OutboxInterceptor(OutboxDbContext outbox) : SaveChangesInterceptor
{
    public override async ValueTask<int> SavingChangesAsync(
        DbContextEventData ev, InterceptionResult<int> result, CancellationToken ct)
    {
        var domainEvents = ev.Context?.ChangeTracker.Entries<AggregateRoot>()
            .SelectMany(e => e.Entity.GetDomainEvents()) ?? [];

        foreach (var @event in domainEvents)
            outbox.Messages.Add(new OutboxMessage(Guid.NewGuid(), @event.GetType().Name,
                JsonSerializer.Serialize(@event, @event.GetType())));

        return await base.SavingChangesAsync(ev, result, ct);
    }
}
```

### Shared Authentication

```csharp
// Authentication is handled once at the ASP.NET Core level — all modules share it
// Modules access the current user via a shared CurrentUserService

// SharedKernel (public)
public interface ICurrentUser
{
    int? UserId { get; }
    string? Email { get; }
    bool IsAuthenticated { get; }
    bool IsInRole(string role);
}

// Infrastructure implementation (registered at bootstrapper level)
public class HttpContextCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal? User => accessor.HttpContext?.User;
    public int? UserId => User?.FindFirstValue(ClaimTypes.NameIdentifier) is { } id ? int.Parse(id) : null;
    public string? Email => User?.FindFirstValue(ClaimTypes.Email);
    public bool IsAuthenticated => User?.Identity?.IsAuthenticated ?? false;
    public bool IsInRole(string role) => User?.IsInRole(role) ?? false;
}

// Registered once in bootstrapper:
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

// Used in any module handler (by injecting the interface — no module coupling to auth infra):
internal class PlaceOrderHandler(ICurrentUser currentUser, IOrderRepository orders)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedException();
        // ...
    }
}
```

### What Can Be Shared vs What Must Be Isolated

| Infrastructure | Shared or Isolated | Reason |
|---------------|-------------------|--------|
| Database instance | ✅ Shared (separate schemas) | Operational simplicity; schema = boundary |
| DB tables | ❌ Isolated per module | Cross-module table access = coupling |
| DbContext | ❌ Per module | Scoped to module's schema |
| Outbox table | ✅ Shared | Infrastructure concern, not domain |
| Auth middleware | ✅ Shared | One HTTP pipeline |
| ICurrentUser service | ✅ Shared via interface | Identity is cross-cutting |
| Logging | ✅ Shared (Serilog, etc.) | Observability infrastructure |
| Cache (Redis) | ✅ Shared (with key namespacing) | Operational simplicity |
| Message bus | ✅ Shared | Infrastructure transport |

## Code Example

```csharp
// Bootstrapper: wiring shared + per-module infrastructure
var builder = WebApplication.CreateBuilder(args);
var connStr = builder.Configuration.GetConnectionString("App")!;

// Shared infrastructure
builder.Services.AddDbContext<OutboxDbContext>(o => o.UseNpgsql(connStr));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();
builder.Services.AddSingleton<IMemoryCache, MemoryCache>();

// Per-module infrastructure (each brings its own DbContext + domain DI)
builder.Services
    .AddOrdersModule(builder.Configuration)
    .AddInventoryModule(builder.Configuration)
    .AddCustomersModule(builder.Configuration);
```

## Common Follow-up Questions

- How do you run EF Core migrations for multiple DbContexts (per module) in a single deployment?
- How do you handle referential integrity when modules can't query each other's tables?
- What is the trade-off between separate schemas in one DB vs completely separate databases?
- How do you handle multi-tenancy in a shared-database modular monolith?
- How do you test infrastructure that spans multiple module DbContexts?

## Common Mistakes / Pitfalls

- **Cross-schema EF Core navigation properties**: adding a navigation from `orders.Order.Customer` → `customers.Customer` (different schema) creates a tight coupling at the DB level. Modules should communicate via application-level integration, not DB joins.
- **Single shared DbContext for all modules**: one `AppDbContext` with all tables loses schema isolation — any module can accidentally reference any table, making boundary enforcement purely by convention.
- **Outbox in the domain module**: the Outbox table in the domain DbContext mixes business state with infrastructure. Keep Outbox in a dedicated `OutboxDbContext` or shared infrastructure project.
- **Sharing the `ICurrentUser` implementation class** instead of the interface: if modules inject `HttpContextCurrentUser` directly, they couple to the HTTP infrastructure. Inject the `ICurrentUser` interface only.

## References

- [Modular Monolith — DB per module — Kamil Grzybek](https://www.kamilgrzybek.com/blog/posts/modular-monolith-data) (verify URL)
- [EF Core — schema isolation](https://learn.microsoft.com/en-us/ef/core/modeling/inheritance#table-per-hierarchy-and-discriminator-configuration) (verify URL)
- [See: modular-monolith-structure.md](./modular-monolith-structure.md)
- [See: outbox-pattern-architecture.md](./outbox-pattern-architecture.md)
