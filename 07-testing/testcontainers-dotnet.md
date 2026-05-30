# How Do You Use Testcontainers for .NET to Run a Real PostgreSQL/SQL Server?

**Category:** Testing / EF Core Testing
**Difficulty:** 🔴 Senior
**Tags:** `Testcontainers`, `PostgreSQL`, `SQL Server`, `Docker`, `integration-testing`, `EF Core`

## Question
> How do you use Testcontainers for .NET to run a real PostgreSQL/SQL Server in integration tests?

## Short Answer
Install `Testcontainers.PostgreSql` or `Testcontainers.MsSql`. In `IAsyncLifetime.InitializeAsync`, build and start the container, retrieve the connection string, and configure your `DbContext` or `WebApplicationFactory` to use it. Use `ICollectionFixture<T>` to share one container across multiple test classes. The container is disposed automatically in `DisposeAsync`.

## Detailed Explanation

### Installation
```shell
dotnet add package Testcontainers.PostgreSql   # PostgreSQL
dotnet add package Testcontainers.MsSql         # SQL Server
```

### PostgreSQL Container
```csharp
var container = new PostgreSqlBuilder()
    .WithImage("postgres:16-alpine")
    .WithDatabase("testdb")
    .WithUsername("postgres")
    .WithPassword("P@ssw0rd!")
    .Build();

await container.StartAsync();
var connectionString = container.GetConnectionString();
```

### SQL Server Container
```csharp
var container = new MsSqlBuilder()
    .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
    .WithPassword("P@ssw0rd1!")
    .Build();

await container.StartAsync();
```

### Configuring EF Core with the Container
```csharp
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseNpgsql(connectionString) // PostgreSQL
    // or .UseSqlServer(connectionString) // SQL Server
    .Options;

using var ctx = new AppDbContext(options);
await ctx.Database.MigrateAsync(); // run real migrations!
```

### Sharing Container with `ICollectionFixture`
```csharp
public class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString).Options;
        await using var ctx = new AppDbContext(options);
        await ctx.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();
}

[CollectionDefinition("Postgres")]
public class PostgresCollection : ICollectionFixture<DatabaseFixture> { }
```

### Integrating with `WebApplicationFactory`
```csharp
public class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder().Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseNpgsql(_postgres.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();
    }

    public new async Task DisposeAsync() => await _postgres.DisposeAsync();
}
```

### CI Configuration
Testcontainers requires Docker. In GitHub Actions:
```yaml
jobs:
  test:
    runs-on: ubuntu-latest # Docker is available by default
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.0.x' }
      - run: dotnet test
```
On Windows agents: Docker Desktop must be running.

## Code Example
```csharp
namespace Testcontainers.Tests;

[CollectionDefinition("Postgres")]
public class PostgresCollection : ICollectionFixture<DatabaseFixture> { }

[Collection("Postgres")]
public class OrderRepositoryTests : IAsyncLifetime
{
    private readonly DatabaseFixture _db;
    private Respawner _respawner = default!;

    public OrderRepositoryTests(DatabaseFixture db) => _db = db;

    public async Task InitializeAsync()
    {
        await using var conn = new NpgsqlConnection(_db.ConnectionString);
        await conn.OpenAsync();
        _respawner = await Respawner.CreateAsync(conn, new RespawnerOptions
        {
            DbAdapter = DbAdapter.Postgres,
            TablesToIgnore = ["__EFMigrationsHistory"]
        });
        await _respawner.ResetAsync(conn);
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task AddOrder_UniqueConstraint_ThrowsOnDuplicate()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(_db.ConnectionString).Options;

        await using var ctx = new AppDbContext(options);
        ctx.Orders.Add(new Order { ReferenceNumber = "ORD-001", Amount = 100m });
        await ctx.SaveChangesAsync();

        ctx.Orders.Add(new Order { ReferenceNumber = "ORD-001", Amount = 200m }); // duplicate
        var act = async () => await ctx.SaveChangesAsync();

        await act.Should().ThrowAsync<DbUpdateException>()
                 .WithInnerException<PostgresException>();
    }
}
```

## Common Follow-up Questions
- What is the difference between Testcontainers and Docker Compose for integration tests?
- How do you run Testcontainers tests on Windows (Docker Desktop required)?
- How do you reuse a Testcontainers container to speed up test runs?
- How do you configure Testcontainers for SQL Server ARM (Apple Silicon)?
- What is `ResourceReaper` in Testcontainers and why does it matter?
- How do Testcontainers compare to LocalDB for SQL Server integration tests?

## Common Mistakes / Pitfalls
- **Creating a new container per test class** — startup is slow (5–30s); share via `ICollectionFixture`.
- **Not calling `MigrateAsync`** — container starts empty; schema must be created before tests.
- **Hardcoding the password without matching SQL Server policy** — SQL Server has password complexity requirements; `P@ssw0rd1!` must meet them.
- **Running on CI without Docker** — fails with connection errors; ensure the CI runner has Docker available.
- **Not disposing the container** — implement `IAsyncLifetime.DisposeAsync` to stop and remove the container.

## References
- [Testcontainers for .NET](https://dotnet.testcontainers.org/)
- [NuGet — Testcontainers.PostgreSql](https://www.nuget.org/packages/Testcontainers.PostgreSql/)
- [NuGet — Testcontainers.MsSql](https://www.nuget.org/packages/Testcontainers.MsSql/)
- [Testcontainers GitHub](https://github.com/testcontainers/testcontainers-dotnet)
