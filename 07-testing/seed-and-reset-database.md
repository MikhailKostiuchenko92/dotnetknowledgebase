# How Do You Seed a Test Database and Reset State Between Integration Test Runs?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🔴 Senior
**Tags:** `Respawn`, `EF Core`, `test-database`, `seeding`, `integration-testing`, `reset`

## Question
> How do you seed a test database and reset state between integration test runs?

## Short Answer
Seed test data in `IAsyncLifetime.InitializeAsync` (per-test) or the factory's `InitializeAsync` (shared). Reset state between tests using one of: **Respawn** (clears tables efficiently), **transaction rollback** (wraps each test in a rolled-back transaction), or **re-creating the DB** (slow but simple). Respawn is the most popular choice for SQL databases; transaction rollback is the fastest when EF Core supports it.

## Detailed Explanation

### Option 1: Respawn (Recommended for Real SQL DBs)
**Respawn** deletes all rows in all tables in the correct FK order, faster than `DROP/CREATE`.
```csharp
private Respawner _respawner = default!;

public async Task InitializeAsync()
{
    await _connection.OpenAsync();
    _respawner = await Respawner.CreateAsync(_connection, new RespawnerOptions
    {
        DbAdapter = DbAdapter.SqlServer, // or Postgres
        TablesToIgnore = ["__EFMigrationsHistory"]
    });
}

// Reset before each test
public async Task ResetDatabaseAsync()
    => await _respawner.ResetAsync(_connection);
```

Call `ResetDatabaseAsync()` in test class constructors via `IAsyncLifetime`.

### Option 2: Transaction Rollback (Fastest)
Wrap each test in a transaction, then roll it back:
```csharp
public class OrderTests : IAsyncLifetime
{
    private IDbContextTransaction? _transaction;

    public async Task InitializeAsync()
    {
        _transaction = await _db.Database.BeginTransactionAsync();
    }

    public async Task DisposeAsync()
    {
        await _transaction!.RollbackAsync();
    }
}
```

> ⚠️ Only works if your production code doesn't commit transactions inside methods being tested. Also doesn't work with `WebApplicationFactory` unless you inject the same `DbContext` instance.

### Option 3: Re-Create Database (Simple but Slow)
```csharp
public async Task InitializeAsync()
{
    await _db.Database.EnsureDeletedAsync();
    await _db.Database.EnsureCreatedAsync();
    SeedData();
}
```
Fine for SQLite in-memory; expensive for real SQL Server.

### Option 4: Named SQLite In-Memory Database Per Test
Each test gets a uniquely named in-memory SQLite DB:
```csharp
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlite($"DataSource=test-{Guid.NewGuid():N};Mode=Memory;Cache=Shared")
    .Options;
```
No shared state between tests, but no FK enforcement either.

### Seeding Data
```csharp
// In test factory or IAsyncLifetime
private async Task SeedAsync()
{
    using var scope = _factory.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
    db.Products.AddRange(
        new Product { Id = 1, Name = "Widget", Price = 9.99m },
        new Product { Id = 2, Name = "Gadget", Price = 29.99m });
    await db.SaveChangesAsync();
}
```

## Code Example
```csharp
namespace Integration.Tests;

public class ApiTestFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly SqliteConnection _connection = new("DataSource=:memory:");
    private Respawner? _respawner;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts => opts.UseSqlite(_connection));
        });
    }

    public async Task InitializeAsync()
    {
        await _connection.OpenAsync();
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.EnsureCreatedAsync();

        // Seed baseline data
        db.Products.AddRange(
            new Product { Id = 1, Name = "Widget", Price = 9.99m });
        await db.SaveChangesAsync();

        // Respawn config (for SQLite, use CheckTemporalTables = false)
        _respawner = await Respawner.CreateAsync(_connection, new RespawnerOptions
        {
            TablesToIgnore = ["__EFMigrationsHistory"]
        });
    }

    public async Task ResetAsync() => await _respawner!.ResetAsync(_connection);

    public new async Task DisposeAsync()
    {
        await _connection.DisposeAsync();
        await base.DisposeAsync();
    }
}

[CollectionDefinition("DB")]
public class DbCollection : ICollectionFixture<ApiTestFactory> { }

[Collection("DB")]
public class ProductsTests : IAsyncLifetime
{
    private readonly ApiTestFactory _factory;
    private readonly HttpClient _client;

    public ProductsTests(ApiTestFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public async Task InitializeAsync() => await _factory.ResetAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task GetProducts_Returns_SeededProducts()
    {
        var response = await _client.GetAsync("/api/products");
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        products.Should().NotBeEmpty();
    }
}
```

## Common Follow-up Questions
- What is Respawn and how does it work under the hood?
- When should you use transaction rollback vs. Respawn for database reset?
- How do you use Respawn with PostgreSQL or SQLite?
- How do you seed different data sets for different test classes?
- What is the `TablesToIgnore` option in Respawn for?
- How does Testcontainers change the database reset strategy?

## Common Mistakes / Pitfalls
- **Not resetting between tests** — test order dependency; later tests see data from earlier ones.
- **Resetting in `DisposeAsync` instead of `InitializeAsync`** — if a test crashes mid-run, `Dispose` may not run; reset before the test for reliability.
- **Seeding and resetting without ordering FK constraints** — Respawn handles this automatically; manual `DELETE FROM` statements may fail FK checks.
- **Using `EnsureDeleted` + `EnsureCreated` in a shared factory** — rebuilds the entire schema per test; use Respawn for speed.
- **In-memory EF Core provider + Respawn** — Respawn requires a real SQL connection; use SQLite or a container for integration tests that need real reset.

## References
- [Respawn on GitHub](https://github.com/jbogard/Respawn)
- [NuGet — Respawn](https://www.nuget.org/packages/Respawn/)
- [Microsoft Learn — EF Core Testing](https://learn.microsoft.com/en-us/ef/core/testing/)
- [Andrew Lock — Resetting test databases with Respawn](https://andrewlock.net/making-your-db-tests-resilient-to-schema-changes-got-a-lot-easier-with-respawn-v6/)
