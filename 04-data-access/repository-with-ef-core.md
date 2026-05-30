# Repository Pattern with EF Core

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🟡 Middle
**Tags:** `repository-pattern`, `EF Core`, `DbContext`, `abstraction`, `testability`, `CQRS`

## Question

> Should you wrap EF Core's `DbContext` in a repository? What value does the repository abstraction add over using `DbContext` directly? How does the pattern fit into a CQRS architecture?

## Short Answer

EF Core's `DbContext` already implements both the Repository and Unit of Work patterns internally — you can use it directly without adding another layer. The repository abstraction adds value when: (1) the domain layer must not reference EF Core packages (Clean Architecture), (2) you need to mock persistence for unit tests without an in-memory EF provider, or (3) you may switch persistence technology. For a read-heavy CQRS query side, adding a repository layer over `DbContext` is often counterproductive — use `DbContext` or Dapper directly in query handlers. The repository pattern's strongest case is on the **command/write side** for protecting aggregate boundaries.

## Detailed Explanation

### DbContext Used Directly — When It's Fine

For small-to-medium applications, MVC controllers, or Razor Pages without a strict layering requirement:

```csharp
// Controller using DbContext directly — pragmatic for simple CRUD
[ApiController, Route("api/products")]
public class ProductsController(AppDbContext db) : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<IActionResult> GetAsync(int id, CancellationToken ct)
    {
        var product = await db.Products
            .AsNoTracking()
            .Select(p => new ProductDto(p.Id, p.Name, p.Price))
            .FirstOrDefaultAsync(p => p.Id == id, ct);

        return product is null ? NotFound() : Ok(product);
    }
}
```

**This is acceptable** when:
- Domain logic is simple (CRUD-oriented)
- The project is small or a microservice with a single concern
- You are not doing DDD with aggregate boundaries

### Repository for Write Side — Clean Architecture

In Clean Architecture, the **Application** layer defines the use-case, the **Domain** layer holds domain models, and the **Infrastructure** layer holds EF Core. The repository interface bridges Application → Infrastructure:

```
Application/
  └── PlaceOrderHandler.cs         (uses IOrderRepository)
Domain/
  └── IOrderRepository.cs          (interface — no EF Core)
Infrastructure/
  └── OrderRepository.cs           (EF Core implementation)
```

```csharp
// Application/PlaceOrderHandler.cs
public class PlaceOrderHandler(IOrderRepository orders, IUnitOfWork uow)
{
    public async Task HandleAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Lines);
        await orders.AddAsync(order, ct);
        await uow.SaveChangesAsync(ct);
    }
}
```

The `PlaceOrderHandler` project references only `Domain` — not EF Core. Swapping the persistence implementation requires only changing the DI registration.

### Repository NOT on the Read Side (CQRS)

On the read side (queries), repositories add unnecessary indirection — query handlers know what data they need and how it should be shaped:

```csharp
// ❌ Redundant repository abstraction for reads
public interface IOrderReadRepository
{
    Task<OrderDashboardDto> GetDashboardAsync(int customerId, CancellationToken ct);
}
// This just wraps a DbContext call — adds a file/interface with no testability or portability benefit

// ✅ Query handler uses DbContext or Dapper directly
public class GetOrderDashboardHandler(AppDbContext db)
{
    public async Task<OrderDashboardDto> HandleAsync(
        GetOrderDashboardQuery query, CancellationToken ct)
    {
        return await db.Orders
            .AsNoTracking()
            .Where(o => o.CustomerId == query.CustomerId)
            .GroupBy(_ => 1)
            .Select(g => new OrderDashboardDto(
                g.Count(),
                g.Sum(o => o.Total),
                g.Count(o => o.Status == "Pending")))
            .SingleAsync(ct);
    }
}
```

### Testing — When the Repository Matters

The repository's primary value is **unit testing** without a real database:

```csharp
// With repository interface — unit test is pure in-memory
[Fact]
public async Task PlaceOrder_SavesOrderAndDecrementsInventory()
{
    var orders = new FakeOrderRepository();
    var inventory = new FakeInventoryRepository();
    inventory.Seed(new InventoryItem(productId: 1, quantity: 10));

    var uow = new FakeUnitOfWork();
    var handler = new PlaceOrderHandler(orders, inventory, uow);

    await handler.HandleAsync(new PlaceOrderCommand(customerId: 1,
        Lines: [new(ProductId: 1, Quantity: 2)]), CancellationToken.None);

    Assert.Single(orders.All);
    Assert.Equal(8, inventory.GetQuantity(productId: 1));
    Assert.True(uow.SaveChangesWasCalled);
}
```

Without the repository interface, this test requires an in-memory EF Core provider or SQL Server — slower and more fragile.

### Summary — When to Use Repository over Direct DbContext

| Scenario | Direct DbContext | Repository |
|----------|----------------|-----------|
| Simple CRUD API | ✅ | Over-engineering |
| Domain with rich business rules | ⚠️ Couples domain to EF | ✅ |
| Unit-testable command handlers | ❌ Needs InMemory provider | ✅ |
| Read/query handlers in CQRS | ✅ Efficient and clear | ❌ Unnecessary |
| Multi-DB portability required | ❌ | ✅ |

## Code Example

```csharp
// Typical Clean Architecture setup — write side uses repository, read side uses DbContext directly
public class OrderCommandService(IOrderRepository orders, IUnitOfWork uow)
{
    public async Task CreateAsync(CreateOrderRequest req, CancellationToken ct)
    {
        var order = Order.Create(req.CustomerId, req.Items);
        await orders.AddAsync(order, ct);
        await uow.SaveChangesAsync(ct);
    }
}

public class OrderQueryService(AppDbContext db)  // ← DbContext directly for reads
{
    public async Task<List<OrderSummary>> GetRecentAsync(
        int customerId, int top, CancellationToken ct)
        => await db.Orders
            .AsNoTracking()
            .Where(o => o.CustomerId == customerId)
            .OrderByDescending(o => o.CreatedAt)
            .Take(top)
            .Select(o => new OrderSummary(o.Id, o.Reference, o.Total))
            .ToListAsync(ct);
}
```

## Common Follow-up Questions

- Is it worth adding a repository abstraction just to switch from EF Core to Dapper someday?
- How do Mediatr `IRequest`/`IRequestHandler` patterns relate to the repository decision?
- How do you handle eager loading of aggregates in a repository without leaking `Include` to the caller?
- Why is the statement "EF Core already IS a repository" not entirely accurate?
- What is the "Screaming Architecture" argument for using `DbContext` directly in handlers?

## Common Mistakes / Pitfalls

- **Adding repository on the read side**: query handlers that use `IOrderRepository.GetDashboardAsync(...)` instead of `DbContext` directly add an extra class per query with no gain — the implementation would just wrap one `DbContext` call.
- **Believing a repository enables swapping databases "for free"**: switching from SQL Server to MongoDB is not just a repository implementation swap — query semantics, transaction support, and data modeling assumptions differ fundamentally.
- **Using the repository as a "service" with business logic**: `OrderRepository.PlaceOrderAsync(...)` is not a repository method — it's a use-case. Keep repositories as data-access only.
- **Forgetting that `DbContext` is already scoped**: some developers create a repository that `new`s its own `DbContext`, bypassing the DI-scoped instance. This breaks change tracking across repositories and makes the UoW pattern impossible.

## References

- [DbContext — Unit of Work and Repository — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/)
- [CQRS and repositories — Microsoft Architecture Guide](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/apply-simplified-microservice-cqrs-ddd-patterns)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
- [See: generic-vs-specific-repository.md](./generic-vs-specific-repository.md)
- [See: unit-of-work-pattern.md](./unit-of-work-pattern.md)
