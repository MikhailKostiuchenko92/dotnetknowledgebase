# How Do You Test EF Core Migrations?

**Category:** Testing / EF Core Testing
**Difficulty:** 🔴 Senior
**Tags:** `EF Core`, `migrations`, `testing`, `Testcontainers`, `DbContext`

## Question
> How do you test EF Core migrations (ensure they apply cleanly)?

## Short Answer
Run `await context.Database.MigrateAsync()` against a real (or SQLite/containerised) database in a test and assert that `GetPendingMigrationsAsync()` returns an empty list. For full fidelity, use Testcontainers to run migrations against the real database engine (SQL Server, PostgreSQL) in CI. Optionally snapshot the model and assert no pending model changes exist.

## Detailed Explanation

### Why Test Migrations?
- EF Core's design-time model might be out of sync with migration files.
- A new migration column may conflict with existing data.
- A migration might contain raw SQL that fails on the target DB engine.
- CI should catch "Pending migrations" errors before they hit production.

### Test 1: All Migrations Apply Without Error
```csharp
[Fact]
public async Task Migrations_ApplyCleanly()
{
    await using var context = CreateDbContext();
    // Throws if any migration fails
    await context.Database.MigrateAsync();
    var pending = await context.Database.GetPendingMigrationsAsync();
    pending.Should().BeEmpty();
}
```

### Test 2: No Pending Model Changes
After migrations run, the model snapshot should match the current entity configuration:
```csharp
[Fact]
public async Task ModelMatchesMigrations_NoPendingChanges()
{
    await using var context = CreateDbContext();
    await context.Database.MigrateAsync();
    var hasPending = (context.Database.GetService<IMigrationsAssembly>()
        .CreateMigration(
            context.GetService<IMigrationsIdGenerator>().GenerateId(DateTime.Now),
            "CheckStaleness")
        .UpOperations.Count > 0);
    // Simplified check — use `dotnet ef migrations has-pending-model-changes` in CLI
}
```

Simpler: include a CLI check in your CI pipeline:
```shell
dotnet ef migrations has-pending-model-changes --project MyProject
```

### Test 3: Rollback (Down Migration)
```csharp
[Fact]
public async Task Migrations_CanRollBackToInitial()
{
    await using var context = CreateDbContext();
    await context.Database.MigrateAsync();
    await context.Database.ExecuteSqlRawAsync("UPDATE __EFMigrationsHistory SET ...");
    // Migrate to specific target:
    await context.GetInfrastructure().GetRequiredService<IMigrator>()
                 .MigrateAsync("0"); // "0" = revert all
}
```

### Using Testcontainers for Full Fidelity
```csharp
public class MigrationTests : IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder().Build();

    public async Task InitializeAsync() => await _db.StartAsync();
    public async Task DisposeAsync() => await _db.DisposeAsync();

    [Fact]
    public async Task AllMigrations_ApplyCleanlyToSqlServer()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(_db.GetConnectionString()).Options;
        await using var ctx = new AppDbContext(options);

        await ctx.Database.MigrateAsync();

        var pending = await ctx.Database.GetPendingMigrationsAsync();
        pending.Should().BeEmpty("because all migrations must apply cleanly");
    }
}
```

### Using SQLite for Fast Non-SQL-Server Tests
```csharp
private AppDbContext CreateSqliteContext()
{
    var conn = new SqliteConnection("DataSource=:memory:");
    conn.Open();
    var options = new DbContextOptionsBuilder<AppDbContext>()
        .UseSqlite(conn).Options;
    return new AppDbContext(options);
}

[Fact]
public async Task Migrations_ApplyCleanly_SQLite()
{
    await using var ctx = CreateSqliteContext();
    await ctx.Database.MigrateAsync();
    (await ctx.Database.GetPendingMigrationsAsync()).Should().BeEmpty();
}
```

## Code Example
```csharp
namespace Migrations.Tests;

// Fast test with SQLite — catches schema errors, not SQL Server-specific issues
public class MigrationFastTests
{
    [Fact]
    public async Task Migrations_SQLite_ApplyCleanly()
    {
        await using var conn = new SqliteConnection("DataSource=:memory:");
        await conn.OpenAsync();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(conn).Options;
        await using var ctx = new AppDbContext(options);

        var act = async () => await ctx.Database.MigrateAsync();
        await act.Should().NotThrowAsync("all migrations must apply without error");

        var pending = await ctx.Database.GetPendingMigrationsAsync();
        pending.Should().BeEmpty("no migrations should be left pending after MigrateAsync");
    }

    [Fact]
    public async Task Migrations_AllApplied_ListIsConsistent()
    {
        await using var conn = new SqliteConnection("DataSource=:memory:");
        await conn.OpenAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(conn).Options;
        await using var ctx = new AppDbContext(options);
        await ctx.Database.MigrateAsync();

        var applied = await ctx.Database.GetAppliedMigrationsAsync();
        var all = ctx.Database.GetMigrations();

        applied.Should().BeEquivalentTo(all,
            "all defined migrations should have been applied");
    }
}
```

## Common Follow-up Questions
- How do you detect if a migration is missing in CI?
- What is `GetPendingMigrationsAsync` vs. `GetMigrations`?
- How do you test that a migration handles data correctly (data migration)?
- Can EF Core migrations be tested with the InMemory provider?
- What is `IMigrator` and how do you migrate to a specific version?
- How do you prevent EF Core from automatically generating a migration when the model doesn't match?

## Common Mistakes / Pitfalls
- **Using InMemory provider for migration tests** — migrations are not supported by the InMemory provider.
- **Testing migrations only with SQLite** — some SQL Server-specific migration operations (computed columns, sequences, temporal tables) fail on SQLite.
- **Not testing rollback** — if a migration can't be rolled back, fixing a bad deployment is painful.
- **Forgetting to include migration tests in CI** — "pending migration" errors should be caught before merge.
- **Creating migration tests in the same project as the app** — migration test projects need a reference to the EF Core `DbContext` assembly; separate them to avoid circular references.

## References
- [Microsoft Learn — EF Core Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Microsoft Learn — `GetPendingMigrationsAsync`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.relationaldatabasefacadeextensions.getpendingmigrationsasync)
- [Testcontainers for .NET](https://dotnet.testcontainers.org/)
- [EF Core CLI — `has-pending-model-changes`](https://learn.microsoft.com/en-us/ef/core/cli/dotnet#dotnet-ef-migrations-has-pending-model-changes)
