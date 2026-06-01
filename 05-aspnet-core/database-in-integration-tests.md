# Database Integration Tests in ASP.NET Core

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `Testcontainers`, `integration-testing`, `EF-Core`, `SQLite`, `database`, `test-isolation`

## Question

> How do you test database interactions in ASP.NET Core integration tests? Compare in-memory EF, SQLite, and Testcontainers, and explain how to handle test isolation.

## Short Answer

EF Core's `UseInMemoryDatabase` is fast but does not enforce constraints or run real SQL, making it unreliable for integration tests that involve migrations, FK relationships, or raw SQL. **SQLite in-process** is better: real SQL dialect, FK constraints, runs in-memory. **Testcontainers** spins up a real Docker SQL Server/Postgres instance per test run — highest fidelity for production-like behavior. Test isolation is typically achieved by resetting the database between tests using `EnsureDeleted`/`EnsureCreated`, transactions, or `Respawn`.

## Detailed Explanation

### Option 1: EF Core `UseInMemoryDatabase`

```csharp
services.AddDbContext<AppDbContext>(opts =>
    opts.UseInMemoryDatabase($"TestDb_{Guid.NewGuid()}"));
```

**Pros:** Zero setup, no Docker, very fast.  
**Cons:** No FK constraints, no unique index enforcement, no SQL translation (LINQ may behave differently), migrations not applied.

> **Use only for:** pure LINQ query logic with no SQL-specific features.

### Option 2: SQLite in-memory

```bash
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
```

```csharp
// Must keep connection alive for the duration — in-memory DB is destroyed when connection closes
var connection = new SqliteConnection("DataSource=:memory:");
connection.Open();

services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlite(connection));

// Apply schema
using var scope = provider.CreateScope();
var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
db.Database.EnsureCreated(); // or db.Database.MigrateAsync()
```

**Pros:** Real SQL, FK constraints, migrations, fast, no Docker.  
**Cons:** SQLite dialect differs from SQL Server (no schema, different datetime types, `NOLOCK` not supported).

### Option 3: Testcontainers (real DB engine)

```bash
dotnet add package Testcontainers.MsSql  # or Testcontainers.PostgreSql
```

```csharp
public sealed class DatabaseIntegrationTests
    : IClassFixture<DatabaseFixture>
{
    // ...
}

public sealed class DatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public Task InitializeAsync() => _container.StartAsync();
    public Task DisposeAsync() => _container.DisposeAsync().AsTask();
}
```

```csharp
// Factory using Testcontainers DB
public sealed class IntegrationFactory(DatabaseFixture db)
    : WebApplicationFactory<Program>, IClassFixture<DatabaseFixture>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlServer(db.ConnectionString));
        });
    }
}
```

### Test isolation strategies

| Strategy | Speed | Complexity | Suitable for |
|---|---|---|---|
| `EnsureDeleted` + `EnsureCreated` | Slow | Low | SQLite, small DBs |
| Transaction rollback per test | Fast | Medium | Unit-of-work tests |
| `Respawn` library (Scott Hanselman) | Fast | Low | SQL Server / Postgres |
| Unique DB per test class | Moderate | Low | Parallel test runs |

#### `Respawn` for fast database reset

```bash
dotnet add package Respawn
```

```csharp
// In IAsyncLifetime.InitializeAsync
var respawner = await Respawner.CreateAsync(connectionString, new RespawnerOptions
{
    DbAdapter = DbAdapter.SqlServer,
    TablesToIgnore = ["__EFMigrationsHistory"]
});

// In each test cleanup
await respawner.ResetAsync(connectionString);
```

#### Transaction rollback approach

```csharp
public sealed class TransactionalTest : IAsyncLifetime
{
    private IDbContextTransaction? _transaction;

    public async Task InitializeAsync()
    {
        _db = factory.Services.CreateScope()
            .ServiceProvider.GetRequiredService<AppDbContext>();
        _transaction = await _db.Database.BeginTransactionAsync();
    }

    public async Task DisposeAsync() => await _transaction!.RollbackAsync();
}
```

> **Warning:** Transaction rollback only works for tests that don't call `SaveChanges`/commit internally, and it doesn't reset identity columns.

## Code Example

```csharp
// Full SQLite integration test with schema reset between tests
public sealed class ProductRepositoryTests : IAsyncLifetime
{
    private readonly SqliteConnection _connection = new("DataSource=:memory:");
    private AppDbContext _db = default!;

    public async Task InitializeAsync()
    {
        await _connection.OpenAsync();
        var opts = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(opts);
        await _db.Database.EnsureCreatedAsync();
    }

    [Fact]
    public async Task AddProduct_ThenGet_ReturnsSameProduct()
    {
        _db.Products.Add(new Product { Name = "Gadget", Price = 9.99m });
        await _db.SaveChangesAsync();

        var product = await _db.Products.FirstOrDefaultAsync(p => p.Name == "Gadget");

        Assert.NotNull(product);
        Assert.Equal(9.99m, product!.Price);
    }

    public async Task DisposeAsync()
    {
        await _db.DisposeAsync();
        await _connection.DisposeAsync();
    }
}
```

## Common Follow-up Questions

- How do you run Testcontainers in a CI/CD environment where Docker is not available?
- What is the `Respawn` library and how does it compare to `EnsureDeleted` for test isolation?
- How do you apply EF Core migrations (not `EnsureCreated`) in tests to catch migration errors?
- How do you handle seeded reference data (e.g., lookup tables) that should exist in all tests?
- What is `DbContext` scope management in integration tests and why can it cause `ObjectDisposedException`?

## Common Mistakes / Pitfalls

- **Using `UseInMemoryDatabase` for tests that rely on FK constraints or unique indexes** — violations are silently ignored, causing false-positive tests.
- **Not keeping the `SqliteConnection` open** — in-memory SQLite databases are destroyed when the last connection closes; the test schema disappears mid-test.
- **Sharing a single `AppDbContext` instance across tests without resetting** — EF Core's change tracker retains entities from previous tests, causing phantom data.
- **Not including `__EFMigrationsHistory` in Respawn's `TablesToIgnore`** — Respawn deletes migration history, causing migration re-application failures.

## References

- [Testcontainers for .NET](https://dotnet.testcontainers.org)
- [Respawn library](https://github.com/jbogard/Respawn)
- [Microsoft Learn — EF Core testing overview](https://learn.microsoft.com/ef/core/testing/)
- [Microsoft Learn — Testing with SQLite](https://learn.microsoft.com/ef/core/testing/testing-with-the-database?tabs=sqlite)
