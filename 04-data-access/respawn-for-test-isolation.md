# Respawn for Test Isolation

**Category:** Data Access / Testing Data Access
**Difficulty:** 🔴 Senior
**Tags:** `Respawn`, `test-isolation`, `integration-testing`, `database-reset`, `xUnit`, `Testcontainers`

## Question

> What is the `Respawn` library, and how does it reset the database between integration tests? How does it compare to `DROP/RECREATE` and transaction rollback strategies? What are the performance and correctness trade-offs?

## Short Answer

**Respawn** (by Jimmy Bogard) is a .NET library that resets a database to a clean state between tests by generating a `DELETE` script in dependency order (respecting FK relationships) rather than dropping and recreating tables. It introspects the schema on first call, builds a topologically sorted delete plan, and executes it as a single batch. This is faster than DROP/RECREATE (avoids schema re-creation overhead) and more flexible than transaction rollback (works with tests that span multiple transactions, HTTP endpoints, and background jobs). Configure `Respawn` to skip tables with reference/seed data.

## Detailed Explanation

### Why Transaction Rollback Isn't Always Enough

Transaction rollback works for tests that use a single `DbContext` directly. It fails when:
- The test calls the **HTTP API** via `HttpClient` — the request runs in a separate DI scope with its own `DbContext` and committed transaction
- The test exercises **background jobs** or message handlers that run outside the test transaction
- The test uses **multiple `DbContext` instances** (some already committed)

Respawn handles all of these by resetting the database after each test regardless of how the data was written.

### Setup

```bash
# NuGet
dotnet add package Respawn
dotnet add package Respawn.DatabaseContainers  # optional, for MsSqlContainer interop
```

### Basic Respawn Configuration

```csharp
using Respawn;

public class IntegrationTestDatabase : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();
    private Respawner _respawner = null!;

    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        await using var db = CreateContext();
        await db.Database.MigrateAsync();

        // Seed reference/static data that should NOT be deleted between tests
        await SeedReferenceDataAsync();

        // Initialize Respawner — introspects schema once
        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        _respawner = await Respawner.CreateAsync(conn, new RespawnerOptions
        {
            TablesToIgnore =
            [
                new Table("Countries"),     // reference data — keep
                new Table("Categories"),    // reference data — keep
                new Table("__EFMigrationsHistory")  // always ignore migration history
            ],
            DbAdapter = DbAdapter.SqlServer
        });
    }

    public async Task ResetAsync()
    {
        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        await _respawner.ResetAsync(conn);
    }

    // ...
}
```

### Using Respawn in Tests

```csharp
[Collection("Integration")]
public class OrderTests(IntegrationTestDatabase db) : IAsyncLifetime
{
    private ApiFactory _factory = null!;

    public async Task InitializeAsync()
    {
        _factory = new ApiFactory(db);

        // Reset database at start of EACH test — clean state guaranteed
        await db.ResetAsync();
    }

    public async Task DisposeAsync() => await _factory.DisposeAsync();

    [Fact]
    public async Task POST_CreateOrder_Returns201()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/orders",
            new { CustomerId = 1, Total = 99m });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task GET_Orders_ReturnsAllOrders()
    {
        // Seed data for THIS test only (will be cleaned by Respawn before next test)
        await using var ctx = db.CreateContext();
        ctx.Orders.Add(new Order { CustomerId = 1, Total = 50m });
        await ctx.SaveChangesAsync();

        var client = _factory.CreateClient();
        var orders = await client.GetFromJsonAsync<List<OrderDto>>("/api/orders");

        Assert.Single(orders!);
    }
}
```

### Comparison of Reset Strategies

| Strategy | Speed | Scope | Trade-offs |
|----------|-------|-------|-----------|
| `DROP DATABASE + CREATE` | Slowest | Full | Schema re-creation for every test |
| `EnsureDeleted + EnsureCreated` | Slow | Full | Schema re-created per test |
| Transaction rollback | Fastest | Single context scope | Doesn't work for committed transactions (HTTP API) |
| Respawn | Fast | All tables in DB | Requires open connection, can't reset identity columns |
| Manual DELETE per table | Medium | Specific tables | Must manage FK order manually |

### Resetting Identity Counters (Optional)

By default, Respawn does not reset `IDENTITY` seed values — IDs keep incrementing. For most tests this is fine. If you need IDs to reset:

```csharp
// After Respawn, manually reset identity
await using var cmd = conn.CreateCommand();
cmd.CommandText = "DBCC CHECKIDENT ('Orders', RESEED, 0)";
await cmd.ExecuteNonQueryAsync();
```

Or configure Respawn to include `RESEED` in its reset:
```csharp
var options = new RespawnerOptions
{
    DbAdapter = DbAdapter.SqlServer,
    // Respawn 6.x: WithReseed option (verify in latest docs)
};
```

## Code Example

```csharp
// Production-ready Respawn + Testcontainers + xUnit setup
[CollectionDefinition("Integration")]
public class IntegrationCollection : ICollectionFixture<IntegrationTestDatabase> { }

public class IntegrationTestDatabase : IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder().Build();
    private Respawner _respawner = null!;

    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        await _db.StartAsync();
        ConnectionString = _db.GetConnectionString();

        await using var ctx = CreateContext();
        await ctx.Database.MigrateAsync();
        await SeedReferenceDataAsync(ctx);

        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        _respawner = await Respawner.CreateAsync(conn, new RespawnerOptions
        {
            TablesToIgnore = [new Table("__EFMigrationsHistory"), new Table("Countries")],
            DbAdapter = DbAdapter.SqlServer
        });
    }

    public async Task ResetDatabaseAsync()
    {
        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        await _respawner.ResetAsync(conn);
    }

    public AppDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString).Options);

    public async Task DisposeAsync() => await _db.DisposeAsync();

    private static async Task SeedReferenceDataAsync(AppDbContext ctx)
    {
        if (!await ctx.Countries.AnyAsync())
        {
            ctx.Countries.Add(new Country { Code = "US", Name = "United States" });
            await ctx.SaveChangesAsync();
        }
    }
}
```

## Common Follow-up Questions

- How does Respawn handle circular FK relationships when determining delete order?
- What happens to auto-increment / `IDENTITY` column values after Respawn resets the data?
- Can you use Respawn with PostgreSQL or MySQL — what changes in the configuration?
- How does Respawn interact with temporal tables (system-versioned tables in SQL Server)?
- What is the performance overhead of Respawn's schema introspection on the first call?

## Common Mistakes / Pitfalls

- **Not listing `__EFMigrationsHistory` in `TablesToIgnore`**: Respawn will delete the migration history rows, causing EF Core to think no migrations have been applied and re-applying them on the next `MigrateAsync()` call.
- **Not listing reference/seed data tables in `TablesToIgnore`**: Countries, Categories, and other static reference data that was seeded in `InitializeAsync` will be deleted, causing FK violations in tests.
- **Calling `ResetAsync` in `DisposeAsync` instead of `InitializeAsync`**: if you reset at the end of a test and the test throws, `DisposeAsync` may not be called, leaving dirty data for the next test. Reset at the **start** of each test (`InitializeAsync`) for guaranteed clean state.
- **Using Respawn with SQLite**: Respawn is designed for SQL Server, PostgreSQL, and MySQL. SQLite support is limited — use a fresh in-memory SQLite connection per test instead.

## References

- [Respawn GitHub — Jimmy Bogard](https://github.com/jbogard/Respawn)
- [Integration testing with Respawn — Andrew Lock blog](https://andrewlock.net/using-respawn-to-reset-databases-for-tests/) (verify URL)
- [See: integration-test-database-setup.md](./integration-test-database-setup.md)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
- [See: sqlite-for-testing.md](./sqlite-for-testing.md)
