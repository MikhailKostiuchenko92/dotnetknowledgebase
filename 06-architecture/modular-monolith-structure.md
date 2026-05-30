# Modular Monolith Structure

**Category:** Architecture / Modular Monolith
**Difficulty:** 🟡 Middle
**Tags:** `modular-monolith`, `module-boundaries`, `internal-API`, `exported-API`, `DI-registration`, `solution-structure`

## Question

> How do you structure a modular monolith in .NET — what constitutes a module boundary, what is "internal vs exported API", and how do you enforce module isolation in a C# solution?

## Short Answer

In a .NET modular monolith, each **module** is a class library project exposing a narrow public API — typically one `IModuleContract` interface and a set of DTOs — while keeping all implementation classes `internal`. Modules register their own DI services via a static `AddOrdersModule(this IServiceCollection services)` extension method. Cross-module communication uses only the exported interfaces, never internal classes. Boundaries are enforced via C# `internal` access modifier, `InternalsVisibleTo` for tests only, and optional architectural tests with NetArchTest.

## Detailed Explanation

### Module Structure

```
MyApp.sln
├── src/
│   ├── MyApp.Bootstrapper/          ← Program.cs — wires all modules
│   ├── Modules/
│   │   ├── MyApp.Orders/
│   │   │   ├── OrdersModule.cs          ← public: DI registration + module metadata
│   │   │   ├── IOrdersModule.cs         ← public: exported contract interface
│   │   │   ├── Contracts/               ← public: DTOs, events, commands accepted from outside
│   │   │   │   ├── PlaceOrderRequest.cs
│   │   │   │   └── OrderDto.cs
│   │   │   ├── Application/             ← internal: use cases / command handlers
│   │   │   ├── Domain/                  ← internal: aggregates, value objects
│   │   │   └── Infrastructure/          ← internal: EF Core, repos
│   │   └── MyApp.Inventory/
│   │       ├── InventoryModule.cs
│   │       ├── IInventoryModule.cs
│   │       ├── Contracts/
│   │       └── ...
│   └── MyApp.SharedKernel/          ← public: base classes, value objects, shared interfaces
├── tests/
│   ├── MyApp.Orders.Tests/
│   └── MyApp.Inventory.Tests/
└── arch-tests/
    └── MyApp.ArchTests/             ← architectural dependency rule tests
```

### Public Module API

```csharp
// IOrdersModule.cs — PUBLIC: the only way other modules interact with Orders
namespace MyApp.Orders.Contracts;

public interface IOrdersModule
{
    Task<int> PlaceOrderAsync(PlaceOrderRequest request, CancellationToken ct = default);
    Task<OrderDto?> GetOrderAsync(int orderId, CancellationToken ct = default);
    Task CancelOrderAsync(int orderId, string reason, CancellationToken ct = default);
}

// Contracts (public) — DTOs for cross-module use
public record PlaceOrderRequest(int CustomerId, IReadOnlyList<OrderLineRequest> Lines);
public record OrderLineRequest(int ProductId, int Quantity);
public record OrderDto(int Id, decimal Total, string Status, DateTimeOffset PlacedAt);
```

### Module Registration

```csharp
// OrdersModule.cs — public entry point, all internals hidden
namespace MyApp.Orders;

public static class OrdersModule
{
    public static IServiceCollection AddOrdersModule(this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register internal services (hidden from other modules via 'internal' class modifier)
        services.AddDbContext<OrdersDbContext>(opts =>
            opts.UseNpgsql(configuration.GetConnectionString("Orders")));

        services.AddScoped<IOrderRepository, OrderRepository>();
        services.AddScoped<IOrderDomainService, OrderDomainService>();
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<OrdersModule>());

        // Register the public interface — other modules inject IOrdersModule
        services.AddScoped<IOrdersModule, OrdersModuleImpl>();
        return services;
    }
}

// OrdersModuleImpl.cs — INTERNAL: implements the public interface
namespace MyApp.Orders;

internal sealed class OrdersModuleImpl(ISender mediator) : IOrdersModule
{
    public async Task<int> PlaceOrderAsync(PlaceOrderRequest request, CancellationToken ct)
        => await mediator.Send(new PlaceOrderCommand(request.CustomerId, request.Lines), ct);

    public async Task<OrderDto?> GetOrderAsync(int orderId, CancellationToken ct)
        => await mediator.Send(new GetOrderByIdQuery(orderId), ct);

    public Task CancelOrderAsync(int orderId, string reason, CancellationToken ct)
        => mediator.Send(new CancelOrderCommand(orderId, reason), ct);
}

// All handlers, aggregates, repositories are 'internal':
internal class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, int> { ... }
internal class OrderRepository : IOrderRepository { ... }
internal class Order : AggregateRoot { ... }
```

### Bootstrapper

```csharp
// Program.cs — wires all modules, knows about all of them
builder.Services
    .AddOrdersModule(builder.Configuration)
    .AddInventoryModule(builder.Configuration)
    .AddCustomersModule(builder.Configuration);

// Inventory uses Orders via IOrdersModule — resolved from DI
// Inventory never references any internal Orders type
```

### Enforcing Boundaries

```csharp
// arch-tests: ensure no cross-module internal class references
// NuGet: NetArchTest.Rules

[Fact]
public void Inventory_ShouldNotReference_Orders_InternalTypes()
{
    var result = Types.InAssembly(typeof(InventoryModule).Assembly)
        .Should()
        .NotHaveDependencyOn("MyApp.Orders.Application")   // ← internal namespace
        .GetResult();

    Assert.True(result.IsSuccessful,
        $"Inventory references Orders internals: {string.Join(", ", result.FailingTypes ?? [])}");
}
```

## Code Example

```csharp
// Cross-module call: Inventory module checks order before releasing stock
// Uses IOrdersModule (public) not OrderRepository (internal)

namespace MyApp.Inventory.Application;

internal class ReleaseStockOnOrderCancelledHandler(
    IStockRepository stocks,
    IOrdersModule orders)            // ← injected via public interface
    : INotificationHandler<OrderCancelledIntegrationEvent>
{
    public async Task Handle(OrderCancelledIntegrationEvent ev, CancellationToken ct)
    {
        // Can call public IOrdersModule methods
        var order = await orders.GetOrderAsync(ev.OrderId, ct);
        if (order is null) return;

        await stocks.ReleaseReservationAsync(ev.OrderId, ct);
        // Cannot reference: OrderRepository, OrdersDbContext, Order aggregate — all internal
    }
}
```

## Common Follow-up Questions

- How do you share database infrastructure (migrations, connection pooling) between modules while keeping schemas isolated?
- How do you test a module in isolation when it has no public constructors for its internal classes?
- What is the difference between a modular monolith module and a microservice?
- How do you handle circular dependencies between modules?
- When does a module warrant being extracted to a microservice?

## Common Mistakes / Pitfalls

- **Public classes in implementation namespaces**: making `OrderRepository` or `PlaceOrderHandler` public defeats the purpose — any module can now depend on implementation details.
- **Modules sharing a DbContext**: `OrdersDbContext` shared between Orders and Inventory modules means schema coupling. Each module should have its own DbContext and DB schema.
- **Missing `InternalsVisibleTo` for tests**: after making everything `internal`, unit tests in `MyApp.Orders.Tests` can't access classes. Add `[assembly: InternalsVisibleTo("MyApp.Orders.Tests")]` in the module assembly.
- **Modules communicating via domain events in-process without interface**: publishing `INotification` and subscribing in another module creates coupling — you need to ensure the event contract (the notification type) lives in the public contracts layer.

## References

- [Modular Monolith — Kamil Grzybek](https://www.kamilgrzybek.com/blog/posts/modular-monolith-primer) (verify URL)
- [NetArchTest — GitHub](https://github.com/BenMorris/NetArchTest)
- [See: modular-monolith-design.md](./modular-monolith-design.md)
- [See: module-isolation-enforcement.md](./module-isolation-enforcement.md)
