# Generic vs Specific Repository

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🟡 Middle
**Tags:** `repository-pattern`, `generic-repository`, `aggregate`, `DDD`, `EF Core`, `IRepository`

## Question

> What is a generic repository (`IRepository<T>`)? What are its advantages and disadvantages compared to specific (aggregate-focused) repositories? Should you use one or the other — or both?

## Short Answer

A **generic repository** (`IRepository<T>`) provides CRUD operations for any entity type via a single interface, reducing boilerplate. The downside: it leaks infrastructure concerns (returning `IQueryable<T>`) or becomes a lowest-common-denominator abstraction that forces awkward query expression via generic filter parameters. **Specific repositories** expose domain-meaningful query methods (`GetActiveOrdersForCustomer`, `FindByEmail`) — callers get clear intent and don't need to know filtering logic. The pragmatic approach: a generic base for standard CRUD + specific interfaces that add domain-meaningful methods per aggregate.

## Detailed Explanation

### Generic Repository

```csharp
// Generic interface — one for all entity types
public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    Task UpdateAsync(T entity, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}

// EF Core generic implementation
public class Repository<T>(AppDbContext db) : IRepository<T> where T : class
{
    protected readonly DbSet<T> Set = db.Set<T>();

    public async Task<T?> GetByIdAsync(int id, CancellationToken ct = default)
        => await Set.FindAsync([id], ct);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default)
        => await Set.AsNoTracking().ToListAsync(ct);

    public async Task AddAsync(T entity, CancellationToken ct = default)
        => await Set.AddAsync(entity, ct);

    public async Task UpdateAsync(T entity, CancellationToken ct = default)
        => Set.Update(entity);

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        var entity = await GetByIdAsync(id, ct);
        if (entity is not null) Set.Remove(entity);
    }
}
```

**Problems with pure generic repository:**
- No way to express domain queries without exposing `IQueryable<T>` or a Specification
- `GetAllAsync` on a large table is dangerous (loads everything into memory)
- Forces either a leaky abstraction or a complex specification/query object system

### Specific Repository — Domain Intent

```csharp
// Expresses what the domain needs, not how to get it
public interface IOrderRepository
{
    Task<Order?> GetWithLinesAsync(int id, CancellationToken ct = default);
    Task<PagedResult<Order>> GetActiveForCustomerAsync(
        int customerId, int page, int size, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetPendingOlderThanAsync(
        TimeSpan age, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
}
```

Every method has a clear business name. The caller doesn't need to know about `Include`, `AsNoTracking`, or `Where`.

### Hybrid Pattern — Generic Base + Specific Extensions

The most pragmatic approach in a medium-sized codebase:

```csharp
// Generic base handles standard CRUD
public interface IRepository<T, TId> where T : class
{
    Task<T?> GetByIdAsync(TId id, CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    Task DeleteAsync(TId id, CancellationToken ct = default);
}

// Specific interface extends with domain methods
public interface IOrderRepository : IRepository<Order, int>
{
    Task<Order?> GetWithLinesAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetPendingForFulfillmentAsync(CancellationToken ct = default);
}

// Implementation inherits generic EF implementation and adds specifics
public class OrderRepository(AppDbContext db)
    : Repository<Order, int>(db), IOrderRepository
{
    public async Task<Order?> GetWithLinesAsync(int id, CancellationToken ct = default)
        => await Set
            .Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task<IReadOnlyList<Order>> GetPendingForFulfillmentAsync(CancellationToken ct = default)
        => await Set
            .Where(o => o.Status == OrderStatus.Pending
                     && o.CreatedAt < DateTime.UtcNow.AddHours(-1))
            .OrderBy(o => o.CreatedAt)
            .AsNoTracking()
            .ToListAsync(ct);
}
```

### IQueryable Leakage — Why to Avoid It

Some generic repositories expose `IQueryable<T>`:
```csharp
// ❌ Leaky generic repository — IQueryable is an EF Core abstraction
public interface IRepository<T>
{
    IQueryable<T> Query();
}

// Callers must know EF Core details to use it
var orders = repo.Query()
    .Include(o => o.Lines)  // EF Core specific
    .AsNoTracking()          // EF Core specific
    .Where(o => o.Status == "Pending")
    .ToList();
```

This defeats the purpose of the repository — the caller has a direct dependency on EF Core semantics even through the interface.

## Code Example

```csharp
// Registration — specific interfaces, backed by EF Core implementations
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();

// Or register the generic base for simple entities that don't need specific queries
builder.Services.AddScoped(typeof(IRepository<,>), typeof(Repository<,>));
```

## Common Follow-up Questions

- How does the Specification pattern solve the "generic repository can't express domain queries" problem?
- Is using EF Core's `DbContext` directly (without a repository) ever a better choice?
- How do you handle aggregate root constraints when a generic repository allows modifying child entities directly?
- What is the `Ardalis.Specification` library, and how does it integrate with the generic repository?
- How do you prevent generic repositories from becoming "god objects" over time?

## Common Mistakes / Pitfalls

- **Exposing `IQueryable<T>` from the repository interface**: leaks EF Core semantics into the application/domain layer — callers must add `Include`, `AsNoTracking`, etc. outside the repository, defeating encapsulation.
- **`GetAllAsync()` without pagination**: a generic `GetAllAsync` that loads all rows into memory is a performance bomb on large tables. Always add pagination or filtering to queries that might return many rows.
- **One generic repository for non-aggregate entities**: the repository pattern should map to aggregates (Order + OrderLines together), not to individual tables. A `LineItemRepository` alongside `OrderRepository` violates the aggregate boundary.
- **Registering `IRepository<Order>` AND `IOrderRepository`**: having two registrations for the same aggregate causes confusion about which one to inject. Pick one pattern per aggregate.

## References

- [Repository pattern — .NET Architecture Guide — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [Ardalis.Specification GitHub](https://github.com/ardalis/Specification)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
- [See: specification-pattern-data-access.md](./specification-pattern-data-access.md)
- [See: repository-anti-patterns.md](./repository-anti-patterns.md)
