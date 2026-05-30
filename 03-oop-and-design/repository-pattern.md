# Repository Pattern

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `repository`, `EF-Core`, `persistence`

## Question
> What is the repository pattern in DDD, what problem does it solve, and how does it compare to using `DbContext` directly or creating generic repositories?

## Short Answer
A repository gives the domain or application layer a collection-like interface for loading and saving aggregates without exposing persistence details. In DDD, that can help keep the domain model focused on business rules instead of EF Core concerns. Using `DbContext` directly is often fine in simple applications, while generic repositories frequently become leaky abstractions; typed repositories are usually a better fit when you genuinely need the pattern.

## Detailed Explanation
### What a repository is
A repository is an abstraction over persistence for aggregates. Conceptually, it looks like an in-memory collection: you ask for an aggregate by ID, add a new one, or save changes through a unit of work. The goal is not to hide that a database exists, but to stop the domain model from depending on persistence mechanics.

In DDD, repositories are usually defined per aggregate root, such as `IOrderRepository` or `ICustomerRepository`. That keeps the interface aligned with domain needs instead of raw CRUD mechanics.

### Why teams use repositories
Repositories are useful when you want a clean boundary between domain logic and infrastructure. The application service can say “load order,” “change order,” and “save order” without knowing whether the implementation uses EF Core, Dapper, or another store.

This matters most when aggregates contain behavior and invariants. If business code starts depending on `Include`, tracking state, or LINQ-to-SQL translation quirks, domain logic can become persistence-aware and harder to test.

| Approach | Strengths | Weaknesses | Good fit |
| --- | --- | --- | --- |
| Typed repository | Domain-focused API, clearer boundaries | Extra abstraction | Rich domain model, aggregate access |
| Direct `DbContext` | Simple, fewer layers, full EF power | Couples app code to EF | CRUD apps, simpler modules |
| Generic repository | Reuse and boilerplate reduction | Often leaky and too generic | Rarely ideal for DDD |

### Repository vs direct `DbContext`
A common interview answer is that `DbContext` already behaves somewhat like a unit of work and repository. That is true. In many straightforward ASP.NET Core apps, using `DbContext` directly in handlers or services is completely reasonable.

The question is whether your domain benefits from an explicit abstraction. If your use case is mostly CRUD plus projections, adding a repository layer may only duplicate EF Core. But if you want aggregate-oriented access, intention-revealing methods, and the ability to isolate persistence from the application core, repositories can help.

For example, a typed repository can expose `GetDraftOrderForCheckoutAsync` or `GetByOrderNumberAsync`, which are domain terms, not generic persistence operations.

### Generic vs typed repositories
Generic repositories often look attractive because they reduce repeated code. The problem is that they usually expose methods like `Add`, `Update`, `Delete`, and `GetAll`, which are too generic for DDD. They encourage treating all aggregates as interchangeable data containers.

Typed repositories are usually better because they match aggregate rules and domain language. They also avoid exposing queries that bypass the aggregate model.

> Warning: if your repository returns `IQueryable`, you may be leaking persistence details upward and allowing callers to build arbitrary database queries that bypass your intended boundaries.

### Trade-offs and when not to use repositories
Repositories add indirection. That means more interfaces, more files, and sometimes duplicated query logic. If the module is simple and already centered around EF Core projections, using `DbContext` directly may be cleaner.

In DDD-heavy modules, however, repositories give you a stable place to load and persist aggregates while keeping EF-specific concerns in infrastructure. A common compromise is: use repositories for write-side aggregates, and use direct read models or query handlers for read-side projections.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed class Order(Guid id)
{
    public Guid Id { get; } = id;
    public bool IsSubmitted { get; private set; }

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order already submitted.");
        }

        IsSubmitted = true; // Domain behavior stays on the aggregate.
    }
}

public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task AddAsync(Order order, CancellationToken cancellationToken = default);
    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}

public sealed class InMemoryOrderRepository : IOrderRepository
{
    private readonly Dictionary<Guid, Order> _orders = [];

    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => Task.FromResult(_orders.GetValueOrDefault(id));

    public Task AddAsync(Order order, CancellationToken cancellationToken = default)
    {
        _orders[order.Id] = order;
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
        => Task.CompletedTask; // EF Core implementation would call DbContext.SaveChangesAsync.
}

public static class Program
{
    public static async Task Main()
    {
        IOrderRepository repository = new InMemoryOrderRepository();

        var order = new Order(Guid.NewGuid());
        await repository.AddAsync(order);

        var loadedOrder = await repository.GetByIdAsync(order.Id);
        loadedOrder!.Submit();
        await repository.SaveChangesAsync();

        Console.WriteLine($"Submitted: {loadedOrder.IsSubmitted}");
    }
}
```

## Common Follow-up Questions
- Does EF Core `DbContext` already implement repository and unit of work concepts?
- When is a repository layer unnecessary ceremony?
- Why is returning `IQueryable` from a repository controversial?
- Why are repositories usually defined per aggregate root?
- How would you combine repositories with CQRS read models?

## Common Mistakes / Pitfalls
- Creating a generic repository that exposes only CRUD and loses domain meaning.
- Returning `IQueryable` and effectively leaking EF Core all the way up the stack.
- Putting business logic into repository implementations instead of aggregates or domain services.
- Adding repositories to simple CRUD modules where `DbContext` would be clearer and smaller.
- Using one repository for many unrelated aggregates, which weakens boundaries.

## References
- [Infrastructure persistence layer design](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [DbContext in EF Core](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/)
- [Repository and Unit of Work Pattern](https://learn.microsoft.com/en-us/aspnet/mvc/overview/older-versions/getting-started-with-ef-5-in-mvc4/implementing-the-repository-and-unit-of-work-patterns-in-an-asp-net-mvc-application)
- [Repository](https://martinfowler.com/eaaCatalog/repository.html)
