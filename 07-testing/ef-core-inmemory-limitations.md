# What Are the Limitations of the EF Core In-Memory Provider?

**Category:** Testing / EF Core Testing
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `InMemoryDatabase`, `limitations`, `testing`, `constraints`

## Question
> What are the limitations of the EF Core in-memory provider (no transactions, no SQL-level constraints)?

## Short Answer
The in-memory provider stores entities as .NET objects in a `Dictionary`, not as SQL rows. It does not enforce database constraints (unique, foreign key, check), does not support transactions (they succeed trivially), does not run migrations, and cannot execute raw SQL. Tests relying solely on the in-memory provider may pass while hiding real production bugs. Use SQLite in-memory or Testcontainers when you need SQL-level fidelity.

## Detailed Explanation

### Limitation 1: No Constraint Enforcement
```csharp
// ❌ These do NOT throw with InMemory:
context.Products.Add(new Product { Id = 1, Sku = "WIDGET" });
context.Products.Add(new Product { Id = 2, Sku = "WIDGET" }); // duplicate unique key
await context.SaveChangesAsync(); // succeeds! real DB throws DbUpdateException
```

Missing enforcement covers: `[Index(IsUnique = true)]`, foreign keys, `CHECK` constraints, `NOT NULL` columns (sometimes).

### Limitation 2: Transactions Are No-Ops
```csharp
using var tx = await context.Database.BeginTransactionAsync();
// operations...
await tx.RollbackAsync(); // does nothing — state is already saved in-memory
```
Testing rollback behaviour, distributed transactions, or isolation levels requires a real DB.

### Limitation 3: No Raw SQL Support
```csharp
await context.Database.ExecuteSqlRawAsync("UPDATE Products SET Price = 0"); // throws
var results = context.Products.FromSqlRaw("SELECT * FROM Products").ToList(); // throws
```

### Limitation 4: No Migrations
```csharp
await context.Database.MigrateAsync(); // throws — migrations not supported
```
The schema is derived from the model, not from migration files.

### Limitation 5: Concurrency Token Behaviour
Optimistic concurrency (`[ConcurrencyCheck]`, `[Timestamp]`) is enforced differently than in SQL Server; some scenarios behave incorrectly.

### Limitation 6: Value Converters with Constraints
Value converters that convert an enum to a string with a `CHECK` constraint are silently ignored.

### Summary Table

| Feature | InMemory | SQLite In-Memory | SQL Server |
|---|---|---|---|
| FK constraints | ❌ | ✅ (if enabled) | ✅ |
| Unique constraints | ❌ | ✅ | ✅ |
| Transactions/rollback | ❌ | ✅ | ✅ |
| Raw SQL | ❌ | ✅ | ✅ |
| Migrations | ❌ | ✅ | ✅ |
| Startup speed | ⚡ | ⚡ | 🕐 |
| Production fidelity | Low | Medium | High |

> 💡 Microsoft officially recommends SQLite or a real DB for integration tests. The InMemory provider is best suited for unit tests that only care about EF Core query results, not constraint enforcement.

## Code Example
```csharp
namespace Limitations.Tests;

public class InMemoryLimitationDemo
{
    // ❌ Foreign key not enforced — passes with InMemory, fails with real DB
    [Fact]
    public async Task OrderCanReferenceMissingCustomer_InMemoryOnly()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(nameof(OrderCanReferenceMissingCustomer_InMemoryOnly))
            .Options;

        using var context = new AppDbContext(options);

        // Customer with Id 999 doesn't exist
        context.Orders.Add(new Order { Id = 1, CustomerId = 999, Amount = 100m });
        await context.SaveChangesAsync(); // passes! real DB: FK violation
    }

    // ✅ Switch to SQLite for constraint testing
    [Fact]
    public async Task OrderWithMissingCustomer_SQLite_ThrowsDbUpdateException()
    {
        var connection = new SqliteConnection("DataSource=:memory:");
        await connection.OpenAsync();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(connection)
            .Options;

        using var context = new AppDbContext(options);
        await context.Database.EnsureCreatedAsync();

        context.Orders.Add(new Order { Id = 1, CustomerId = 999, Amount = 100m });
        var act = async () => await context.SaveChangesAsync();

        await act.Should().ThrowAsync<DbUpdateException>();
    }
}
```

## Common Follow-up Questions
- How does SQLite in-memory mode compare to the EF Core InMemory provider?
- When should you use `UseInMemoryDatabase` vs. `UseSqlite`?
- What is the Microsoft recommendation for EF Core testing strategies?
- How do you enable FK enforcement in SQLite?
- Can EF Core migrations be tested with SQLite?
- What happens to `[ConcurrencyCheck]` with the InMemory provider?

## Common Mistakes / Pitfalls
- **Building entire test suite on InMemory and never testing against a real DB** — constraint bugs only appear in production.
- **Testing `SaveChanges` exception handling with InMemory** — it won't throw; you need SQLite or a real DB for that.
- **Enabling FK checks in InMemory** — there is no option; FK enforcement simply doesn't exist in the provider.
- **Assuming `BeginTransaction` protects data** — InMemory transactions are no-ops; don't rely on them for test isolation.
- **Combining InMemory tests with Respawn** — Respawn requires a real SQL connection; it doesn't work with InMemory.

## References
- [Microsoft Learn — EF Core InMemory provider limitations](https://learn.microsoft.com/en-us/ef/core/providers/in-memory/#limitations)
- [Microsoft Learn — Choosing a testing strategy](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
- [EF Core GitHub — InMemory provider design](https://github.com/dotnet/efcore)
