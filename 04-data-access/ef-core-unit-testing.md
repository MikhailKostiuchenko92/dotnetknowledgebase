# EF Core Unit Testing Strategies

**Category:** Data Access / Testing Data Access
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `unit-testing`, `integration-testing`, `DbContext`, `mocking`, `InMemory`, `SQLite`

## Question

> Why is mocking `DbContext` fragile for unit testing EF Core applications? What is worth unit testing vs integration testing when using EF Core? What are the recommended patterns?

## Short Answer

Mocking `DbContext` or `DbSet<T>` with Moq/NSubstitute is fragile because `DbContext` has a complex internal API surface — `DbSet<T>` is not a simple interface, change tracking, `Include()`, `AsNoTracking()`, and LINQ-to-EF methods all have internal dependencies that mocks cannot replicate. The result: tests pass with the mock but fail against a real database. The recommended approach: mock at the **repository interface** boundary (not DbContext), and use EF Core InMemory or SQLite for testing DbContext-dependent logic. Reserve Testcontainers for T-SQL–specific scenarios.

## Detailed Explanation

### Why Mocking DbContext Fails

```csharp
// ❌ Fragile — mocking DbSet<Order>
var mockSet = new Mock<DbSet<Order>>();
var mockContext = new Mock<AppDbContext>();
mockContext.Setup(c => c.Orders).Returns(mockSet.Object);

// This won't work for async queries:
var result = await db.Orders.Where(o => o.Status == "Active").ToListAsync();
// ToListAsync calls IAsyncEnumerable internals that the mock doesn't implement
// → throws NotImplementedException or returns empty results silently
```

EF Core's `DbSet<T>`:
- Implements `IQueryable<T>` backed by a real query provider
- Implements `IAsyncEnumerable<T>` for async LINQ
- Exposes internal EF Core state machine
- Mocking all of this correctly requires implementing dozens of internal interfaces

### What's Worth Unit Testing vs Integration Testing

| What to test | Approach | Why |
|-------------|---------|-----|
| Service orchestration (calls repo, commits UoW) | Unit test with fake `IRepository` | No DB needed |
| Domain logic (entity methods, domain rules) | Unit test with `new Order()` in memory | Pure .NET objects |
| LINQ query translation to SQL | Integration test (SQLite/Testcontainers) | SQL translation is DB-specific |
| FK/unique constraint behavior | Integration test (Testcontainers) | InMemory ignores constraints |
| Global query filter behavior | EF Core InMemory or SQLite | Filters evaluated in-process |
| Migration correctness | Integration test (Testcontainers) | Need real schema creation |
| Concurrent write behavior | Testcontainers (real SQL) | Locking is database-specific |

### Pattern 1: Mock at the Repository Interface Boundary

```csharp
// ✅ Mock IOrderRepository — not DbContext
[Fact]
public async Task GetOrderDetail_ReturnsDto_WhenFound()
{
    var mockRepo = new Mock<IOrderRepository>();
    mockRepo.Setup(r => r.GetByIdAsync(1, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Order { Id = 1, CustomerId = 5, Total = 99m });

    var service = new OrderService(mockRepo.Object);
    var result = await service.GetDetailAsync(1, CancellationToken.None);

    Assert.Equal(99m, result!.Total);
}
```

This tests the service's orchestration, not the repository implementation.

### Pattern 2: Hand-Written Fake Repository

```csharp
// More robust than Moq for repository testing — captures state
public class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _store = [];
    public IReadOnlyList<Order> Stored => _store;

    public Task AddAsync(Order order, CancellationToken ct = default)
    {
        order.Id = _store.Count + 1;
        _store.Add(order);
        return Task.CompletedTask;
    }

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct = default)
        => Task.FromResult(_store.FirstOrDefault(o => o.Id == id));
}
```

### Pattern 3: EF Core InMemory for DbContext-Level Tests

```csharp
// ✅ Test global query filters, SaveChanges interceptors, owned entities
[Fact]
public async Task SoftDeleteInterceptor_SetsDeletedAt()
{
    var options = new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase($"Test_{Guid.NewGuid()}")
        .Options;

    await using var db = new AppDbContext(options);
    db.Orders.Add(new Order { Status = "Active" });
    await db.SaveChangesAsync();

    // Trigger soft-delete (via EF Core remove → interceptor sets DeletedAt)
    var order = db.Orders.First();
    db.Orders.Remove(order);
    await db.SaveChangesAsync();

    // Verify interceptor behavior — works with InMemory
    var all = await db.Orders.IgnoreQueryFilters().ToListAsync();
    Assert.NotNull(all.Single().DeletedAt);
}
```

### Pattern 4: SQLite for Query Translation Tests

```csharp
// ✅ Tests that EF Core LINQ correctly translates to SQL (SQLite dialect)
[Fact]
public async Task Pagination_SkipsAndTakesCorrectly()
{
    using var conn = new SqliteConnection("DataSource=:memory:");
    conn.Open();

    var options = new DbContextOptionsBuilder<AppDbContext>()
        .UseSqlite(conn)
        .Options;

    await using var db = new AppDbContext(options);
    await db.Database.EnsureCreatedAsync();

    for (int i = 1; i <= 15; i++)
        db.Orders.Add(new Order { CustomerId = 1, Total = i * 10m });
    await db.SaveChangesAsync();

    // Test that SKIP/TAKE generates correct SQL pagination
    var page2 = await db.Orders
        .OrderBy(o => o.Id)
        .Skip(10)
        .Take(5)
        .ToListAsync();

    Assert.Equal(5, page2.Count);
    Assert.Equal(110m, page2.First().Total); // item 11
}
```

## Code Example

```csharp
// Full test file demonstrating appropriate approach per scenario
public class OrderServiceTests
{
    // ✅ Fake repo — service orchestration
    [Fact]
    public async Task CancelOrder_UpdatesStatusAndSaves()
    {
        var repo = new FakeOrderRepository();
        var uow = new FakeUnitOfWork();
        await repo.AddAsync(new Order { Id = 1, Status = "Pending" });

        var service = new OrderService(repo, uow);
        await service.CancelAsync(1, CancellationToken.None);

        Assert.Equal("Cancelled", repo.Stored[0].Status);
        Assert.True(uow.SaveWasCalled);
    }
}

public class AuditInterceptorTests  // tests EF Core infrastructure
{
    // ✅ InMemory — global filter + interceptor
    [Fact]
    public async Task AuditInterceptor_SetsCreatedAt_OnAdd()
    {
        var db = CreateInMemoryContext();
        db.Orders.Add(new Order { CustomerId = 1, Total = 10m });
        await db.SaveChangesAsync();

        var order = await db.Orders.FirstAsync();
        Assert.True(order.CreatedAt > DateTime.UtcNow.AddMinutes(-1));
    }

    private static AppDbContext CreateInMemoryContext()
        => new(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"T_{Guid.NewGuid()}")
            .Options);
}
```

## Common Follow-up Questions

- When is it acceptable to use `Moq` on a `DbContext` vs a repository interface?
- How do you test that EF Core's `SaveChangesAsync` throws on a unique constraint violation?
- How do you mock `IDbContextFactory<T>` for services that create contexts per operation?
- What are the test coverage gaps when only unit testing with fakes — and how do you close them?
- How does the "test doubles" hierarchy (stub, spy, fake, mock) apply to EF Core testing?

## Common Mistakes / Pitfalls

- **Using `new Mock<DbContext>()` directly**: this generates a proxy that doesn't implement EF Core's internal state. Async LINQ operations will fail with `NotImplementedException` or silently return wrong results.
- **Over-testing the infrastructure**: writing unit tests that verify `db.Orders.Add(...)` is called (testing EF Core internals) provides zero value. Test the service behavior, not how it interacts with the framework.
- **Not testing the critical path with a real database**: if all tests use InMemory or fakes, production can fail on FK violations, constraint errors, or complex LINQ translation bugs that were never exercised.
- **Testing with InMemory when the business requirement depends on uniqueness**: if a feature requires unique email enforcement, an InMemory test that passes (no unique constraint) gives false confidence. Use SQLite or Testcontainers for constraint-dependent scenarios.

## References

- [Unit testing EF Core applications — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/unit-testing)
- [Testing with InMemory vs SQLite — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
- [See: sqlite-for-testing.md](./sqlite-for-testing.md)
- [See: in-memory-provider.md](./in-memory-provider.md)
- [See: repository-testing-patterns.md](./repository-testing-patterns.md)
