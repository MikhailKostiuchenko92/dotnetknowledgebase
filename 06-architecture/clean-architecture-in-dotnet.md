# Clean Architecture in .NET

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `clean-architecture`, `dotnet`, `solution-structure`, `layers`, `dependency-rule`, `DI`

## Question

> How do you implement Clean Architecture in a .NET solution? Describe the typical project structure, the responsibility of each layer, and how dependency injection ties it all together.

## Short Answer

A Clean Architecture .NET solution typically has four projects: `Domain` (entities, value objects, domain events — no external dependencies), `Application` (use cases, interfaces like `IOrderRepository`, MediatR handlers), `Infrastructure` (EF Core implementations, HTTP clients, messaging), and `Api` (controllers, `Program.cs`, DI wiring). Project references enforce the dependency rule at compile time: `Api` → `Infrastructure` → `Application` → `Domain`. DI registers concrete infrastructure types against application-layer interfaces in the composition root (`Program.cs`).

## Detailed Explanation

### Layer Responsibilities

#### Domain Layer
The innermost ring. Contains pure business concepts with no framework dependencies:
- **Entities** — objects with identity (`Order`, `Customer`)
- **Value objects** — structural equality (`Money`, `Address`, `Email`)
- **Domain events** — things that happened (`OrderPlaced`, `PaymentFailed`)
- **Domain exceptions** — business rule violations (`InsufficientStockException`)
- **No EF Core, no MediatR, no ASP.NET Core references**

#### Application Layer
Orchestrates use cases. Depends only on `Domain`:
- **Use case handlers** — MediatR `IRequestHandler<TCommand, TResult>`
- **Application service interfaces** — `IOrderRepository`, `IEmailSender`, `ICurrentUser`
- **DTOs / ViewModels** — input/output shapes for commands and queries
- **Validators** — FluentValidation `AbstractValidator<TCommand>`
- **Mapping** — AutoMapper profiles or manual projection methods

#### Infrastructure Layer
Implements application-layer interfaces using concrete technologies. Depends on `Application` and `Domain`:
- **Persistence** — EF Core `DbContext`, repository implementations
- **External HTTP** — `HttpClient`-based API clients
- **Messaging** — MassTransit consumers, Azure Service Bus senders
- **Email** — SendGrid / SMTP senders
- **File storage** — Azure Blob, S3 adapters

#### API / Presentation Layer
Composition root and delivery mechanism. Depends on `Infrastructure` and `Application`:
- **Controllers / Minimal API endpoints**
- **`Program.cs`** — `WebApplicationBuilder`, DI registration, middleware pipeline
- **Auth / middleware** — JWT validation, CORS, rate limiting
- **OpenAPI / Swagger** configuration

### Project Reference Rules (Enforced at Compile Time)

```
YourApp.Domain         → (no references)
YourApp.Application    → YourApp.Domain
YourApp.Infrastructure → YourApp.Application
YourApp.Api            → YourApp.Infrastructure
                       → YourApp.Application  (for DI extension methods)
```

`Application` never references `Infrastructure`. `Domain` never references anything.

### DI Composition Root Pattern

Register everything in `Program.cs` via extension methods:

```csharp
// Infrastructure/DependencyInjection.cs
public static class InfrastructureServices
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration config)
    {
        services.AddDbContext<AppDbContext>(o =>
            o.UseSqlServer(config.GetConnectionString("Default")));

        services.AddScoped<IOrderRepository, EfOrderRepository>();
        services.AddScoped<IEmailSender, SendGridEmailSender>();
        return services;
    }
}

// Application/DependencyInjection.cs
public static class ApplicationServices
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());
        services.AddValidatorsFromAssemblyContaining<PlaceOrderCommandValidator>();
        return services;
    }
}

// Program.cs — composition root
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);
```

### Typical Folder Structure

```
src/
  YourApp.Domain/
    Entities/
      Order.cs
      Customer.cs
    ValueObjects/
      Money.cs
    Events/
      OrderPlacedEvent.cs
  YourApp.Application/
    Features/Orders/
      Commands/PlaceOrder/
        PlaceOrderCommand.cs
        PlaceOrderHandler.cs
        PlaceOrderValidator.cs
      Queries/GetOrder/
        GetOrderQuery.cs
        GetOrderHandler.cs
        OrderDto.cs
    Contracts/
      IOrderRepository.cs
      IEmailSender.cs
  YourApp.Infrastructure/
    Persistence/
      AppDbContext.cs
      Repositories/EfOrderRepository.cs
      Configurations/OrderConfiguration.cs
    Email/
      SendGridEmailSender.cs
  YourApp.Api/
    Program.cs
    Controllers/OrdersController.cs
tests/
  YourApp.Domain.Tests/
  YourApp.Application.Tests/    ← unit tests, no infrastructure
  YourApp.Integration.Tests/    ← real DB via Testcontainers
```

## Code Example

```csharp
// ── Domain/Entities/Order.cs ──────────────────────────────────────
namespace YourApp.Domain.Entities;

public class Order
{
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public decimal Total { get; private set; }
    public string Status { get; private set; } = "Pending";
    private readonly List<DomainEvent> _events = [];
    public IReadOnlyList<DomainEvent> DomainEvents => _events;

    public Order(int customerId, decimal total)
    {
        if (total <= 0) throw new ArgumentOutOfRangeException(nameof(total));
        CustomerId = customerId;
        Total = total;
        _events.Add(new OrderPlacedEvent(Id, customerId, total));
    }
}

// ── Application/Contracts/IOrderRepository.cs ────────────────────
namespace YourApp.Application.Contracts;

public interface IOrderRepository
{
    Task AddAsync(Order order, CancellationToken ct = default);
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
}

// ── Application/Features/Orders/Commands/PlaceOrder ──────────────
namespace YourApp.Application.Features.Orders.Commands;

public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

public class PlaceOrderHandler(IOrderRepository orders) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order(cmd.CustomerId, cmd.Total);
        await orders.AddAsync(order, ct);
        return order.Id;
    }
}

// ── Infrastructure/Persistence/EfOrderRepository.cs ──────────────
namespace YourApp.Infrastructure.Persistence;

public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task AddAsync(Order order, CancellationToken ct)
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
    }

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders.FindAsync([id], ct).AsTask();
}

// ── Api/Controllers/OrdersController.cs ──────────────────────────
[ApiController, Route("api/orders")]
public class OrdersController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct);
        return CreatedAtAction(nameof(Create), new { id }, id);
    }
}
```

## Common Follow-up Questions

- Where should cross-cutting concerns (logging, authorization checks) live in Clean Architecture?
- How do you handle domain events — dispatch in the handler or in `SaveChangesAsync`?
- Is it acceptable to skip the Domain layer for simple CRUD features?
- How do you prevent the Application layer from becoming a dumping ground for business logic?
- How does Clean Architecture compare to Vertical Slice Architecture for feature cohesion?

## Common Mistakes / Pitfalls

- **Business logic bleeding into controllers**: validation and domain decisions made in `ApiController` methods bypass the Application layer and can't be reused by background jobs or tests.
- **Application layer importing infrastructure NuGet packages**: if `YourApp.Application.csproj` has `<PackageReference Include="Microsoft.EntityFrameworkCore" />`, the layer is no longer infrastructure-independent.
- **Every feature getting its own repository interface**: `IProductRepository`, `IOrderRepository`, `ICustomerRepository` each with identical CRUD signatures is a sign you need a generic repository or should reconsider the pattern.
- **Skipping the domain layer for complex business rules**: putting invariant enforcement in a `PlaceOrderHandler` rather than `Order.Place()` means the rule can be bypassed by any handler that directly manipulates the order.

## References

- [Clean Architecture with ASP.NET Core 8 — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
- [ardalis/CleanArchitecture — Reference template (GitHub)](https://github.com/ardalis/CleanArchitecture)
- [jasontaylordev/CleanArchitecture — Popular .NET template](https://github.com/jasontaylordev/CleanArchitecture)
- [See: layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md)
- [See: application-layer-responsibilities.md](./application-layer-responsibilities.md)
