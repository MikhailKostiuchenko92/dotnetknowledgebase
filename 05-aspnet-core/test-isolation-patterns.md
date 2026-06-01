# Test Isolation Patterns in ASP.NET Core Integration Tests

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `test-isolation`, `IAsyncLifetime`, `IClassFixture`, `test-fixtures`, `state-management`

## Question

> What are the common test isolation patterns in ASP.NET Core integration tests? Explain `IClassFixture`, `ICollectionFixture`, and how to prevent test interdependencies.

## Short Answer

Integration tests share infrastructure (database, WebApplicationFactory) through xUnit's `IClassFixture<T>` (shared across one class) and `ICollectionFixture<T>` (shared across multiple classes). Isolation means each test gets a clean, predictable state regardless of execution order. The key patterns are: unique database per test class, `Respawn` for fast resets between tests, wrapping each test in a rolled-back transaction, and using `IAsyncLifetime` for async setup/teardown.

## Detailed Explanation

### xUnit fixture scope levels

| Mechanism | Lifetime | Best for |
|---|---|---|
| No fixture | Per test | Pure unit tests |
| `IClassFixture<T>` | Per test class | Integration tests sharing one WebApplicationFactory |
| `ICollectionFixture<T>` | Per test collection | Multiple classes sharing one Testcontainer |
| `IAsyncLifetime` | Per instance | Async setup/teardown in fixture |

### `IClassFixture<T>` — shared factory, isolated state

```csharp
// Factory creates once; all tests in the class share it
public sealed class ProductTests : IClassFixture<IntegrationFactory>, IAsyncLifetime
{
    private readonly IntegrationFactory _factory;
    private readonly HttpClient _client;

    public ProductTests(IntegrationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    // Runs before EACH test method
    public async Task InitializeAsync()
    {
        await _factory.ResetDatabaseAsync(); // Clean state per test
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task CreateProduct_Succeeds() { /* ... */ }
}
```

### `ICollectionFixture<T>` — shared across classes

```csharp
// Define the collection
[CollectionDefinition("Integration")]
public class IntegrationCollection : ICollectionFixture<IntegrationFactory> { }

// Use in multiple test classes
[Collection("Integration")]
public sealed class ProductTests(IntegrationFactory factory) { /* ... */ }

[Collection("Integration")]
public sealed class OrderTests(IntegrationFactory factory) { /* ... */ }
```

> **Warning:** Tests in the same collection run sequentially (xUnit) unless you configure parallel execution. Shared factories with shared state can cause flakiness.

### Factory with database reset capability

```csharp
public sealed class IntegrationFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder().Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlServer(_db.GetConnectionString()));
        });
    }

    public async Task ResetDatabaseAsync()
    {
        // Respawn: deletes all rows in all tables (except migration history)
        await _respawner.ResetAsync(_db.GetConnectionString());
    }

    private Respawner _respawner = default!;

    public async Task InitializeAsync()
    {
        await _db.StartAsync();
        // Migrate schema
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();

        _respawner = await Respawner.CreateAsync(_db.GetConnectionString(), new RespawnerOptions
        {
            DbAdapter = DbAdapter.SqlServer,
            TablesToIgnore = ["__EFMigrationsHistory"]
        });
    }

    public new async Task DisposeAsync() => await _db.DisposeAsync();
}
```

### Transaction-based isolation (no external tool)

```csharp
// Wrap each test in a transaction that is rolled back on dispose
public abstract class TransactionalTestBase : IAsyncLifetime
{
    protected AppDbContext Db { get; private set; } = default!;
    private IDbContextTransaction _tx = default!;

    public async Task InitializeAsync()
    {
        Db = CreateDbContext(); // from shared scope
        _tx = await Db.Database.BeginTransactionAsync();
    }

    public async Task DisposeAsync() => await _tx.RollbackAsync();
}
```

### Preventing shared state bugs

```csharp
// ❌ BAD: static data shared across tests
private static int _nextId = 1;
public async Task SetupAsync()
{
    _db.Users.Add(new User { Id = _nextId++ }); // Order-dependent
}

// ✅ GOOD: use Guid or Respawn to ensure clean state
public async Task InitializeAsync()
{
    await _factory.ResetDatabaseAsync(); // Always start clean
    var userId = Guid.NewGuid().ToString(); // No collision possible
    _db.Users.Add(new User { Id = userId });
    await _db.SaveChangesAsync();
}
```

## Code Example

```csharp
// Complete IAsyncLifetime + IClassFixture pattern
public sealed class OrderIntegrationTests : IClassFixture<IntegrationFactory>, IAsyncLifetime
{
    private readonly IntegrationFactory _factory;
    private readonly HttpClient _client;

    public OrderIntegrationTests(IntegrationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _client.DefaultRequestHeaders.Add("X-Test-UserId", "user-1");
        _client.DefaultRequestHeaders.Add("X-Test-Role", "User");
    }

    public async Task InitializeAsync()
    {
        await _factory.ResetDatabaseAsync();

        // Seed data needed by this test class
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Products.Add(new Product { Id = 1, Name = "Widget", Price = 9.99m });
        await db.SaveChangesAsync();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task PlaceOrder_ReturnsCreated() { /* ... */ }

    [Fact]
    public async Task CancelOrder_ReturnsNoContent() { /* ... */ }
}
```

## Common Follow-up Questions

- How does xUnit's test parallelism interact with `IClassFixture` and `ICollectionFixture`?
- What is the `ITestOutputHelper` and how do you use it to debug integration test failures?
- How do you seed lookup/reference data that all test classes need without re-inserting it every time?
- When would you prefer transaction rollback over `Respawn` for test isolation?
- How do you ensure test ordering within a class (for integration tests with inherent order)?

## Common Mistakes / Pitfalls

- **Mutating `DefaultRequestHeaders` on a shared `HttpClient`** — headers added in one test affect subsequent tests; use `HttpRequestMessage` per request instead.
- **Not implementing `IAsyncLifetime` for async cleanup** — the xUnit `IDisposable.Dispose()` is synchronous; async disposal requires `IAsyncLifetime.DisposeAsync()`.
- **Seeding data in the constructor instead of `InitializeAsync`** — constructors cannot be async; seeding in constructors requires `.GetAwaiter().GetResult()` which can deadlock.
- **Using `ICollectionFixture` with tests that modify shared state in parallel** — xUnit 2 runs tests in a collection sequentially by default, but xUnit 3 may change this; design for isolation regardless.

## References

- [xUnit — Shared Context](https://xunit.net/docs/shared-context)
- [Respawn library](https://github.com/jbogard/Respawn)
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-8.0)
- [Andrew Lock — Integration tests with Testcontainers](https://andrewlock.net/running-tests-against-testcontainers-with-dotnet/) (verify URL)
