# Integration Test Database Setup

**Category:** Data Access / Testing Data Access
**Difficulty:** 🔴 Senior
**Tags:** `integration-testing`, `WebApplicationFactory`, `xUnit`, `database-fixture`, `test-isolation`, `Testcontainers`

## Question

> How do you set up a shared database fixture for integration tests using `WebApplicationFactory`? What are the strategies for test isolation — per-test database, transaction rollback, and Respawn? How do you handle migrations in an integration test setup?

## Short Answer

The recommended setup: a `DatabaseFixture` that starts a Testcontainers SQL Server container (or uses SQLite), applies EF Core migrations once, and shares the database across a test collection. Each test either rolls back a transaction after the test or uses **Respawn** to reset all tables between tests. `WebApplicationFactory<Program>` replaces the production connection string with the test container's via `ConfigureTestServices`. This gives you a near-production environment with isolated, repeatable tests without the overhead of a new container per test.

## Detailed Explanation

### Shared Database Fixture (xUnit Collection)

```csharp
// Shared across all tests in the Integration collection — container starts once
public class IntegrationTestDatabase : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        // Apply all EF Core migrations to the fresh container
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString)
            .Options;

        await using var db = new AppDbContext(options);
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();
}

// xUnit collection definition — all tests in this collection share the fixture
[CollectionDefinition("Integration")]
public class IntegrationCollection : ICollectionFixture<IntegrationTestDatabase> { }
```

### WebApplicationFactory Integration

```csharp
public class ApiFactory(IntegrationTestDatabase database)
    : WebApplicationFactory<Program>, IAsyncLifetime
{
    public HttpClient Client { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        Client = CreateClient();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Remove the real DbContext registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null) services.Remove(descriptor);

            // Register test DbContext pointing to the container
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(database.ConnectionString));
        });
    }

    public new Task DisposeAsync() => Task.CompletedTask;
}

// Test class
[Collection("Integration")]
public class OrdersApiTests(IntegrationTestDatabase database)
{
    private readonly ApiFactory _factory = new(database);

    [Fact]
    public async Task POST_Orders_Creates_Order()
    {
        var client = _factory.Client;
        var response = await client.PostAsJsonAsync("/api/orders",
            new CreateOrderRequest(CustomerId: 1, Total: 99.99m));

        response.EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }
}
```

### Test Isolation Options

**Option 1: Transaction Rollback**

```csharp
// Per-test transaction that is always rolled back
[Collection("Integration")]
public class OrderTests(IntegrationTestDatabase db) : IAsyncLifetime
{
    private AppDbContext _context = null!;
    private IDbContextTransaction _tx = null!;

    public async Task InitializeAsync()
    {
        _context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(db.ConnectionString).Options);
        _tx = await _context.Database.BeginTransactionAsync();
    }

    public async Task DisposeAsync()
    {
        await _tx.RollbackAsync();
        await _context.DisposeAsync();
    }

    [Fact]
    public async Task CreateOrder_PersistsCorrectly()
    {
        _context.Orders.Add(new Order { CustomerId = 1, Total = 50m });
        await _context.SaveChangesAsync();

        var saved = await _context.Orders.FirstAsync();
        Assert.Equal(50m, saved.Total);
        // ← Rolled back in DisposeAsync — no pollution to next test
    }
}
```

**Option 2: Respawn** (see `respawn-for-test-isolation.md`)

**Option 3: Per-test schema (slow, fully isolated)**:
```csharp
// Each test gets its own schema — expensive but completely isolated
var schema = $"test_{Guid.NewGuid():N}";
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlServer(connectionString)
    .Options;
await using var db = new AppDbContext(options);
db.Database.SetConnectionString(connectionString);
// Create schema + apply migrations — for scenarios where isolation is critical
```

### Seeding Common Reference Data

```csharp
// Seed data needed for all tests — applied once during fixture initialization
public class IntegrationTestDatabase : IAsyncLifetime
{
    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        await using var db = CreateContext();
        await db.Database.MigrateAsync();

        // Seed reference data once
        if (!await db.Countries.AnyAsync())
        {
            db.Countries.AddRange(
                new Country { Code = "US", Name = "United States" },
                new Country { Code = "GB", Name = "United Kingdom" }
            );
            await db.SaveChangesAsync();
        }
    }

    public AppDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString).Options);
}
```

## Code Example

```csharp
// Full test with WebApplicationFactory + shared container + HTTP test
[Collection("Integration")]
public class ProductsEndpointTests(IntegrationTestDatabase db) : IAsyncLifetime
{
    private ApiFactory _factory = null!;
    private HttpClient _client = null!;

    public async Task InitializeAsync()
    {
        _factory = new ApiFactory(db);
        _client = _factory.CreateClient();

        // Seed per-test data
        await using var ctx = db.CreateContext();
        ctx.Products.Add(new Product { Name = "Test Widget", Price = 9.99m });
        await ctx.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        // Clean up per-test data
        await using var ctx = db.CreateContext();
        await ctx.Products.ExecuteDeleteAsync();
        await _factory.DisposeAsync();
    }

    [Fact]
    public async Task GET_Products_ReturnsSeededProduct()
    {
        var response = await _client.GetFromJsonAsync<List<ProductDto>>("/api/products");

        Assert.NotNull(response);
        Assert.Contains(response, p => p.Name == "Test Widget");
    }
}
```

## Common Follow-up Questions

- How do you use `[CollectionDefinition]` and `[Collection]` in xUnit to share a database fixture across multiple test classes?
- How do you seed data that must exist before any test runs (reference data) vs data specific to each test?
- What is the difference between `IClassFixture` and `ICollectionFixture` in xUnit?
- How do you debug a test that passes locally but fails in CI due to Docker container timing?
- How do you implement parallelism-safe integration tests when multiple tests modify the same table?

## Common Mistakes / Pitfalls

- **Forgetting to apply migrations before tests**: the container starts empty. Without `MigrateAsync()` in `InitializeAsync()`, all tests fail with "Invalid object name 'Orders'".
- **Running integration tests in parallel without isolation**: parallel test execution against the same database without transaction rollback or Respawn causes data contamination and flaky tests.
- **Not disposing the `WebApplicationFactory`**: `WebApplicationFactory` holds a reference to the DI container and background services. Not disposing it after tests causes resource leaks and interference between test runs.
- **Seeding data in tests without cleanup**: tests that add rows without cleanup leave data for subsequent tests, causing false positives (e.g., `Assert.Single()` fails because a previous test added a row).

## References

- [Integration tests in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [WebApplicationFactory — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.mvc.testing.webapplicationfactory-1)
- [Testcontainers for .NET — dotnet.testcontainers.org](https://dotnet.testcontainers.org/)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
- [See: respawn-for-test-isolation.md](./respawn-for-test-isolation.md)
