# SQLite for Testing EF Core Applications

**Category:** Data Access / Testing Data Access
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `SQLite`, `testing`, `integration-testing`, `in-process`, `InMemory`

## Question

> Why is SQLite a better choice than the EF Core InMemory provider for testing? How do you configure EF Core to use SQLite with an in-memory connection for integration tests? What are SQLite's limitations compared to SQL Server?

## Short Answer

SQLite is a real relational database engine that enforces foreign keys (when enabled), generates and validates SQL, and supports transactions — unlike the EF Core InMemory provider which stores objects in memory and ignores SQL semantics entirely. For most EF Core integration tests, SQLite provides an excellent balance: tests run in-process (no Docker required), the schema is created from EF Core migrations, and real SQL is executed. The main limitations: SQLite's SQL dialect differs from SQL Server (no `GETUTCDATE()`, different type mappings, no computed columns as written), so raw SQL tests that use T-SQL syntax must use Testcontainers instead.

## Detailed Explanation

### SQLite vs InMemory Provider

| Feature | EF Core InMemory | SQLite (in-memory) |
|---------|-----------------|-------------------|
| SQL generated | ❌ | ✅ |
| FK constraints | ❌ | ✅ (with `PRAGMA foreign_keys = ON`) |
| Unique constraints | ❌ | ✅ |
| Transactions | ❌ (no-op) | ✅ |
| `FromSqlRaw` / `SqlQuery<T>` | ❌ | ✅ |
| Real LINQ translation | ❌ (in-memory eval) | ✅ |
| T-SQL functions (`GETUTCDATE`, etc.) | N/A | ❌ (SQLite dialect only) |
| Docker dependency | ❌ | ❌ |
| Speed | Very fast | Fast |

### Setting Up SQLite In-Memory for Tests

```csharp
// NuGet: Microsoft.EntityFrameworkCore.Sqlite

// Keep the connection open for the lifetime of the test
// (SQLite in-memory database is destroyed when the last connection closes)
var connection = new SqliteConnection("DataSource=:memory:");
connection.Open();

var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlite(connection)
    .Options;

await using var db = new AppDbContext(options);
await db.Database.EnsureCreatedAsync();  // creates schema from EF Core model

// Run test...

// Cleanup
await connection.DisposeAsync();
```

### Shared Fixture for xUnit (Recommended)

```csharp
// Shared once per test class — avoids schema creation overhead per test
public class SqliteTestFixture : IAsyncLifetime
{
    private SqliteConnection? _connection;
    public DbContextOptions<AppDbContext> Options { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        await _connection.OpenAsync();

        Options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        await using var db = new AppDbContext(Options);
        await db.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        if (_connection is not null)
            await _connection.DisposeAsync();
    }
}

// Test class using the fixture
public class OrderRepositoryTests(SqliteTestFixture fixture)
    : IClassFixture<SqliteTestFixture>
{
    [Fact]
    public async Task AddOrder_SavesAndRetrievesCorrectly()
    {
        await using var db = new AppDbContext(fixture.Options);

        var order = new Order { CustomerId = 1, Total = 99.99m, Status = "Pending" };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        // Use a fresh context to avoid identity map cache
        await using var db2 = new AppDbContext(fixture.Options);
        var retrieved = await db2.Orders.FindAsync(order.Id);

        Assert.NotNull(retrieved);
        Assert.Equal(99.99m, retrieved.Total);
    }
}
```

### Resetting Between Tests

For test isolation without recreating the schema:

```csharp
// Option 1: Use a transaction, roll back after each test
public class OrderTests(SqliteTestFixture fixture) : IClassFixture<SqliteTestFixture>
{
    [Fact]
    public async Task Test1()
    {
        await using var db = new AppDbContext(fixture.Options);
        await using var tx = await db.Database.BeginTransactionAsync();

        // Test code...

        await tx.RollbackAsync(); // all changes undone — clean for next test
    }
}

// Option 2: Delete and re-seed data explicitly
// Option 3: Unique database per test (slower but fully isolated)
var conn = new SqliteConnection("DataSource=:memory:");
```

### SQLite Limitations to Watch For

```csharp
// ❌ T-SQL specific functions — fail on SQLite
m.Sql("ALTER TABLE Orders ADD CONSTRAINT DF_Status DEFAULT GETUTCDATE() FOR CreatedAt");

// ✅ Use EF Core's built-in defaults instead of raw SQL defaults
entity.Property(e => e.CreatedAt)
      .HasDefaultValueSql("datetime('now')");  // SQLite-compatible

// ❌ Computed columns with SQL Server syntax
entity.Property(e => e.FullName)
      .HasComputedColumnSql("[FirstName] + ' ' + [LastName]");  // SQL Server syntax
// → fails on SQLite. Use application-level computed properties instead.
```

## Code Example

```csharp
// Complete SQLite integration test setup with cleanup
public class ProductRepositoryTests : IClassFixture<SqliteTestFixture>
{
    private readonly SqliteTestFixture _fixture;
    public ProductRepositoryTests(SqliteTestFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task FindByCategory_ReturnsOnlyMatchingProducts()
    {
        await using var db = new AppDbContext(_fixture.Options);

        // Seed
        db.Products.AddRange(
            new Product { Name = "Widget A", CategoryId = 1, Price = 9.99m },
            new Product { Name = "Gadget B", CategoryId = 2, Price = 19.99m },
            new Product { Name = "Widget C", CategoryId = 1, Price = 14.99m }
        );
        await db.SaveChangesAsync();

        // Act
        var repo = new ProductRepository(db);
        var widgets = await repo.GetByCategoryAsync(categoryId: 1, CancellationToken.None);

        // Assert
        Assert.Equal(2, widgets.Count);
        Assert.All(widgets, p => Assert.Equal(1, p.CategoryId));
    }
}
```

## Common Follow-up Questions

- How do you run EF Core migrations (not `EnsureCreated`) against a SQLite in-memory database in tests?
- What is the performance difference between SQLite in-memory and Testcontainers for a suite of 500 tests?
- How do you handle SQLite's lack of `ALTER TABLE DROP COLUMN` in older versions for migration tests?
- When does SQLite's behavior diverge from SQL Server in ways that cause tests to pass but production to fail?
- Can you use a SQLite file (not in-memory) for persistent test databases — and when would you want that?

## Common Mistakes / Pitfalls

- **Closing the connection before tests finish**: SQLite in-memory databases are destroyed when the last connection closes. Keep the `SqliteConnection` open for the entire test lifetime and dispose it in `DisposeAsync`.
- **Using `EnsureCreated` with EF Core Migrations**: `EnsureCreated` creates the schema from the current model, bypassing the migration history. If you need to test migration Up/Down logic, use `MigrateAsync()` instead.
- **Testing T-SQL–specific query logic on SQLite**: queries that call `DATEPART`, `GETUTCDATE()`, `CHARINDEX`, or use T-SQL window function syntax will fail on SQLite. Test these with Testcontainers against real SQL Server.
- **Sharing a single `DbContext` across multiple tests**: EF Core's change tracker caches entities. Use a fresh `DbContext` instance per test (or per test action) to avoid stale identity map data affecting assertions.

## References

- [Testing with SQLite — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database#sqlite-in-memory)
- [Choosing a testing strategy — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
- [See: in-memory-provider.md](./in-memory-provider.md)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
