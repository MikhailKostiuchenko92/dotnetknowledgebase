# Testcontainers for Data Access Testing

**Category:** Data Access / Testing Data Access
**Difficulty:** 🟡 Middle
**Tags:** `Testcontainers`, `integration-testing`, `Docker`, `SQL Server`, `PostgreSQL`, `xUnit`, `WebApplicationFactory`

## Question

> What is the Testcontainers library, and how do you use it to run real database integration tests in .NET? How do you set up a shared SQL Server container per test class, and how do you handle test isolation?

## Short Answer

Testcontainers for .NET (`Testcontainers.MsSql`, `Testcontainers.PostgreSql`) spins up real Docker containers of the target database during test execution, provides the connection string to your code, and tears them down after tests complete. This gives you a real SQL Server or PostgreSQL instance with the exact same behavior as production — no SQLite dialect differences, full constraint enforcement, real transaction semantics, and T-SQL support. The trade-off: requires Docker to be running and takes 5–30 seconds to start a container. Use a shared container per test class (via `IClassFixture`) and roll back transactions or use Respawn for test isolation.

## Detailed Explanation

### Setup

```bash
# NuGet packages
dotnet add package Testcontainers.MsSql
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
```

### Basic SQL Server Container

```csharp
using Testcontainers.MsSql;

public class SqlServerContainerFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("TestPass@123!")
        .Build();

    public string ConnectionString => _container.GetConnectionString();
    public DbContextOptions<AppDbContext> Options { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        Options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString)
            .Options;

        // Apply migrations to the fresh SQL Server instance
        await using var db = new AppDbContext(Options);
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
        => await _container.DisposeAsync();
}
```

### Test Class Using the Fixture

```csharp
public class OrderRepositoryIntegrationTests
    : IClassFixture<SqlServerContainerFixture>
{
    private readonly SqlServerContainerFixture _fixture;

    public OrderRepositoryIntegrationTests(SqlServerContainerFixture fixture)
        => _fixture = fixture;

    [Fact]
    public async Task CreateOrder_FailsOnForeignKeyViolation()
    {
        await using var db = new AppDbContext(_fixture.Options);

        // CustomerId = 99999 does not exist — FK violation
        db.Orders.Add(new Order { CustomerId = 99999, Total = 50m });

        // ✅ Testcontainers uses real SQL Server — FK enforcement works
        await Assert.ThrowsAsync<DbUpdateException>(
            async () => await db.SaveChangesAsync());
    }

    [Fact]
    public async Task RawSqlQuery_WorksWithSqlServerSyntax()
    {
        await using var db = new AppDbContext(_fixture.Options);
        db.Customers.Add(new Customer { Name = "Alice", Email = "alice@test.com" });
        await db.SaveChangesAsync();

        // T-SQL syntax — only works with real SQL Server
        var results = await db.Database
            .SqlQuery<CustomerSummary>($"""
                SELECT TOP 10 Id, Name, UPPER(Email) AS Email
                FROM Customers
                ORDER BY Name
                """)
            .ToListAsync();

        Assert.Single(results);
    }
}
```

### Test Isolation Options

**Option 1: Transaction rollback per test**

```csharp
[Fact]
public async Task Test_WithTransactionRollback()
{
    await using var db = new AppDbContext(_fixture.Options);
    await using var tx = await db.Database.BeginTransactionAsync();

    // Arrange + Act
    db.Orders.Add(new Order { CustomerId = 1, Total = 99m });
    await db.SaveChangesAsync();

    // Assert
    Assert.Equal(1, await db.Orders.CountAsync());

    // Rollback — database returns to clean state for next test
    await tx.RollbackAsync();
}
```

**Option 2: Respawn to clean all tables between tests** (see `respawn-for-test-isolation.md`)

**Option 3: One container per test** (slow but fully isolated):

```csharp
public class IsolatedOrderTests : IAsyncLifetime
{
    private MsSqlContainer _container = null!;

    public async Task InitializeAsync()
    {
        _container = new MsSqlBuilder().Build();
        await _container.StartAsync();
        // ... setup
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();
}
```

### WebApplicationFactory + Testcontainers (Full Integration)

```csharp
public class ApiIntegrationFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _sqlContainer = new MsSqlBuilder().Build();

    public async Task InitializeAsync()
    {
        await _sqlContainer.StartAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Replace the real connection string with the container's
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(_sqlContainer.GetConnectionString()));
        });
    }

    public new async Task DisposeAsync()
    {
        await _sqlContainer.DisposeAsync();
        await base.DisposeAsync();
    }
}

[Collection("Integration")]
public class OrdersEndpointTests(ApiIntegrationFixture fixture)
    : IClassFixture<ApiIntegrationFixture>
{
    [Fact]
    public async Task Post_CreateOrder_Returns201()
    {
        var client = fixture.CreateClient();
        var response = await client.PostAsJsonAsync("/api/orders",
            new { CustomerId = 1, Total = 99m });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }
}
```

## Code Example

```csharp
// Minimal but complete Testcontainers setup
public class DatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public AppDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(_container.GetConnectionString())
            .Options);

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();
}
```

## Common Follow-up Questions

- How does Testcontainers handle parallel test execution — does each parallel test worker get its own container?
- How do you speed up Testcontainers startup in CI pipelines (image caching, pre-pulled images)?
- How do you use Testcontainers with `dotnet test --parallel` without container conflicts?
- What is the `Ryuk` container that Testcontainers starts automatically, and how do you disable it in secure CI environments?
- When would you use Testcontainers vs a shared integration test database?

## Common Mistakes / Pitfalls

- **Starting a container per test**: a new SQL Server container takes 10–30 seconds to start. With 100 tests, that's 16–50 minutes. Use `IClassFixture` to share one container per test class.
- **Not applying migrations to the container**: the container starts with an empty database. Always call `MigrateAsync()` or `EnsureCreatedAsync()` in `InitializeAsync()` before running tests.
- **Running Docker-dependent tests in environments without Docker**: CI agents may not have Docker available. Gate Testcontainers tests with a `[Trait]` or `[Skip]` attribute for environments without Docker.
- **Cross-test data contamination without cleanup**: if tests don't roll back or clean up, data from test A affects test B's assertions. Use transaction rollback or Respawn.

## References

- [Testcontainers for .NET — dotnet.testcontainers.org](https://dotnet.testcontainers.org/)
- [Testing with real databases — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database)
- [Testcontainers.MsSql NuGet package](https://www.nuget.org/packages/Testcontainers.MsSql)
- [See: in-memory-provider.md](./in-memory-provider.md)
- [See: respawn-for-test-isolation.md](./respawn-for-test-isolation.md)
