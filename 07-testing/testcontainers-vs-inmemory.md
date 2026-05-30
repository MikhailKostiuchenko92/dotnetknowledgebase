# In-Process Integration Tests vs. Testcontainers: Trade-Offs

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🔴 Senior
**Tags:** `Testcontainers`, `WebApplicationFactory`, `integration-testing`, `Docker`, `trade-offs`

## Question
> What are the trade-offs of in-process integration tests vs. spinning up a real container (Testcontainers)?

## Short Answer
In-process tests with `WebApplicationFactory` + in-memory/SQLite databases are fast but can hide real-database bugs (missing constraints, SQL-specific behaviour). Testcontainers spin up real Docker containers (PostgreSQL, SQL Server, Redis) giving full production-fidelity at the cost of slower startup and a Docker daemon dependency. Use in-memory/SQLite for rapid unit-level integration tests and Testcontainers for critical data-access and migration tests.

## Detailed Explanation

### In-Process Integration Tests
```
WebApplicationFactory<Program>
  ├── TestServer (in-memory HTTP)
  ├── EF Core InMemory DB / SQLite
  └── Mocked/faked external services
```

| Pros | Cons |
|---|---|
| Fast (seconds) | InMemory DB has no constraints, no SQL |
| No Docker required | SQLite is not your production DB |
| Simple CI setup | May hide DB-specific bugs |
| Perfect for API surface testing | Migrations not tested |

### Testcontainers
```csharp
// Testcontainers.MsSql or Testcontainers.PostgreSql
var container = new MsSqlBuilder()
    .WithPassword("P@ssw0rd!")
    .Build();

await container.StartAsync();
var connectionString = container.GetConnectionString();
```

| Pros | Cons |
|---|---|
| Real DB engine (real SQL, real constraints) | Slow startup (5–30s per container) |
| Tests migrations and FK constraints | Requires Docker daemon |
| Same engine as production | CI needs Docker-in-Docker or DIND |
| Tests indexes, stored procs, views | Higher resource usage |

### Decision Guide

| Concern | In-Process + SQLite | Testcontainers |
|---|---|---|
| API routing and response shape | ✅ | Overkill |
| DB constraint enforcement | ❌ | ✅ |
| EF Core migrations | ❌ | ✅ |
| Stored procedures / views | ❌ | ✅ |
| CI speed | ⚡ Fast | 🕐 Slow |
| Docker available in CI | N/A | Required |

### Recommended Layering
```
Unit tests           → Mock all infrastructure → fast, many
In-process tests     → SQLite/InMemory DB     → API surface, routing
Testcontainer tests  → Real DB container      → critical data access, migrations
```

### Testcontainers .NET Example
```csharp
public class PostgresTestFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        using var conn = new NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        // Run migrations
    }

    public async Task DisposeAsync()
        => await _container.DisposeAsync();
}
```

## Code Example
```csharp
namespace Integration.Tests;

// ── In-process (fast, SQLite) ──────────────────────────────
public class OrdersApi_InMemoryTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public OrdersApi_InMemoryTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(b =>
            b.ConfigureTestServices(s =>
            {
                s.RemoveDbContext<AppDbContext>();
                s.AddDbContext<AppDbContext>(o => o.UseSqlite("DataSource=:memory:"));
            })).CreateClient();
    }

    [Fact]
    public async Task GetOrders_Returns200() =>
        (await _client.GetAsync("/api/orders")).StatusCode.Should().Be(HttpStatusCode.OK);
}

// ── Testcontainers (real Postgres) ─────────────────────────
public class OrderRepository_PostgresTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    private AppDbContext _db = default!;

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(_postgres.GetConnectionString())
            .Options;
        _db = new AppDbContext(options);
        await _db.Database.MigrateAsync(); // real migrations!
    }

    [Fact]
    public async Task UniqueConstraint_DuplicateEmail_ThrowsDbUpdateException()
    {
        _db.Users.Add(new User { Email = "a@b.com" });
        await _db.SaveChangesAsync();

        _db.Users.Add(new User { Email = "a@b.com" }); // duplicate
        var act = async () => await _db.SaveChangesAsync();

        await act.Should().ThrowAsync<DbUpdateException>()
                 .WithInnerException<PostgresException>();
    }

    public async Task DisposeAsync()
    {
        await _db.DisposeAsync();
        await _postgres.DisposeAsync();
    }
}
```

## Common Follow-up Questions
- What is Testcontainers for .NET and which databases does it support?
- How do you run Testcontainers in GitHub Actions or Azure DevOps?
- How do you reuse a Testcontainers container across multiple test classes?
- What is Docker-in-Docker (DIND) and why does it matter for CI?
- How do you configure Testcontainers to run migrations before tests?
- When is it worth accepting the Testcontainers startup cost vs. using SQLite?

## Common Mistakes / Pitfalls
- **Only using InMemory EF Core and missing constraint violations** — the InMemory provider ignores FK constraints, uniqueness, and check constraints.
- **Assuming SQLite = your production DB** — SQLite has different collation, type affinity, and no `schema` support; behaviour can diverge.
- **Not reusing Testcontainers across tests** — starting a new container per test class is very slow; share via `ICollectionFixture`.
- **Forgetting to wait for container readiness** — `StartAsync()` returns when the container starts, not when the DB is ready; Testcontainers handles wait strategies automatically.
- **Running Testcontainers tests in `dotnet test` without Docker** — tests fail with obscure connection errors; ensure Docker is running in CI.

## References
- [Testcontainers for .NET](https://dotnet.testcontainers.org/)
- [NuGet — Testcontainers](https://www.nuget.org/packages/Testcontainers/)
- [NuGet — Testcontainers.MsSql](https://www.nuget.org/packages/Testcontainers.MsSql/)
- [NuGet — Testcontainers.PostgreSql](https://www.nuget.org/packages/Testcontainers.PostgreSql/)
- [Andrew Lock — Integration tests with Testcontainers](https://andrewlock.net/dotnet-testing-resources/) (verify URL)
