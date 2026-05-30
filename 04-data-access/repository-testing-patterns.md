# Repository Testing Patterns

**Category:** Data Access / Testing Data Access
**Difficulty:** 🟡 Middle
**Tags:** `testing`, `repository-pattern`, `unit-testing`, `integration-testing`, `mocking`, `EF Core`, `test-double`

## Question

> How should you test repositories in a .NET application? When do you test with a real provider (SQLite/Testcontainers) vs using a fake in-memory repository? What is the value of each approach, and what does each validate?

## Short Answer

Repository testing splits into two layers: (1) **Unit tests of the application/service layer** — use a fake (in-memory) repository implementation to verify orchestration logic without a database; (2) **Integration tests of the repository implementation** — use SQLite or Testcontainers to verify the EF Core queries, SQL translation, and database constraints. Mocking `IOrderRepository` with Moq tests only the mock setup, not the actual query. Integration testing the `OrderRepository` class verifies the real SQL it generates and the data it returns.

## Detailed Explanation

### What Each Testing Approach Validates

| Testing approach | Tests | Does NOT test |
|-----------------|-------|---------------|
| Mock (`Moq<IRepository>`) | Service uses repository correctly | SQL correctness, EF Core translation |
| Fake in-memory repository | Service orchestration, domain logic | Database semantics |
| EF Core InMemory provider | Entity tracking, simple LINQ | SQL translation, FK constraints, transactions |
| SQLite in-memory | SQL translation, basic constraints | T-SQL specific functions |
| Testcontainers (real SQL Server) | Full stack — real SQL + constraints + T-SQL | Speed (slow startup) |

### Layer 1: Fake Repository for Service Unit Tests

```csharp
// Fake in-memory implementation — no DB dependency
public class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _store = [];

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct = default)
        => Task.FromResult(_store.FirstOrDefault(o => o.Id == id));

    public Task<IReadOnlyList<Order>> GetActiveForCustomerAsync(
        int customerId, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Order>>(
            _store.Where(o => o.CustomerId == customerId
                           && o.DeletedAt is null).ToList());

    public Task AddAsync(Order order, CancellationToken ct = default)
    {
        order.Id = _store.Count + 1;  // simulate ID generation
        _store.Add(order);
        return Task.CompletedTask;
    }

    // Test helper — not on the interface
    public IReadOnlyList<Order> All => _store;
}

// Service unit test — fast, no DB
[Fact]
public async Task CancelOrder_SetsStatusToCancelled()
{
    var repo = new FakeOrderRepository();
    repo.AddAsync(new Order { Id = 1, CustomerId = 1, Status = "Active" });
    var uow = new FakeUnitOfWork();

    var service = new OrderService(repo, uow);
    await service.CancelAsync(orderId: 1, CancellationToken.None);

    Assert.Equal("Cancelled", repo.All.Single().Status);
    Assert.True(uow.SaveChangesWasCalled);
}
```

### Layer 2: Repository Integration Test (SQLite)

```csharp
// Verifies EF Core query generates correct SQL and returns correct data
public class OrderRepositoryTests : IClassFixture<SqliteTestFixture>
{
    private readonly SqliteTestFixture _fixture;
    public OrderRepositoryTests(SqliteTestFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task GetActiveForCustomer_ExcludesSoftDeleted()
    {
        await using var db = new AppDbContext(_fixture.Options);

        // Seed with mix of active and deleted
        db.Orders.AddRange(
            new Order { CustomerId = 1, Status = "Active", DeletedAt = null },
            new Order { CustomerId = 1, Status = "Active", DeletedAt = DateTime.UtcNow }
        );
        await db.SaveChangesAsync();

        await using var readDb = new AppDbContext(_fixture.Options);
        var repo = new OrderRepository(readDb);

        var active = await repo.GetActiveForCustomerAsync(customerId: 1, CancellationToken.None);

        // Verifies that the global query filter (soft delete) is applied correctly
        Assert.Single(active);
    }

    [Fact]
    public async Task AddOrder_EnforcesCustomerForeignKey()
    {
        await using var db = new AppDbContext(_fixture.Options);
        var repo = new OrderRepository(db);

        // CustomerId 99999 does not exist
        await repo.AddAsync(new Order { CustomerId = 99999, Total = 50m });

        // SQLite enforces FK constraints (with PRAGMA foreign_keys = ON)
        // This test validates the FK constraint is in place
        await Assert.ThrowsAsync<DbUpdateException>(
            async () => await db.SaveChangesAsync());
    }
}
```

### What NOT to Test at the Repository Level

- **Business rules that belong in domain objects**: testing `Order.CanBeCancelled()` in an `OrderRepository` test is testing the wrong thing.
- **EF Core infrastructure itself**: don't test that `db.Orders.Add(entity)` works — that's EF Core's responsibility.
- **Mock-based repository tests**: `mock.Verify(r => r.AddAsync(...))` verifies the service calls the repository but not that the repository is correct.

### Test Pyramid for Data Access

```
         ┌─────────────────────┐
         │  E2E / API tests    │  (Testcontainers, real HTTP)
         ├─────────────────────┤
         │ Integration tests   │  (Testcontainers / SQLite — repository impl)
         ├─────────────────────┤
         │    Unit tests       │  (Fakes — service/domain logic)
         └─────────────────────┘
```

## Code Example

```csharp
// Complete test file demonstrating both layers in the same suite

// Layer 1: Unit test with fake — fast, no database
public class OrderServiceTests
{
    [Fact]
    public async Task PlaceOrder_CreatesOrderAndCommits()
    {
        var repo = new FakeOrderRepository();
        var uow = new FakeUnitOfWork();
        var service = new OrderService(repo, uow);

        await service.PlaceOrderAsync(new CreateOrderRequest(CustomerId: 1, Total: 99m));

        Assert.Single(repo.All);
        Assert.True(uow.SaveChangesWasCalled);
    }
}

// Layer 2: Integration test — verifies real EF Core SQL behavior
public class OrderRepositoryIntegrationTests(SqliteTestFixture fx)
    : IClassFixture<SqliteTestFixture>
{
    [Fact]
    public async Task GetPaginated_ReturnsSortedResults()
    {
        await using var db = new AppDbContext(fx.Options);
        db.Orders.AddRange(
            new Order { CustomerId = 1, Total = 30m, CreatedAt = DateTime.UtcNow.AddDays(-3) },
            new Order { CustomerId = 1, Total = 10m, CreatedAt = DateTime.UtcNow.AddDays(-1) },
            new Order { CustomerId = 1, Total = 20m, CreatedAt = DateTime.UtcNow.AddDays(-2) }
        );
        await db.SaveChangesAsync();

        await using var db2 = new AppDbContext(fx.Options);
        var repo = new OrderRepository(db2);
        var results = await repo.GetActiveForCustomerAsync(
            customerId: 1, page: 1, size: 10, CancellationToken.None);

        // Verify sort order is enforced by the repository
        Assert.Equal(3, results.Count);
        Assert.True(results[0].CreatedAt > results[1].CreatedAt);
    }
}
```

## Common Follow-up Questions

- How do you test repositories that use `FromSqlRaw` or `ExecuteSqlRaw`?
- Should repository integration tests test every method, or just the complex ones?
- How do you handle seeding prerequisite data (e.g., Customer before Order) in repository tests?
- Is it ever acceptable to use `Moq` on `IRepository` interfaces instead of a hand-written fake?
- How do you test a repository's behavior when a concurrency conflict occurs (`DbUpdateConcurrencyException`)?

## Common Mistakes / Pitfalls

- **Only writing mock-based repository tests**: mocking `IRepository.GetByIdAsync(1)` to return a specific order doesn't verify the `OrderRepository.GetByIdAsync` implementation at all — only that the service calls it. Always have integration tests for the repository implementation.
- **Putting business logic in repositories and only testing via integration tests**: complex filter logic in the repository is hard to unit test. Keep repositories focused on data access; put business logic in domain objects or services.
- **Not seeding data before querying**: repository tests that `GetActiveForCustomerAsync(1)` without first inserting any orders for customer 1 will always return empty — a vacuously passing test.
- **Using the same `DbContext` instance for seed and query**: EF Core's identity map means the query returns the same tracked instance without hitting the database. Use separate context instances for seed and read to test the actual database query.

## References

- [Testing EF Core applications — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/)
- [Testing without a database — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/testing-without-the-database)
- [See: sqlite-for-testing.md](./sqlite-for-testing.md)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
