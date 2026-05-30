# What Is Respawn and How Does It Help with EF Core Integration Test Database Reset?

**Category:** Testing / EF Core Testing
**Difficulty:** 🔴 Senior
**Tags:** `Respawn`, `database-reset`, `EF Core`, `integration-testing`, `jbogard`

## Question
> What is Respawn and how does it help with EF Core integration test database reset?

## Short Answer
**Respawn** (by Jimmy Bogard) is a .NET library that efficiently resets a database between tests by deleting rows in FK-safe order — without dropping and re-creating tables. It introspects the database schema to build a deletion graph that respects foreign key constraints, then executes `DELETE` statements in the correct topological order. This is much faster than `DROP DATABASE` / `CREATE DATABASE` and cleaner than per-test transactions.

## Detailed Explanation

### Why Not Other Approaches?
| Approach | Problem |
|---|---|
| `EnsureDeleted` + `EnsureCreated` | Rebuilds schema — slow (1–5s per test) |
| Per-test transaction rollback | Doesn't work with `WebApplicationFactory` scope isolation |
| Manual `DELETE FROM` | Must manually maintain FK order |
| **Respawn** | Auto-discovers schema, fast, production-safe |

### Basic Setup
```csharp
// Install: NuGet Respawn

private Respawner _respawner = default!;
private SqlConnection _connection = default!;

// In test setup (once):
_respawner = await Respawner.CreateAsync(_connection, new RespawnerOptions
{
    DbAdapter = DbAdapter.SqlServer, // or DbAdapter.Postgres
    TablesToIgnore = new Table[] { "__EFMigrationsHistory" }
});

// Before each test:
await _respawner.ResetAsync(_connection);
```

### Supported Databases
- SQL Server (`DbAdapter.SqlServer`)
- PostgreSQL (`DbAdapter.Postgres`)
- MySQL (`DbAdapter.MySql`)
- SQLite (limited — see note below)

> ⚠️ Respawn's SQLite support is limited as SQLite lacks the system catalog tables Respawn uses to discover FK graph. For SQLite, prefer per-test database names or `EnsureDeleted` + `EnsureCreated`.

### `RespawnerOptions` Key Properties
```csharp
new RespawnerOptions
{
    DbAdapter = DbAdapter.SqlServer,
    TablesToIgnore = ["__EFMigrationsHistory", "LookupCodes"], // preserve reference data
    TablesToInclude = ["Orders", "Customers"],  // optional: only reset these
    SchemasToInclude = ["dbo"],
    WithReseed = true // resets IDENTITY columns to 0
}
```

### Integration with `WebApplicationFactory`
```csharp
public class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private SqlConnection _conn = default!;
    private Respawner _respawner = default!;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlServer(ConnectionString));
        });
    }

    public async Task InitializeAsync()
    {
        _conn = new SqlConnection(ConnectionString);
        await _conn.OpenAsync();
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();

        _respawner = await Respawner.CreateAsync(_conn, new RespawnerOptions
        {
            DbAdapter = DbAdapter.SqlServer,
            TablesToIgnore = ["__EFMigrationsHistory"]
        });
    }

    public async Task ResetDbAsync() => await _respawner.ResetAsync(_conn);

    public new async Task DisposeAsync() => await _conn.DisposeAsync();
}

// In each test class:
public class OrderTests : IAsyncLifetime
{
    private readonly ApiFactory _factory;
    public OrderTests(ApiFactory factory) => _factory = factory;

    public async Task InitializeAsync() => await _factory.ResetDbAsync();
    public Task DisposeAsync() => Task.CompletedTask;
}
```

## Code Example
```csharp
namespace Respawn.Tests;

[CollectionDefinition("SqlServer")]
public class SqlServerCollection : ICollectionFixture<ApiFactory> { }

[Collection("SqlServer")]
public class ProductApiTests : IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly ApiFactory _factory;

    public ProductApiTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public async Task InitializeAsync() => await _factory.ResetDbAsync(); // clean slate
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task CreateProduct_Returns201_AndProductCanBeRetrieved()
    {
        var body = new { Name = "Widget", Price = 9.99 };
        var createResponse = await _client.PostAsJsonAsync("/api/products", body);

        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var id = (await createResponse.Content.ReadFromJsonAsync<ProductDto>())!.Id;
        var getResponse = await _client.GetAsync($"/api/products/{id}");
        getResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task GetProducts_AfterReset_ReturnsEmptyList()
    {
        // DB was reset in InitializeAsync — no data from previous tests
        var response = await _client.GetAsync("/api/products");
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        products.Should().BeEmpty();
    }
}
```

## Common Follow-up Questions
- How does Respawn discover the database schema?
- What is `TablesToIgnore` and why would you ignore `__EFMigrationsHistory`?
- What is `WithReseed` and when should you enable it?
- Can Respawn be used with PostgreSQL or MySQL?
- How does Respawn compare to per-test transaction rollback?
- How do you use Respawn with `NpgsqlConnection` for PostgreSQL?

## Common Mistakes / Pitfalls
- **Using Respawn with the EF Core InMemory provider** — Respawn requires a real SQL connection; it doesn't work with InMemory.
- **Calling `ResetAsync` in `DisposeAsync` instead of `InitializeAsync`** — if a test crashes, `Dispose` may not run; reset before the test.
- **Not ignoring migration history table** — Respawn deletes `__EFMigrationsHistory` by default, which causes `MigrateAsync` to re-run all migrations.
- **Forgetting `WithReseed = true`** — if tests depend on specific auto-increment IDs (bad practice), identity columns may not reset to 1.
- **Creating a new `Respawner` per test** — `CreateAsync` is expensive (introspects schema); create once in `InitializeAsync` of the shared factory, not per test.

## References
- [Respawn on GitHub](https://github.com/jbogard/Respawn)
- [NuGet — Respawn](https://www.nuget.org/packages/Respawn/)
- [Jimmy Bogard — Respawn blog post](https://jimmybogard.com/better-integration-tests-for-asp-net-core/) (verify URL)
- [Andrew Lock — Respawn v6 update](https://andrewlock.net/making-your-db-tests-resilient-to-schema-changes-got-a-lot-easier-with-respawn-v6/)
