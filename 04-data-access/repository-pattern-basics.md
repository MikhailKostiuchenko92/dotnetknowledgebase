# Repository Pattern Basics

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🟢 Junior
**Tags:** `repository-pattern`, `DDD`, `persistence`, `abstraction`, `domain`, `EF Core`

## Question

> What is the Repository pattern? Why would you use it, and what problem does it solve? What does a basic repository interface look like in a .NET application?

## Short Answer

The Repository pattern introduces an abstraction layer between the domain model and the data access technology. It presents the data store as a collection of domain objects — the caller works with strongly-typed domain types via methods like `GetByIdAsync`, `AddAsync`, or `FindAsync` without knowing whether the data comes from SQL Server, MongoDB, or a stub. The main benefits are: (1) domain logic isn't polluted with data access concerns, (2) the persistence technology can change without altering domain code, and (3) repositories can be swapped with in-memory fakes for unit testing.

## Detailed Explanation

### Problem Without the Pattern

```csharp
// Domain service directly coupled to EF Core
public class OrderService(AppDbContext db)
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct)
    {
        // Domain service knows about DbContext, Include(), AsNoTracking() — infrastructure leaks in
        return await db.Orders
            .Include(o => o.Lines)
            .AsNoTracking()
            .FirstOrDefaultAsync(o => o.Id == id, ct);
    }
}
```

The service can never be unit tested without a real database.

### Repository Interface — Domain-Oriented

```csharp
// Domain layer (no EF Core reference)
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetActiveForCustomerAsync(int customerId, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    Task UpdateAsync(Order order, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}
```

The interface lives in the **domain** or **application** project. It has no reference to EF Core, Dapper, or any infrastructure package.

### EF Core Implementation

```csharp
// Infrastructure project — implements the interface using EF Core
public sealed class OrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct = default)
        => await db.Orders
            .Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task<IReadOnlyList<Order>> GetActiveForCustomerAsync(
        int customerId, CancellationToken ct = default)
        => await db.Orders
            .Where(o => o.CustomerId == customerId && o.Status != OrderStatus.Archived)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct);

    public async Task AddAsync(Order order, CancellationToken ct = default)
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(Order order, CancellationToken ct = default)
    {
        db.Orders.Update(order);
        await db.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        await db.Orders
            .Where(o => o.Id == id)
            .ExecuteDeleteAsync(ct);
    }
}
```

### Unit Testing with In-Memory Fake

```csharp
// Fake for unit tests — no database needed
public sealed class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _orders = [];

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct = default)
        => Task.FromResult(_orders.FirstOrDefault(o => o.Id == id));

    public Task<IReadOnlyList<Order>> GetActiveForCustomerAsync(int customerId, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Order>>(
            _orders.Where(o => o.CustomerId == customerId).ToList());

    public Task AddAsync(Order order, CancellationToken ct = default)
    {
        _orders.Add(order);
        return Task.CompletedTask;
    }

    public Task UpdateAsync(Order order, CancellationToken ct = default)
    {
        var idx = _orders.FindIndex(o => o.Id == order.Id);
        if (idx >= 0) _orders[idx] = order;
        return Task.CompletedTask;
    }

    public Task DeleteAsync(int id, CancellationToken ct = default)
    {
        _orders.RemoveAll(o => o.Id == id);
        return Task.CompletedTask;
    }
}
```

### DI Registration

```csharp
// Program.cs
builder.Services.AddScoped<IOrderRepository, OrderRepository>();

// In tests
services.AddScoped<IOrderRepository, FakeOrderRepository>();
```

## Code Example

```csharp
// Domain service — clean, testable, no EF Core dependency
public class OrderService(IOrderRepository orders, ICustomerRepository customers)
{
    public async Task<OrderDetailDto?> GetDetailAsync(int orderId, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(orderId, ct);
        if (order is null) return null;

        var customer = await customers.GetByIdAsync(order.CustomerId, ct);
        return new OrderDetailDto(order, customer);
    }
}

// Unit test — pure in-memory, no DB
[Fact]
public async Task GetDetail_ReturnsDto_WhenOrderExists()
{
    var fakeOrders = new FakeOrderRepository();
    var fakeCustomers = new FakeCustomerRepository();
    fakeOrders.Seed(new Order(1, customerId: 10, total: 99.99m));
    fakeCustomers.Seed(new Customer(10, name: "Alice"));

    var svc = new OrderService(fakeOrders, fakeCustomers);
    var result = await svc.GetDetailAsync(1, CancellationToken.None);

    Assert.Equal("Alice", result!.CustomerName);
}
```

## Common Follow-up Questions

- What is the difference between a Repository and a DAO (Data Access Object)?
- Should a repository call `SaveChanges` — or is that the Unit of Work's responsibility?
- Is it an anti-pattern to expose `IQueryable<T>` from a repository?
- How do you handle cross-aggregate queries that span multiple repositories?
- Why is wrapping EF Core's `DbContext` in a repository sometimes called an "anti-pattern"?

## Common Mistakes / Pitfalls

- **Saving inside every repository method**: calling `SaveChangesAsync` in `AddAsync`/`UpdateAsync` makes it impossible to batch multiple repository operations in one transaction. Prefer letting the caller or a Unit of Work control when `SaveChanges` is called.
- **Returning `IQueryable<T>` from the repository**: this leaks the ORM abstraction — callers can add `.Include()`, `.Where()`, `.AsNoTracking()` outside the repository, defeating the encapsulation purpose.
- **One repository per table**: the repository pattern maps to **aggregates**, not tables. An `OrderRepository` may query `Orders`, `OrderLines`, and `OrderEvents` internally — they're all part of the Order aggregate.
- **Over-engineering a CRUD app**: for simple CRUD with no complex domain logic, introducing repositories over `DbContext` adds boilerplate with little benefit. Evaluate whether the domain complexity justifies the abstraction.

## References

- [Repository pattern — Microsoft Architecture Guide](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [Repository and Unit of Work patterns — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/mvc/overview/older-versions/getting-started-with-ef-5-using-mvc-4/implementing-the-repository-and-unit-of-work-patterns-in-an-asp-net-mvc-application)
- [See: unit-of-work-pattern.md](./unit-of-work-pattern.md)
- [See: repository-anti-patterns.md](./repository-anti-patterns.md)
