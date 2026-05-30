# Repository Pattern (DDD)

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `repository-pattern`, `aggregate-root`, `IRepository`, `persistence-abstraction`, `EF-Core`

## Question

> What is the Repository pattern in DDD? How is it different from a generic CRUD repository? How do you implement a DDD-style repository for an aggregate root in .NET using EF Core?

## Short Answer

A DDD Repository abstracts the persistence of an **aggregate root** — it presents the illusion that aggregates exist in an in-memory collection. Unlike a generic CRUD repository, a DDD repository is **domain-oriented**: the interface is defined in the domain/application layer in the Ubiquitous Language, exposes only methods meaningful to the domain (`GetByIdAsync`, `FindByEmailAsync`, `AddAsync`, `SaveAsync`), and never exposes `IQueryable` or database-specific types. There is one repository per aggregate root, not per database table.

## Detailed Explanation

### DDD Repository vs Generic CRUD Repository

| Aspect | Generic CRUD Repository | DDD Repository |
|--------|------------------------|----------------|
| Interface location | Often Infrastructure | Domain or Application layer |
| Methods | `GetAll`, `GetById`, `Insert`, `Update`, `Delete` | Domain-language methods: `FindActiveOrders`, `GetByCustomerId` |
| `IQueryable` exposure | Often returns `IQueryable<T>` | Never exposes `IQueryable` |
| Granularity | One per entity/table | One per aggregate root |
| Unit of Work | Sometimes built in | Explicit, separate concern |
| Testability | Hard (can't fake `IQueryable` easily) | Easy (implement fake in-memory) |

### Defining the Repository Interface

The interface lives in the Application (or Domain) layer — the domain dictates what it needs from persistence:

```csharp
// Application/Contracts/IOrderRepository.cs
// Domain-language interface — no EF Core types
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetByCustomerAsync(CustomerId customerId, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetPendingOlderThanAsync(TimeSpan age, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    void Remove(Order order);
}

// IUnitOfWork — SaveChanges is a separate concern from querying
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
```

### EF Core Implementation

The repository implementation lives in Infrastructure:

```csharp
// Infrastructure/Persistence/EfOrderRepository.cs
public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
        => db.Orders
            .Include(o => o.Lines)   // always load aggregate fully
            .FirstOrDefaultAsync(o => o.Id == id, ct);

    public Task<IReadOnlyList<Order>> GetByCustomerAsync(CustomerId customerId, CancellationToken ct)
        => db.Orders
            .Include(o => o.Lines)
            .Where(o => o.CustomerId == customerId)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct)
            .ContinueWith(t => (IReadOnlyList<Order>)t.Result, ct);

    public Task<IReadOnlyList<Order>> GetPendingOlderThanAsync(TimeSpan age, CancellationToken ct)
    {
        var cutoff = DateTime.UtcNow - age;
        return db.Orders
            .Include(o => o.Lines)
            .Where(o => o.Status == OrderStatus.Pending && o.CreatedAt < cutoff)
            .ToListAsync(ct)
            .ContinueWith(t => (IReadOnlyList<Order>)t.Result, ct);
    }

    public async Task AddAsync(Order order, CancellationToken ct)
        => await db.Orders.AddAsync(order, ct);

    public void Remove(Order order)
        => db.Orders.Remove(order);
}

// AppDbContext implements IUnitOfWork
public class AppDbContext(DbContextOptions<AppDbContext> options) 
    : DbContext(options), IUnitOfWork
{
    public DbSet<Order> Orders => Set<Order>();
    // SaveChangesAsync inherited from DbContext
}
```

### Fake Repository for Unit Tests

The key benefit: write a fast in-memory fake for unit tests:

```csharp
// Tests/Fakes/InMemoryOrderRepository.cs
public class InMemoryOrderRepository : IOrderRepository
{
    private readonly List<Order> _orders = [];

    public Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
        => Task.FromResult(_orders.FirstOrDefault(o => o.Id == id));

    public Task<IReadOnlyList<Order>> GetByCustomerAsync(CustomerId customerId, CancellationToken ct)
        => Task.FromResult<IReadOnlyList<Order>>(
            _orders.Where(o => o.CustomerId == customerId).ToList());

    public Task<IReadOnlyList<Order>> GetPendingOlderThanAsync(TimeSpan age, CancellationToken ct)
    {
        var cutoff = DateTime.UtcNow - age;
        return Task.FromResult<IReadOnlyList<Order>>(
            _orders.Where(o => o.Status == OrderStatus.Pending && o.CreatedAt < cutoff).ToList());
    }

    public Task AddAsync(Order order, CancellationToken ct)
    {
        _orders.Add(order);
        return Task.CompletedTask;
    }

    public void Remove(Order order) => _orders.Remove(order);

    // Seed helper for tests
    public InMemoryOrderRepository With(params Order[] seed)
    {
        _orders.AddRange(seed);
        return this;
    }
}
```

### One Repository Per Aggregate Root

`OrderLine` is part of the `Order` aggregate. There is NO `IOrderLineRepository`. You access order lines through `Order`:

```csharp
// CORRECT: access order lines through the aggregate root
var order = await orders.GetByIdAsync(orderId, ct);
order.AddLine(productId, quantity, price); // mutate through root
await uow.SaveChangesAsync(ct);

// WRONG: direct OrderLine access bypasses aggregate invariants
// ← no IOrderLineRepository should exist
```

## Code Example

```csharp
// Full use-case showing repository + UoW pattern in a command handler
public class CancelOrderHandler(
    IOrderRepository orders,
    IUnitOfWork uow) : IRequestHandler<CancelOrderCommand>
{
    public async Task Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(new OrderId(cmd.OrderId), ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);

        order.Cancel(cmd.Reason);  // domain enforces: must be pending to cancel

        await uow.SaveChangesAsync(ct);
        // ← Domain events dispatched in SaveChanges interceptor
    }
}

// Application service test using fake repository — no database needed
[Fact]
public async Task CancelOrder_PendingOrder_Succeeds()
{
    var orderId = new OrderId(1);
    var order = Order.Create(new CustomerId(99));
    order.AddLine(new ProductId(1), 2, new Money(50));

    var repo = new InMemoryOrderRepository().With(order);
    var uow = new InMemoryUnitOfWork();

    var handler = new CancelOrderHandler(repo, uow);
    await handler.Handle(new CancelOrderCommand(orderId.Value, "Customer request"), CancellationToken.None);

    Assert.Equal(OrderStatus.Cancelled, order.Status);
    Assert.True(uow.WasSaved);
}
```

## Common Follow-up Questions

- Should `SaveChangesAsync` be in the repository or in a separate `IUnitOfWork`?
- How do you handle aggregate loading performance — should repositories always load the full aggregate with all children?
- How does the DDD repository pattern relate to the `DbContext` — is `DbContext` itself a repository?
- When is it acceptable to skip the repository and call `DbContext` directly from a handler?
- How do you use the Specification pattern with repositories to avoid interface explosion?

## Common Mistakes / Pitfalls

- **Returning `IQueryable<T>` from repository methods**: this couples callers to LINQ-to-EF semantics, leaking EF Core behaviour into the Application layer and making the fake repository impossible to write correctly.
- **One repository per database table**: creating `IOrderLineRepository` breaks the aggregate boundary — order lines must only be modified through the `Order` aggregate root.
- **Repository with 30 methods**: if every query variation gets its own method, the interface becomes a dumping ground. Use the Specification pattern for dynamic filtering, or accept that read-model queries can bypass the repository entirely (CQRS).
- **Injecting `AppDbContext` directly into application handlers**: this couples handlers to EF Core, prevents unit testing without a database, and often signals that the repository layer is being skipped.

## References

- [Repository pattern in DDD — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [See: specification-pattern.md](./specification-pattern.md)
- [See: unit-of-work-pattern.md](../04-data-access/unit-of-work-pattern.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: generic-vs-specific-repository.md](../04-data-access/generic-vs-specific-repository.md)
