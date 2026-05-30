# Repository Anti-Patterns

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🔴 Senior
**Tags:** `repository-pattern`, `anti-patterns`, `IQueryable`, `over-abstraction`, `testability`, `DDD`, `EF Core`

## Question

> What are the most common repository anti-patterns? What is wrong with exposing `IQueryable<T>` from a repository? What does "repository over repository" mean? When does the repository abstraction actually harm testability rather than help it?

## Short Answer

The most common repository anti-patterns: (1) **leaking `IQueryable<T>`** — callers directly compose LINQ queries outside the repository, defeating encapsulation and binding callers to EF Core semantics; (2) **repository-over-repository** — wrapping a repository in another service that's called "repository" but has business logic; (3) **unnecessary abstraction** — adding repository interfaces for simple CRUD apps where `DbContext` is sufficient, creating dead code; (4) **testability false promise** — believing you can mock a repository interface and unit-test complex LINQ queries when the real test value comes from integration tests with a real database.

## Detailed Explanation

### Anti-Pattern 1: Leaking IQueryable<T>

```csharp
// ❌ Anti-pattern — IQueryable leaks EF Core into callers
public interface IOrderRepository
{
    IQueryable<Order> Query();  // ← EF Core/LINQ abstraction escapes the boundary
}

// Usage in caller — now caller needs EF Core knowledge:
var orders = _repo.Query()
    .Include(o => o.Lines)          // EF Core specific
    .AsNoTracking()                  // EF Core specific
    .Where(o => o.Status == "Active")
    .OrderByDescending(o => o.CreatedAt)
    .ToListAsync();
```

**Problems**:
- The Application layer now effectively depends on EF Core (via LINQ expression trees)
- `IQueryable` cannot be mocked with simple fakes — `FakeOrderRepository.Query()` returning `List<Order>.AsQueryable()` behaves completely differently from EF Core's `IQueryable` (no translation, no deferred execution semantics)
- Filtering logic is scattered across all callers instead of centralized in the repository

```csharp
// ✅ Correct — specific method with domain-meaningful name
public interface IOrderRepository
{
    Task<IReadOnlyList<Order>> GetActiveOrdersAsync(
        int? customerId = null,
        int page = 1,
        int size = 20,
        CancellationToken ct = default);
}
```

### Anti-Pattern 2: Repository-Over-Repository

```csharp
// ❌ This is not a repository — it's a service disguised as one
public class OrderRepository(AppDbContext db)
{
    public async Task<decimal> CalculateLifetimeValueAsync(int customerId, CancellationToken ct)
    {
        // Business logic inside a repository
        var orders = await db.Orders.Where(o => o.CustomerId == customerId).ToListAsync(ct);
        return orders.Sum(o => o.Total) * GetLtvMultiplier(customerId);
    }

    private decimal GetLtvMultiplier(int customerId) => /* ... business rule ... */;
}
```

Repositories should be **data access only**. Business logic belongs in domain services or application handlers.

### Anti-Pattern 3: Unnecessary Abstraction (Repo for Everything)

```csharp
// ❌ Pure CRUD with no domain logic — repository adds zero value
public interface ICountryRepository
{
    Task<Country?> GetByIdAsync(int id, CancellationToken ct);
    Task<IReadOnlyList<Country>> GetAllAsync(CancellationToken ct);
}

// This is a wrapper around db.Countries — no domain logic, no aggregate boundary
// Callers could use DbContext directly with identical testability (countries are read-only reference data)
```

Ask: "What does this abstraction enable that `DbContext` does not?" For reference data and simple lookups, the answer is often: nothing.

### Anti-Pattern 4: Testability False Promise

```csharp
// Interface mocked in unit test
var mock = new Mock<IOrderRepository>();
mock.Setup(r => r.GetActiveOrdersAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
    .ReturnsAsync([ new Order(/* ... */) ]);

var service = new OrderService(mock.Object);
var result = await service.ProcessAsync(customerId: 1);
Assert.True(result.Success);
```

**Where this fails**: the unit test validates that `OrderService` calls `GetActiveOrdersAsync` and processes the returned data. But it does NOT test:
- Whether `GetActiveOrdersAsync` generates correct SQL
- Whether the SQL returns the right data for the given parameters
- Whether the `Include` graph is loaded correctly

For this reason, complex query logic must be tested via **integration tests** against a real database (SQLite, Testcontainers), not just mocked. The repository mock only tests the orchestration layer.

### Anti-Pattern 5: Loading Full Aggregates When Not Needed

```csharp
// ❌ LoadAsync always loads the entire Order aggregate including lines
public async Task<bool> HasPendingOrdersAsync(int customerId, CancellationToken ct)
{
    var orders = await _repo.GetActiveForCustomerAsync(customerId, ct);
    return orders.Any(o => o.Status == "Pending");  // loads all data just to check .Any()
}

// ✅ Add a specific method or use DbContext directly for the projection
public async Task<bool> HasPendingOrdersAsync(int customerId, CancellationToken ct)
    => await _db.Orders.AnyAsync(
        o => o.CustomerId == customerId && o.Status == "Pending", ct);
```

## Code Example

```csharp
// ✅ Well-designed repository — no anti-patterns
public interface IOrderRepository
{
    // Domain-meaningful methods only — no IQueryable exposed
    Task<Order?> GetWithLinesAsync(int id, CancellationToken ct = default);
    Task<bool> ExistsAsync(int id, CancellationToken ct = default);
    Task<PagedResult<OrderSummary>> SearchAsync(
        OrderSearchCriteria criteria, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    // No SaveChangesAsync here — that's the Unit of Work's job
}

public sealed class OrderRepository(AppDbContext db) : IOrderRepository
{
    // Implementation: focused on data access, no business logic
    public Task<Order?> GetWithLinesAsync(int id, CancellationToken ct = default)
        => db.Orders.Include(o => o.Lines).FirstOrDefaultAsync(o => o.Id == id, ct);

    public Task<bool> ExistsAsync(int id, CancellationToken ct = default)
        => db.Orders.AnyAsync(o => o.Id == id, ct);

    public async Task<PagedResult<OrderSummary>> SearchAsync(
        OrderSearchCriteria criteria, CancellationToken ct = default)
    {
        var query = db.Orders.AsNoTracking();
        if (criteria.CustomerId.HasValue)
            query = query.Where(o => o.CustomerId == criteria.CustomerId);
        if (criteria.Status is not null)
            query = query.Where(o => o.Status == criteria.Status);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(o => o.CreatedAt)
            .Skip((criteria.Page - 1) * criteria.PageSize)
            .Take(criteria.PageSize)
            .Select(o => new OrderSummary(o.Id, o.Reference, o.Total, o.Status))
            .ToListAsync(ct);

        return new PagedResult<OrderSummary>(items, total, criteria.Page, criteria.PageSize);
    }

    public Task AddAsync(Order order, CancellationToken ct = default)
    {
        db.Orders.Add(order);
        return Task.CompletedTask;  // SaveChanges is UoW responsibility
    }
}
```

## Common Follow-up Questions

- What is the Specification pattern, and does it solve the `IQueryable` leakage problem?
- How do you decide which queries belong in the repository vs directly in a query handler?
- When is it acceptable to skip the repository layer entirely and use `DbContext` in a CQRS query handler?
- How do you prevent the repository from growing into a "God class" over time?
- How does the Repository pattern interact with Domain Events — should repositories dispatch them?

## Common Mistakes / Pitfalls

- **Adding `GetAll()` or `GetAllAsync()` without pagination**: loading an entire table into memory is a latent performance bomb. Every repository query that can return multiple rows should accept pagination or explicit limit parameters.
- **Putting `SaveChangesAsync` inside repository methods**: makes it impossible to batch multiple repository operations in one database transaction. Commit is the Unit of Work's responsibility.
- **Using Moq on repository interfaces and calling it "fully tested"**: mock-based tests only test the orchestration contract — they don't validate the actual SQL or data returned. Complex repositories need integration tests.
- **Designing repository interfaces for database tables, not aggregates**: `ILineItemRepository`, `IOrderHeaderRepository`, and `IOrderPaymentRepository` are all part of the Order aggregate and should be encapsulated in one `IOrderRepository`.

## References

- [Repository pattern — Microsoft Architecture Guide](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- ["Is the Repository pattern worth it?" — Jimmy Bogard blog](https://jimmybogard.com/life-beyond-transactions-implementation-primer/) (verify URL)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
- [See: generic-vs-specific-repository.md](./generic-vs-specific-repository.md)
- [See: repository-with-ef-core.md](./repository-with-ef-core.md)
