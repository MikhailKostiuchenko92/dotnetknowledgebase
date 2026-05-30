# Onion Architecture

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `onion-architecture`, `jeffrey-palermo`, `clean-architecture`, `hexagonal`, `concentric-rings`, `dependency-rule`

## Question

> What is Onion Architecture? How does it differ from traditional N-tier and from Clean Architecture? What are the concentric rings and what lives in each?

## Short Answer

Onion Architecture (Jeffrey Palermo, 2008) organises code as concentric rings with the Domain Model at the center. Each ring can only depend on rings closer to the center — never outward. The rings typically are: **Domain Model** → **Domain Services** → **Application Services** → **Infrastructure / UI** (outermost). It directly implements the Dependency Inversion Principle: all interfaces are defined in the inner rings, and outer rings supply the implementations. Clean Architecture (Uncle Bob, 2012) is a refinement of the same idea with a slightly different ring naming and an explicit "Entities / Use Cases / Interface Adapters / Frameworks" vocabulary.

## Detailed Explanation

### The Concentric Ring Model

```
┌─────────────────────────────────────────────────────┐
│  Infrastructure / UI / Tests                         │
│  ┌───────────────────────────────────────────────┐  │
│  │  Application Services                         │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │  Domain Services                        │  │  │
│  │  │  ┌───────────────────────────────────┐  │  │  │
│  │  │  │  Domain Model (Entities + VOs)    │  │  │  │
│  │  │  └───────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
         ← all dependencies point inward
```

### Ring Responsibilities

| Ring | Contents | Can reference |
|------|----------|---------------|
| **Domain Model** | Entities, Value Objects, aggregates | Nothing |
| **Domain Services** | Pure business operations spanning aggregates; repository *interfaces* | Domain Model |
| **Application Services** | Use-case orchestration, DTO mapping, email/notification interfaces | Domain Services + Domain Model |
| **Infrastructure / UI** | EF Core repos, HTTP controllers, message consumers, file adapters | All inner rings |

### Key Insight: Interfaces in Inner Rings

The critical difference from N-tier: `IOrderRepository` is defined in the **Domain Services** ring (or Application Services ring), not in Infrastructure. Infrastructure *implements* it. This means:

- Swapping SQL Server for Cosmos DB = rewrite the Infrastructure ring only
- Testing Application Services = inject a fake `IOrderRepository` from Infrastructure ring (in-memory)
- Domain model tests = pure unit tests, no database, no DI

### Onion vs N-Tier vs Clean Architecture

| Aspect | N-Tier | Onion Architecture | Clean Architecture |
|--------|--------|-------------------|--------------------|
| Origin | 1990s enterprise patterns | Jeffrey Palermo, 2008 | Robert C. Martin, 2012 |
| Shape | Horizontal layers | Concentric rings | Concentric rings |
| Dependency direction | Top → Bottom | Inward | Inward |
| Domain model purity | Not enforced | Enforced | Enforced |
| Repository interface location | DAL (bottom layer) | Domain/Application ring | Application ring |
| Ring granularity | 3 layers (UI/BLL/DAL) | 4 rings (domain model/domain svc/app svc/infra) | 4 rings (entities/use cases/adapters/frameworks) |
| Naming | Presentation, Business Logic, Data Access | Domain, Domain Services, Application Services, Infrastructure | Entities, Use Cases, Interface Adapters, Frameworks & Drivers |

The core ideas are identical: **keep business logic at the center, isolate it from infrastructure with interfaces, all dependencies point inward**. The terminology is different.

### Common Misconceptions

**"Onion Architecture means I need 4+ projects"** — False. The rings are logical separations. You can implement Onion in a single project with namespaces/folders that enforce the dependency rule via tools like NetArchTest. Multiple projects enforce it at the compiler level.

**"Onion and Clean Architecture are the same"** — Structurally very similar, but not identical. Palermo's "Domain Services" ring explicitly hosts repository interfaces; Martin's version puts use cases in a separate ring from entities and is more explicit about interface adapters (controllers, presenters).

**"Infrastructure and UI are in the same ring"** — Yes, deliberately. Both are "outer world" details. A REST API and a background job processor are both delivery mechanisms. The domain doesn't care which one calls it.

## Code Example

```csharp
// ── Domain Model ring ─────────────────────────────────────────────
namespace YourApp.Domain.Model;

// Aggregate root — pure domain object
public class Product
{
    public int Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public decimal Price { get; private set; }
    public int StockQuantity { get; private set; }

    public void Reserve(int quantity)
    {
        if (quantity > StockQuantity)
            throw new InsufficientStockException(Id, quantity, StockQuantity);
        StockQuantity -= quantity;
    }
}

// ── Domain Services ring ─────────────────────────────────────────
namespace YourApp.Domain.Services;

// Repository interface defined HERE — not in Infrastructure
public interface IProductRepository
{
    Task<Product?> GetByIdAsync(int id, CancellationToken ct = default);
    Task SaveAsync(Product product, CancellationToken ct = default);
}

// Domain service for logic spanning multiple aggregates
public class InventoryAllocationService(IProductRepository products)
{
    public async Task AllocateForOrderAsync(Order order, CancellationToken ct)
    {
        foreach (var line in order.Lines)
        {
            var product = await products.GetByIdAsync(line.ProductId, ct)
                ?? throw new ProductNotFoundException(line.ProductId);
            product.Reserve(line.Quantity);   // domain invariant enforced
            await products.SaveAsync(product, ct);
        }
    }
}

// ── Application Services ring ────────────────────────────────────
namespace YourApp.Application;

public class PlaceOrderUseCase(
    IOrderRepository orders,
    InventoryAllocationService inventory)
{
    public async Task<int> ExecuteAsync(int customerId, List<OrderLineRequest> lines, CancellationToken ct)
    {
        var order = Order.Create(customerId, lines.Select(l => new OrderLine(l.ProductId, l.Quantity)));
        await inventory.AllocateForOrderAsync(order, ct);
        await orders.AddAsync(order, ct);
        return order.Id;
    }
}

// ── Infrastructure ring (outermost) ─────────────────────────────
namespace YourApp.Infrastructure.Persistence;

public class EfProductRepository(AppDbContext db) : IProductRepository
{
    public Task<Product?> GetByIdAsync(int id, CancellationToken ct)
        => db.Products.FindAsync([id], ct).AsTask();

    public async Task SaveAsync(Product product, CancellationToken ct)
    {
        db.Products.Update(product);
        await db.SaveChangesAsync(ct);
    }
}
```

## Common Follow-up Questions

- Where does FluentValidation go in Onion Architecture?
- Should repository interfaces live in the Domain ring or the Application Services ring?
- How does Onion Architecture handle cross-cutting concerns like logging and auditing?
- How do you enforce ring dependencies using tools like NetArchTest in CI?
- What is the practical difference between Onion Architecture and Vertical Slice Architecture?

## Common Mistakes / Pitfalls

- **Circular ring references**: attempting to reference an outer ring from an inner ring (e.g., Domain Services referencing an EF Core entity configuration) violates the entire premise.
- **Fat domain services**: domain services should only contain stateless logic that spans aggregates. If a "domain service" has 20 methods covering CRUD, it's become an application service.
- **Neglecting the Domain Model ring**: treating the Domain Model ring as just data transfer objects (DTOs) rather than true domain entities with behavior leads to an anemic model regardless of ring structure.
- **Confusion with MVC "Models"**: in Onion Architecture, "Domain Model" refers to the rich business model, not ASP.NET Core view models or EF Core data transfer objects.

## References

- [The Onion Architecture — Jeffrey Palermo (original posts)](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/) (verify URL)
- [.NET Architecture Guides — Microsoft](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
- [See: layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: ports-and-adapters.md](./ports-and-adapters.md)
