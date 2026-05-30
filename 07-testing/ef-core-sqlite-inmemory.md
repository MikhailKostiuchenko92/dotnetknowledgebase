# How Do You Use SQLite In-Memory Mode for EF Core Tests?

**Category:** Testing / EF Core Testing
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `SQLite`, `in-memory`, `testing`, `constraints`

## Question
> How do you use SQLite in-memory mode for EF Core tests to get closer to real SQL behavior?

## Short Answer
Use `Microsoft.Data.Sqlite` and open a `SqliteConnection` to `"DataSource=:memory:"`, then pass it to `UseSqlite()`. You must keep the connection open for the lifetime of the test — SQLite in-memory databases are destroyed when the last connection closes. Call `EnsureCreated()` to apply the schema. SQLite enforces real SQL constraints (unique, NOT NULL) and supports transactions, making it much closer to production than the EF Core InMemory provider.

## Detailed Explanation

### Why SQLite In-Memory Over InMemory Provider?

| Feature | EF InMemory | SQLite In-Memory |
|---|---|---|
| FK constraints | ❌ | ✅ (must enable) |
| Unique constraints | ❌ | ✅ |
| Transactions | ❌ | ✅ |
| Raw SQL | ❌ | ✅ |
| Migrations | ❌ | ✅ |
| Speed | ⚡ | ⚡ (slightly slower) |
| Production-match | Low | Medium |

### Setup Pattern
```csharp
// 1. Open connection (keep it open — in-memory DB dies when connection closes)
var connection = new SqliteConnection("DataSource=:memory:");
connection.Open();

// 2. Configure DbContext to use the connection
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlite(connection)
    .Options;

// 3. Create schema
using var context = new AppDbContext(options);
context.Database.EnsureCreated(); // or MigrateAsync() for migrations
```

### Enabling FK Enforcement
SQLite does NOT enforce foreign keys by default. Enable with a pragma:
```csharp
connection.Open();
using var cmd = connection.CreateCommand();
cmd.CommandText = "PRAGMA foreign_keys = ON;";
cmd.ExecuteNonQuery();
```
Or configure via EF Core:
```csharp
.UseSqlite(connection, opts => opts.CommandTimeout(30))
// And in OnConfiguring or migrations:
context.Database.ExecuteSqlRaw("PRAGMA foreign_keys = ON;");
```

### Sharing the Connection (Important)
Each test must use the **same** connection object. Multiple `DbContext` instances can share one in-memory SQLite connection — they all see the same data:
```csharp
using var context1 = new AppDbContext(options); // write context
using var context2 = new AppDbContext(options); // read context
// Both use the same in-memory DB
```

### IAsyncLifetime Pattern (xUnit)
```csharp
public class RepositoryTests : IAsyncLifetime
{
    private SqliteConnection _connection = default!;
    private AppDbContext _context = default!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        await _connection.OpenAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection).Options;
        _context = new AppDbContext(options);
        await _context.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await _context.DisposeAsync();
        await _connection.DisposeAsync();
    }
}
```

## Code Example
```csharp
namespace EFCore.SQLite.Tests;

public class OrderRepositoryTests : IAsyncLifetime
{
    private SqliteConnection _connection = default!;
    private DbContextOptions<AppDbContext> _options = default!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        await _connection.OpenAsync();

        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        using var ctx = new AppDbContext(_options);
        await ctx.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync() => await _connection.DisposeAsync();

    [Fact]
    public async Task SaveOrder_CanBeRetrieved()
    {
        using var writeCtx = new AppDbContext(_options);
        writeCtx.Orders.Add(new Order { Id = 1, Amount = 100m });
        await writeCtx.SaveChangesAsync();

        using var readCtx = new AppDbContext(_options);
        var order = await readCtx.Orders.FindAsync(1);
        order.Should().NotBeNull();
        order!.Amount.Should().Be(100m);
    }

    [Fact]
    public async Task SaveOrder_DuplicateId_ThrowsDbUpdateException()
    {
        using var ctx = new AppDbContext(_options);
        ctx.Orders.Add(new Order { Id = 1, Amount = 50m });
        await ctx.SaveChangesAsync();

        ctx.Orders.Add(new Order { Id = 1, Amount = 99m }); // duplicate PK
        var act = async () => await ctx.SaveChangesAsync();

        await act.Should().ThrowAsync<DbUpdateException>();
    }

    [Fact]
    public async Task Transaction_RolledBack_DataNotPersisted()
    {
        using var ctx = new AppDbContext(_options);
        await using var tx = await ctx.Database.BeginTransactionAsync();
        ctx.Orders.Add(new Order { Id = 10, Amount = 500m });
        await ctx.SaveChangesAsync();
        await tx.RollbackAsync();

        using var readCtx = new AppDbContext(_options);
        var order = await readCtx.Orders.FindAsync(10);
        order.Should().BeNull();
    }
}
```

## Common Follow-up Questions
- What is the difference between EF Core InMemory provider and SQLite in-memory?
- How do you enable foreign key enforcement in SQLite?
- Can you run EF Core migrations on a SQLite in-memory database?
- How do you share a SQLite in-memory connection across multiple `DbContext` instances?
- What are the remaining differences between SQLite and SQL Server for testing purposes?
- How do you use SQLite in-memory with `WebApplicationFactory`?

## Common Mistakes / Pitfalls
- **Closing the connection between tests** — the in-memory DB is deleted; keep the connection open for the entire test lifetime.
- **Not calling `EnsureCreated`** — the schema is not created automatically; the first `SaveChanges` throws without it.
- **Forgetting `PRAGMA foreign_keys = ON`** — SQLite ignores FK constraints by default; tests pass with invalid FK references.
- **Using `new SqliteConnection` per `DbContext`** — each connection gets its own database; use the same connection object.
- **Assuming SQLite == SQL Server** — SQLite has limited column type support, no `DATETIMEOFFSET`, no `NVARCHAR(MAX)`, and different behaviour for some LINQ translations.

## References
- [Microsoft Learn — Testing with SQLite](https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database#sqlite-in-memory)
- [Microsoft.Data.Sqlite on NuGet](https://www.nuget.org/packages/Microsoft.Data.Sqlite/)
- [EF Core Testing strategies](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
