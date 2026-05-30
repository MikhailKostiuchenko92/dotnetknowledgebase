# Specification Pattern

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `specification-pattern`, `ISpecification`, `Ardalis`, `EF-Core`, `composable-queries`

## Question

> What is the Specification pattern in DDD? How does it help prevent repository interface explosion, and how do you implement it with EF Core using a library like `Ardalis.Specification`?

## Short Answer

The **Specification pattern** (Evans, Fowler) encapsulates a business rule as an object that can evaluate whether an entity satisfies a condition. In a persistence context, specifications are translated to query predicates. Instead of `IOrderRepository` growing a new method for every query variation (`GetPendingOrders`, `GetOrdersByCustomer`, `GetHighValueOrders`), a single `List(spec)` method accepts a specification and returns matching aggregates. `Ardalis.Specification` provides a complete .NET implementation with EF Core `ISpecificationEvaluator` support.

## Detailed Explanation

### The Problem: Repository Method Explosion

```csharp
// Without specifications — interface grows unbounded
public interface IOrderRepository
{
    Task<IReadOnlyList<Order>> GetPendingAsync();
    Task<IReadOnlyList<Order>> GetByCustomerAsync(int customerId);
    Task<IReadOnlyList<Order>> GetHighValueAsync(decimal threshold);
    Task<IReadOnlyList<Order>> GetPendingHighValueByCustomerAsync(int customerId, decimal threshold);
    Task<IReadOnlyList<Order>> GetPendingOlderThanAsync(TimeSpan age);
    // ... 15 more variations
}
```

Every new query requirement adds a new method. The fake repository for unit tests must implement all of them. Compositions become combinatorial explosions.

### Specification as an Object

```csharp
// ISpecification<T> — the contract
public interface ISpecification<T>
{
    Expression<Func<T, bool>>? Criteria { get; }
    List<Expression<Func<T, object>>> Includes { get; }
    Expression<Func<T, object>>? OrderBy { get; }
    Expression<Func<T, object>>? OrderByDescending { get; }
    int? Take { get; }
    int? Skip { get; }
}
```

### With Ardalis.Specification

```bash
dotnet add package Ardalis.Specification
dotnet add package Ardalis.Specification.EntityFrameworkCore
```

```csharp
// Specific spec: encapsulates "pending orders for a customer over a value threshold"
public class PendingHighValueOrdersSpec : Specification<Order>
{
    public PendingHighValueOrdersSpec(CustomerId customerId, Money minimumTotal)
    {
        Query
            .Where(o => o.CustomerId == customerId
                     && o.Status == OrderStatus.Pending
                     && o.Total.Amount >= minimumTotal.Amount)
            .Include(o => o.Lines)
            .OrderByDescending(o => o.Total.Amount);
    }
}

// Usage in handler — no new repo method needed
public class GetHighValuePendingOrdersHandler(IOrderRepository orders)
    : IRequestHandler<GetHighValuePendingOrdersQuery, IReadOnlyList<OrderDto>>
{
    public async Task<IReadOnlyList<OrderDto>> Handle(
        GetHighValuePendingOrdersQuery q, CancellationToken ct)
    {
        var spec = new PendingHighValueOrdersSpec(
            new CustomerId(q.CustomerId),
            new Money(q.MinimumTotal));

        var orders = await _orders.ListAsync(spec, ct);
        return orders.Select(o => new OrderDto(o.Id.Value, o.Total.Amount, o.Status)).ToList();
    }
}
```

### Repository Interface with Specification

```csharp
// Slim repository — ListAsync + GetBySpecAsync cover all query variations
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct = default);
    Task<Order?> GetBySpecAsync(ISpecification<Order> spec, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> ListAsync(ISpecification<Order> spec, CancellationToken ct = default);
    Task<int> CountAsync(ISpecification<Order> spec, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    void Remove(Order order);
}

// EF Core implementation using Ardalis evaluator
public class EfOrderRepository(AppDbContext db) 
    : RepositoryBase<Order>(db), IOrderRepository
{
    // RepositoryBase from Ardalis.Specification.EntityFrameworkCore implements everything
}
```

### Domain-Level Specifications

Specifications can also express business rules without persistence:

```csharp
// Domain specification: can this order be refunded?
public class EligibleForRefundSpecification : Specification<Order>
{
    private static readonly TimeSpan RefundWindow = TimeSpan.FromDays(30);

    public EligibleForRefundSpecification()
    {
        Query.Where(o => o.Status == OrderStatus.Completed
                      && o.CompletedAt > DateTime.UtcNow - RefundWindow);
    }

    // Also useful as a pure predicate without DB
    public bool IsSatisfiedBy(Order order)
        => order.Status == OrderStatus.Completed
        && order.CompletedAt > DateTime.UtcNow - RefundWindow;
}
```

### Composing Specifications

```csharp
// Combining specifications (Ardalis supports And/Or composition)
var forCustomer = new OrdersForCustomerSpec(customerId);
var pending = new PendingOrdersSpec();
var combined = forCustomer.And(pending);  // Ardalis AndSpecification

var orders = await repository.ListAsync(combined, ct);
```

## Code Example

```csharp
// A complete spec with pagination, sorting, and filtering
public class PagedOrdersSpec : Specification<Order, OrderSummaryDto>
{
    public PagedOrdersSpec(int customerId, int page, int pageSize, string? statusFilter)
    {
        Query
            .Where(o => o.CustomerId == new CustomerId(customerId))
            .Where(o => statusFilter == null || o.Status.ToString() == statusFilter)
            .OrderByDescending(o => o.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(o => new OrderSummaryDto(o.Id.Value, o.Total.Amount, o.Status.ToString(), o.CreatedAt));
    }
}

// Result spec → returns DTOs, not domain entities (for read queries)
var spec = new PagedOrdersSpec(customerId: 42, page: 2, pageSize: 20, statusFilter: "Pending");
var dtos = await repository.ListAsync(spec, ct);
```

## Common Follow-up Questions

- When should you use a Specification vs adding a new method to the repository interface?
- Can specifications be reused across different aggregate types?
- How do you unit-test specifications — in memory vs against a real database?
- How does the Specification pattern interact with CQRS read models?
- What is the performance impact of translating specifications to EF Core expressions?

## Common Mistakes / Pitfalls

- **Specifications that do too much**: a spec with 8 optional parameters and conditional query logic is hard to reason about. Prefer multiple specific specs over one mega-spec.
- **Using specs for write-model loading**: specifications are excellent for query projections. For loading an aggregate to mutate it, use `GetByIdAsync` directly — you always want the full aggregate.
- **Leaking specifications to the domain layer**: if a specification uses EF Core `Include()` or `AsNoTracking()`, it's an infrastructure concern and belongs in the Application or Infrastructure layer, not the Domain.
- **Complex spec expressions that can't be translated to SQL**: LINQ expressions in specs must be translatable to SQL. Client-side predicates in specs cause EF Core to load everything and filter in memory.

## References

- [Specification pattern — Ardalis GitHub](https://github.com/ardalis/Specification)
- [Specification pattern — Martin Fowler](https://martinfowler.com/apsupp/spec.pdf) (verify URL)
- [See: repository-pattern.md](./repository-pattern.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: specification-pattern-data-access.md](../04-data-access/specification-pattern-data-access.md)
