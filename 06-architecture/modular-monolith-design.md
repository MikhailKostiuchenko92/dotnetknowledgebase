# Modular Monolith Design

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `modular-monolith`, `bounded-context`, `modules`, `DDD`, `migration-path`, `internal-API`

## Question

> What is a Modular Monolith? How do you structure modules with well-defined boundaries in .NET, and how does a Modular Monolith serve as a migration path to microservices?

## Short Answer

A Modular Monolith is a single-process application internally structured as independent modules, each aligned with a bounded context (Orders, Inventory, Payments). Each module has a **public API** (interfaces, events, request/response types) and **internal implementation** (`internal` classes, repositories, domain model) hidden from other modules. Modules communicate via in-process events or method calls through public interfaces — never by directly accessing another module's database tables or internal types. This gives you the domain isolation of microservices (clear contracts, separate models) without network overhead, and provides a clear extraction path: a module becomes a microservice by moving its public API across a network boundary.

## Detailed Explanation

### The Problem with "Big Ball of Mud" Monoliths

Traditional monoliths start clean but degrade: `OrderService` starts calling `InventoryRepository` directly, then `CustomerService` calls `OrderService.GetInternalState()`. After 2 years, every change requires understanding the entire codebase. The "modular" part of Modular Monolith prevents this by treating modules as first-class units with enforced isolation.

### Module Anatomy

```
src/
  Modules/
    Orders/
      YourApp.Orders.API/           ← Public contract (interfaces, events, DTOs)
        IOrderService.cs
        OrderCreatedEvent.cs
        PlaceOrderRequest.cs
      YourApp.Orders.Domain/         ← Domain model (internal)
        Order.cs
        OrderLine.cs
      YourApp.Orders.Application/    ← Handlers (internal)
        PlaceOrderHandler.cs
        GetOrderHandler.cs
      YourApp.Orders.Infrastructure/ ← DB, repos (internal)
        OrdersDbContext.cs
    Inventory/
      YourApp.Inventory.API/
        IInventoryService.cs
        ProductReservedEvent.cs
      ...
  Common/
    YourApp.Common/                  ← Shared kernel, base types, event bus
```

### Public vs Internal Module API

```csharp
// Orders/YourApp.Orders.API — this is what other modules may reference
public interface IOrderModule
{
    Task<int> PlaceOrderAsync(PlaceOrderRequest request, CancellationToken ct = default);
    Task<OrderSummaryDto?> GetOrderSummaryAsync(int orderId, CancellationToken ct = default);
}

public record PlaceOrderRequest(int CustomerId, decimal Total);
public record OrderSummaryDto(int Id, string Status, decimal Total);
public record OrderPlacedEvent(int OrderId, int CustomerId, decimal Total);

// Orders/YourApp.Orders.Application — internal, other modules can't see this
internal class EfOrderRepository(OrdersDbContext db) : IOrderRepository { ... }
internal class PlaceOrderHandler(IOrderRepository orders) : IRequestHandler<...> { ... }
```

**Enforcement**: `internal` C# modifier + separate projects means the compiler prevents cross-module access to internal types.

### Module Communication Patterns

**Synchronous (direct method call)**:
- Module A calls `IOrderModule.PlaceOrderAsync()` — interfaces are in the public API project
- Use when you need a result back immediately

**Asynchronous (in-process events)**:
- Orders module publishes `OrderPlacedEvent` to an in-process `IEventBus`
- Inventory module subscribes and reserves stock
- Use for eventual consistency, decoupling, and easy extraction later

```csharp
// In-process event bus (becomes MassTransit/RabbitMQ when extracted to microservice)
public interface IEventBus
{
    Task PublishAsync<T>(T @event, CancellationToken ct = default) where T : class;
    void Subscribe<T>(Func<T, CancellationToken, Task> handler) where T : class;
}

// Orders module — publishes after placing order
public class PlaceOrderHandler(IOrderRepository orders, IEventBus bus)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Total);
        await orders.AddAsync(order, ct);
        await bus.PublishAsync(new OrderPlacedEvent(order.Id, cmd.CustomerId, cmd.Total), ct);
        return order.Id;
    }
}

// Inventory module — subscribes to the event
public class ReserveStockOnOrderPlaced(IInventoryService inventory)
{
    public async Task HandleAsync(OrderPlacedEvent @event, CancellationToken ct)
        => await inventory.ReserveForOrderAsync(@event.OrderId, ct);
}
```

### Separate Database Schema per Module

Each module owns its own database schema — no shared tables:

```sql
-- Orders module schema
CREATE SCHEMA orders;
CREATE TABLE orders.Orders (Id INT IDENTITY PRIMARY KEY, ...);

-- Inventory module schema  
CREATE SCHEMA inventory;
CREATE TABLE inventory.Products (Id INT IDENTITY PRIMARY KEY, ...);
```

```csharp
// Per-module DbContext with schema prefix
public class OrdersDbContext(DbContextOptions<OrdersDbContext> opts) : DbContext(opts)
{
    public DbSet<Order> Orders => Set<Order>();
    protected override void OnModelCreating(ModelBuilder mb)
        => mb.HasDefaultSchema("orders");
}
```

### Migration Path to Microservices

The modular monolith is designed so each module can be extracted:
1. Move the module's projects to a new repository
2. Replace `IEventBus` with a real message broker (MassTransit + RabbitMQ)
3. Replace direct `IOrderModule` calls with HTTP/gRPC
4. Move the database schema to a dedicated server

The business logic is unchanged — only the communication mechanism changes.

## Code Example

```csharp
// Program.cs — module registration
builder.Services
    .AddOrdersModule(builder.Configuration)
    .AddInventoryModule(builder.Configuration)
    .AddPaymentsModule(builder.Configuration);

// Each module registers itself
public static IServiceCollection AddOrdersModule(
    this IServiceCollection services,
    IConfiguration config)
{
    services.AddDbContext<OrdersDbContext>(o =>
        o.UseSqlServer(config.GetConnectionString("Orders")));

    services.AddMediatR(cfg =>
        cfg.RegisterServicesFromAssemblyContaining<PlaceOrderHandler>());

    services.AddScoped<IOrderModule, OrderModule>();  // public API implementation
    return services;
}
```

## Common Follow-up Questions

- How do you enforce that Module A cannot access Module B's `internal` types when both are in the same solution?
- When does a modular monolith become harder to maintain than microservices?
- How do you handle distributed transactions when two modules must both succeed or both fail?
- How do you share authentication/authorisation state between modules?
- What tools (NetArchTest, ArchUnit) can enforce module boundaries in CI?

## Common Mistakes / Pitfalls

- **Shared `DbContext` across modules**: if `OrdersDbContext` and `InventoryDbContext` both reference each other's entity types, you've re-coupled the modules at the database level.
- **Public `internal` domain classes via reflection**: some DI frameworks or serializers can bypass `internal` — test that module boundaries hold under real DI wiring.
- **Modules communicating through shared databases**: `OrderService` calling `SELECT * FROM inventory.Products` bypasses the Inventory module's API and creates hidden coupling.
- **No module boundary = no path to microservices**: a modular monolith where modules freely reference each other's internals is just a regular monolith with extra folders.

## References

- [Modular Monolith with DDD — Kamil Grzybek (GitHub)](https://github.com/kgrzybek/modular-monolith-with-ddd) (verify URL)
- [Modular Monolith patterns — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/azure/architecture/microservices/migrate-monolith)
- [See: vertical-slice-architecture.md](./vertical-slice-architecture.md)
- [See: bounded-context.md](./bounded-context.md)
- [See: module-isolation-enforcement.md](./module-isolation-enforcement.md)
