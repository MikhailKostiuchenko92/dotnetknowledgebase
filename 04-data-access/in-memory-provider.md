# EF Core InMemory Provider

**Category:** Data Access / Testing Data Access
**Difficulty:** 🟢 Junior
**Tags:** `EF Core`, `InMemory`, `testing`, `unit-testing`, `integration-testing`, `limitations`

## Question

> What is the EF Core InMemory provider, and what are its limitations? When is it acceptable to use it in tests, and what test scenarios require a real database provider?

## Short Answer

The EF Core InMemory provider (`UseInMemoryDatabase`) is an in-process, non-relational store that implements the EF Core API surface for testing purposes. It does not generate SQL, does not enforce referential integrity, does not support transactions (commits are no-ops), and does not support raw SQL queries. It is acceptable for testing application/domain logic that uses EF Core's change-tracking API (Add, Update, Delete, simple LINQ queries) but is inappropriate for testing anything that relies on real SQL semantics, constraints, transactions, or complex query translation.

## Detailed Explanation

### What InMemory Does

The InMemory provider stores entity objects in a dictionary-like in-memory structure. Calls to `SaveChangesAsync` persist changes to this in-memory store. LINQ queries are evaluated as in-memory LINQ (not translated to SQL).

```csharp
// NuGet: Microsoft.EntityFrameworkCore.InMemory
services.AddDbContext<AppDbContext>(options =>
    options.UseInMemoryDatabase("TestDatabase"));

// Or in a test
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseInMemoryDatabase(databaseName: $"Test_{Guid.NewGuid()}")
    .Options;

await using var db = new AppDbContext(options);
db.Orders.Add(new Order { CustomerId = 1, Total = 99.99m });
await db.SaveChangesAsync();

var order = await db.Orders.FirstAsync();
Assert.Equal(99.99m, order.Total);
```

### InMemory Limitations

| Feature | SQL Server | InMemory |
|---------|-----------|---------|
| SQL generation | ✅ | ❌ (no SQL) |
| Transactions | ✅ | ❌ (`BeginTransaction()` is a no-op) |
| FK constraints | ✅ | ❌ (cascade delete ignored) |
| CHECK constraints | ✅ | ❌ |
| Unique constraints | ✅ | ❌ (duplicates allowed) |
| `FromSqlRaw` / `SqlQuery<T>` | ✅ | ❌ (throws `NotSupportedException`) |
| `ExecuteSqlRawAsync` | ✅ | ❌ |
| Computed columns | ✅ | ❌ |
| JSON columns | ✅ | ❌ |
| Global query filters | ✅ | ✅ |
| Concurrency tokens | ✅ | Limited |

### What You CAN Test with InMemory

- Domain logic in services that use EF Core as a simple data store
- Command handlers that add/update/delete entities and read them back
- Global query filters (soft delete, multi-tenancy) — filters are evaluated in-memory

```csharp
// ✅ InMemory is fine — testing that PlaceOrder adds an order
[Fact]
public async Task PlaceOrder_AddsOrderToRepository()
{
    var options = new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase($"Test_{Guid.NewGuid()}")
        .Options;

    await using var db = new AppDbContext(options);
    var service = new OrderService(db);

    await service.PlaceOrderAsync(new PlaceOrderRequest(CustomerId: 1, Total: 50m));

    Assert.Single(await db.Orders.ToListAsync());
}
```

### What Requires a Real Provider (SQLite or SQL Server)

```csharp
// ❌ InMemory will NOT test this correctly:

// 1. Raw SQL queries
var result = await db.Database
    .SqlQuery<OrderSummary>($"SELECT Id, Total FROM Orders WHERE Status = 'Pending'")
    .ToListAsync(); // throws NotSupportedException on InMemory

// 2. Transaction rollback behavior
await using var tx = await db.Database.BeginTransactionAsync();
// → BeginTransaction on InMemory is a no-op; commit/rollback have no effect

// 3. FK constraint violation testing
db.Orders.Add(new Order { CustomerId = 999 }); // invalid FK
await db.SaveChangesAsync(); // InMemory: succeeds! SQL Server: FK violation exception

// 4. Unique constraint testing
db.Users.Add(new User { Email = "a@b.com" });
db.Users.Add(new User { Email = "a@b.com" });
await db.SaveChangesAsync(); // InMemory: succeeds! SQL Server: unique constraint violation
```

### Recommendation

> Use InMemory only for the simplest orchestration tests where the test does not rely on SQL semantics. For everything else, use **SQLite in-memory** (closer to SQL) or **Testcontainers** (real SQL Server).

## Code Example

```csharp
// Test that global query filters work (soft delete) — InMemory supports filters
[Fact]
public async Task SoftDelete_HidesDeletedOrders()
{
    var options = new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase($"Test_{Guid.NewGuid()}")
        .Options;

    await using var db = new AppDbContext(options);

    // Seed: one active, one soft-deleted
    db.Orders.Add(new Order { Id = 1, Status = "Active", DeletedAt = null });
    db.Orders.Add(new Order { Id = 2, Status = "Active", DeletedAt = DateTime.UtcNow });
    await db.SaveChangesAsync();

    // Global filter: HasQueryFilter(o => o.DeletedAt == null)
    var visible = await db.Orders.ToListAsync();
    Assert.Single(visible);        // ← filter applied in-memory ✅
    Assert.Equal(1, visible[0].Id);

    // IgnoreQueryFilters bypasses the filter
    var all = await db.Orders.IgnoreQueryFilters().ToListAsync();
    Assert.Equal(2, all.Count);
}
```

## Common Follow-up Questions

- What is the difference between EF Core InMemory and SQLite in-memory for testing?
- Why does EF Core's InMemory provider allow inserting duplicate unique constraint values?
- How do you reset the InMemory database between tests without recreating the context?
- When would you use `Moq<DbContext>` vs InMemory provider vs Testcontainers?
- How does the InMemory provider handle owned entities and table splitting?

## Common Mistakes / Pitfalls

- **Testing FK constraints with InMemory**: referential integrity is not enforced. A test that expects an FK violation will pass on InMemory but fail in production. Use SQLite or Testcontainers.
- **Assuming InMemory and SQL Server LINQ translation are equivalent**: `db.Orders.Where(o => EF.Functions.Like(o.Name, "%smith%"))` throws on InMemory — `EF.Functions` methods are SQL-server–specific.
- **Sharing the InMemory database name between tests**: if multiple tests use the same `databaseName`, they share state. Always use `Guid.NewGuid()` as the database name to get a fresh store per test.
- **Using InMemory for performance tests**: InMemory operations don't represent real database I/O latency. Performance benchmarks must use a real SQL provider.

## References

- [Testing with the InMemory provider — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/testing-without-the-database#in-memory-database)
- [Choosing a testing strategy — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
- [See: sqlite-for-testing.md](./sqlite-for-testing.md)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
