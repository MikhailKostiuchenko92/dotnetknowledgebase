# Specification Pattern in Data Access

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🔴 Senior
**Tags:** `specification-pattern`, `DDD`, `repository-pattern`, `IQueryable`, `Ardalis.Specification`, `composable-queries`

## Question

> What is the Specification pattern in the context of data access? How does it solve the `IQueryable` leakage problem in generic repositories? How does `Ardalis.Specification` implement it, and when is it appropriate?

## Short Answer

The Specification pattern encapsulates a query predicate and associated options (criteria, ordering, includes, pagination) into a reusable, named object — `ActiveOrdersForCustomerSpecification(customerId)`. A generic repository accepts specifications and applies them internally, keeping the query logic inside the domain/application layer while keeping `IQueryable` and `Include` out of callers. `Ardalis.Specification` (a popular library) provides the `Specification<T>` base class with a fluent builder DSL. The pattern shines when you have many related queries on the same aggregate that need to be reused across handlers, combined, and unit-tested in isolation.

## Detailed Explanation

### The Problem Specifications Solve

Generic repositories either:
1. Expose `IQueryable<T>` (leaks EF Core to callers), or
2. Add one method per use-case (interface explosion)

Specifications offer a third path: the repository interface is stable (`FindAsync(ISpecification<T>)`), and callers create named objects that describe what they need:

```csharp
// Stable repository interface
public interface IRepository<T> where T : class
{
    Task<T?> FindSingleAsync(ISpecification<T> spec, CancellationToken ct = default);
    Task<IReadOnlyList<T>> FindAllAsync(ISpecification<T> spec, CancellationToken ct = default);
    Task<int> CountAsync(ISpecification<T> spec, CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
}
```

### Basic Specification Contract

```csharp
public interface ISpecification<T>
{
    Expression<Func<T, bool>>? Criteria { get; }                    // WHERE clause
    List<Expression<Func<T, object>>> Includes { get; }             // Include()
    List<string> IncludeStrings { get; }                            // Include("Navigation")
    Expression<Func<T, object>>? OrderBy { get; }
    Expression<Func<T, object>>? OrderByDescending { get; }
    int? Take { get; }
    int? Skip { get; }
    bool AsNoTracking { get; }
}
```

### EF Core Repository Applies the Specification

```csharp
public class Repository<T>(AppDbContext db) : IRepository<T> where T : class
{
    public async Task<IReadOnlyList<T>> FindAllAsync(
        ISpecification<T> spec, CancellationToken ct = default)
    {
        var query = ApplySpecification(spec);
        return await query.ToListAsync(ct);
    }

    private IQueryable<T> ApplySpecification(ISpecification<T> spec)
    {
        var query = spec.AsNoTracking
            ? db.Set<T>().AsNoTracking()
            : db.Set<T>().AsQueryable();

        if (spec.Criteria is not null)
            query = query.Where(spec.Criteria);

        query = spec.Includes.Aggregate(query,
            (q, include) => q.Include(include));

        if (spec.OrderBy is not null)
            query = query.OrderBy(spec.OrderBy);
        else if (spec.OrderByDescending is not null)
            query = query.OrderByDescending(spec.OrderByDescending);

        if (spec.Skip is not null)
            query = query.Skip(spec.Skip.Value);
        if (spec.Take is not null)
            query = query.Take(spec.Take.Value);

        return query;
    }
}
```

### Named Specification Classes

```csharp
public class ActiveOrdersForCustomerSpec : Specification<Order>
{
    public ActiveOrdersForCustomerSpec(int customerId, int page, int size)
    {
        Query
            .Where(o => o.CustomerId == customerId && o.Status != OrderStatus.Archived)
            .Include(o => o.Lines)
            .OrderByDescending(o => o.CreatedAt)
            .Skip((page - 1) * size)
            .Take(size)
            .AsNoTracking();
    }
}

// Usage in application handler — no EF Core reference
var orders = await _orderRepository.FindAllAsync(
    new ActiveOrdersForCustomerSpec(customerId, page: 1, size: 20), ct);
```

### Ardalis.Specification Library

`Ardalis.Specification` provides a production-ready `Specification<T>` base class with EF Core evaluator:

```csharp
// NuGet: Ardalis.Specification + Ardalis.Specification.EntityFrameworkCore
public class PendingOrdersSpec : Specification<Order, OrderSummaryDto>
//                                                     ↑ output projection type
{
    public PendingOrdersSpec(int customerId)
    {
        Query
            .Where(o => o.CustomerId == customerId && o.Status == OrderStatus.Pending)
            .OrderBy(o => o.CreatedAt)
            .Select(o => new OrderSummaryDto(o.Id, o.Reference, o.Total))
            .AsNoTracking();
    }
}

// In the generic EF Core repository:
public async Task<IReadOnlyList<TResult>> FindAllAsync<TResult>(
    Specification<T, TResult> spec, CancellationToken ct = default)
    => await SpecificationEvaluator.GetQuery(db.Set<T>(), spec).ToListAsync(ct);
```

### Unit Testing Specifications

Specifications are plain C# objects — their `Criteria` expression can be tested in-memory:

```csharp
[Fact]
public void PendingOrdersSpec_FiltersCorrectly()
{
    var spec = new PendingOrdersSpec(customerId: 1);
    
    var orders = new List<Order>
    {
        new(id: 1, customerId: 1, status: OrderStatus.Pending),
        new(id: 2, customerId: 1, status: OrderStatus.Completed),
        new(id: 3, customerId: 2, status: OrderStatus.Pending)
    };

    var compiled = spec.WhereExpressions.First().Filter.Compile();
    var result = orders.Where(compiled).ToList();

    Assert.Single(result);
    Assert.Equal(1, result[0].Id);
}
```

## Code Example

```csharp
// Composable specifications — combine for complex scenarios
public class RecentHighValueOrdersSpec : Specification<Order>
{
    public RecentHighValueOrdersSpec(decimal minTotal, int dayCount)
    {
        var since = DateTime.UtcNow.AddDays(-dayCount);
        Query
            .Where(o => o.Total >= minTotal && o.CreatedAt >= since)
            .Include(o => o.Lines)
            .Include(o => o.Customer)
            .OrderByDescending(o => o.Total)
            .Take(100)
            .AsNoTracking();
    }
}

// Handler — no EF Core dependency
public class FraudCheckHandler(IRepository<Order> orders)
{
    public async Task<List<Order>> GetHighValueRecentOrdersAsync(CancellationToken ct)
        => (await orders.FindAllAsync(
            new RecentHighValueOrdersSpec(minTotal: 10_000, dayCount: 7), ct))
            .ToList();
}
```

## Common Follow-up Questions

- How does the Specification pattern relate to the CQRS Query Object pattern?
- What is the difference between `Specification<T>` (filter) and a Query Object (DTO projection)?
- Can specifications be composed (combined with AND/OR) — how?
- What are the performance implications of using specifications vs direct LINQ in EF Core?
- How do you handle pagination metadata (total count) in a repository that uses specifications?

## Common Mistakes / Pitfalls

- **Over-specifying**: creating a specification for every single query, even one-liners used in one place, adds boilerplate with no benefit. Use specifications for reusable, testable, or complex query logic.
- **Mutable specification state**: specifications passed as arguments should be immutable — don't modify a specification object after creation. Build all criteria in the constructor.
- **Ignoring query projection**: a `Specification<T>` that loads the full entity when the caller only needs two columns wastes memory and I/O. Use `Specification<T, TResult>` with `.Select(...)` for projections.
- **Testing specification evaluation with mocked IQueryable**: `List<T>.AsQueryable()` evaluates LINQ in-memory and may behave differently from EF Core's SQL translation (e.g., string comparison case sensitivity). Test complex specifications with integration tests.

## References

- [Ardalis.Specification GitHub](https://github.com/ardalis/Specification)
- [Ardalis.Specification documentation](https://specification.ardalis.com/) (verify URL)
- [Specification pattern — Microsoft Architecture Guide](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design#implementing-the-specification-pattern)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
- [See: generic-vs-specific-repository.md](./generic-vs-specific-repository.md)
