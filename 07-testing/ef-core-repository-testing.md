# How Do You Test a Repository Class That Depends on `DbContext`?

**Category:** Testing / EF Core Testing
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `DbContext`, `repository`, `testing`, `SQLite`

## Question
> How do you test a repository class that depends on `DbContext`?

## Short Answer
Create a real `DbContext` backed by a SQLite in-memory (or InMemory) database and inject it into the repository under test. Avoid mocking `DbContext` — it's a concrete class with many non-virtual members and complex internal state. Write your tests with a fresh context per test (or per transaction) to ensure isolation.

## Detailed Explanation

### Why Not Mock `DbContext`?
`DbContext` has a complex internal model — change tracking, lazy loading proxies, navigation property fixup — that is nearly impossible to mock accurately. Mocking it produces brittle tests that don't reflect real behaviour.

### Recommended Approach: Real DbContext + SQLite
```csharp
// Setup: SQLite in-memory with schema
var connection = new SqliteConnection("DataSource=:memory:");
connection.Open();
var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options;
using var ctx = new AppDbContext(options);
ctx.Database.EnsureCreated();

// Inject real context into repository
var repo = new ProductRepository(ctx);
```

### Write Context vs. Read Context Pattern
Use separate contexts for write and read to test that data is actually persisted:
```csharp
// Write
using var writeCtx = new AppDbContext(options);
var writeRepo = new ProductRepository(writeCtx);
await writeRepo.AddAsync(new Product { Id = 1, Name = "Widget" });
await writeCtx.SaveChangesAsync();

// Read (fresh context — no cache)
using var readCtx = new AppDbContext(options);
var readRepo = new ProductRepository(readCtx);
var product = await readRepo.GetByIdAsync(1);
product.Should().NotBeNull();
```
Using a fresh `readCtx` avoids the EF Core identity cache returning the in-memory tracked instance instead of the saved one.

### Using Transactions for Isolation
```csharp
using var tx = await ctx.Database.BeginTransactionAsync();
// test operations
await tx.RollbackAsync(); // leave no trace for next test
```

### What to Test
- `Add` → persists entity and assigns generated ID
- `GetById` → returns null for missing, entity for existing
- `GetAll` / filtered queries → correct LINQ results
- `Update` → changes are persisted
- `Delete` → entity is removed
- Constraint violations → correct exception type

## Code Example
```csharp
namespace Repository.Tests;

public class ProductRepositoryTests : IAsyncLifetime
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
        await using var ctx = new AppDbContext(_options);
        await ctx.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync() => await _connection.DisposeAsync();

    [Fact]
    public async Task AddAsync_PersistsProduct_CanBeFound()
    {
        // Arrange + Act
        await using (var ctx = new AppDbContext(_options))
        {
            var repo = new ProductRepository(ctx);
            await repo.AddAsync(new Product { Id = 1, Name = "Widget", Price = 9.99m });
        }

        // Assert — fresh context, no cache
        await using (var ctx = new AppDbContext(_options))
        {
            var repo = new ProductRepository(ctx);
            var product = await repo.GetByIdAsync(1);
            product.Should().NotBeNull();
            product!.Name.Should().Be("Widget");
        }
    }

    [Fact]
    public async Task GetActive_ReturnsOnlyActiveProducts()
    {
        await using (var ctx = new AppDbContext(_options))
        {
            ctx.Products.AddRange(
                new Product { Id = 1, Name = "Active", IsActive = true },
                new Product { Id = 2, Name = "Inactive", IsActive = false });
            await ctx.SaveChangesAsync();
        }

        await using (var ctx = new AppDbContext(_options))
        {
            var repo = new ProductRepository(ctx);
            var results = await repo.GetActiveAsync();
            results.Should().ContainSingle(p => p.Id == 1);
        }
    }

    [Fact]
    public async Task DeleteAsync_ExistingProduct_IsRemoved()
    {
        await using (var writeCtx = new AppDbContext(_options))
        {
            writeCtx.Products.Add(new Product { Id = 5, Name = "ToDelete" });
            await writeCtx.SaveChangesAsync();
        }

        await using (var deleteCtx = new AppDbContext(_options))
        {
            var repo = new ProductRepository(deleteCtx);
            await repo.DeleteAsync(5);
        }

        await using (var readCtx = new AppDbContext(_options))
        {
            var product = await readCtx.Products.FindAsync(5);
            product.Should().BeNull();
        }
    }
}
```

## Common Follow-up Questions
- Why should you avoid mocking `DbContext` directly?
- What is the difference between InMemory and SQLite in-memory for repository tests?
- Why do you need a fresh `DbContext` for the read assertion?
- How do you handle `EnsureCreated` vs. `Migrate` in repository tests?
- Should repository tests be unit tests or integration tests?
- How do you test repositories with complex LINQ queries that behave differently in-memory?

## Common Mistakes / Pitfalls
- **Reading from the same context that wrote** — the identity cache returns the tracked instance; you don't know if the data was actually saved. Use a fresh context for reads.
- **Not calling `SaveChangesAsync`** — forgetting to save means nothing is persisted; repositories typically do not call `SaveChanges` themselves.
- **Using InMemory provider for constraint tests** — silently passes; use SQLite for constraint enforcement.
- **Not disposing the connection** — SQLite in-memory DB lives as long as the connection; dispose it properly in `DisposeAsync`.
- **Testing the ORM instead of your repository** — don't test that EF Core saves data (that's EF Core's responsibility); test your custom query logic and repository-specific behaviour.

## References
- [Microsoft Learn — Testing with a database](https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database)
- [Microsoft Learn — Repository pattern](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [EF Core Testing strategies](https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy)
