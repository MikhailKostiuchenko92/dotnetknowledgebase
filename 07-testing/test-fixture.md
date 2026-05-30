# What Is a Test Fixture and How Is It Used?

**Category:** Testing / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `test-fixture`, `shared-context`, `setup`, `teardown`, `xunit`, `nunit`

## Question
> What is a test fixture and how is it used?

## Short Answer
A test fixture is the set of fixed, known conditions established before a test runs — including objects, data, and environment state. In xUnit it is expressed through the test class constructor and `IClassFixture<T>` / `ICollectionFixture<T>`; in NUnit through `[TestFixture]` with `[SetUp]` / `[TearDown]`.

## Detailed Explanation

### What a Fixture Provides
A fixture ensures every test in a class starts with a consistent, known state. Without it, each test would need to repeat its own setup, leading to duplication and fragile tests that diverge over time.

Three flavours, ordered by scope:

| Scope | xUnit mechanism | NUnit mechanism | Lifespan |
|---|---|---|---|
| Per-test | Constructor + `IDisposable` | `[SetUp]` / `[TearDown]` | Created and destroyed for every single test |
| Per-class | `IClassFixture<T>` | `[OneTimeSetUp]` / `[OneTimeTearDown]` | Created once for all tests in the class |
| Per-collection | `ICollectionFixture<T>` | (shared via `[SetUpFixture]`) | Created once for all tests in the collection |

### xUnit Approach
xUnit creates a **new test class instance per test** (unlike NUnit/MSTest which reuse the instance). This makes per-test isolation the default. For expensive shared resources (database schemas, HTTP servers), use `IClassFixture<T>`.

```
new TestClass() → Run Test1 → dispose
new TestClass() → Run Test2 → dispose
...
```

### NUnit Approach
NUnit reuses the test class instance across all tests in `[TestFixture]`. `[SetUp]` runs before each test; `[OneTimeSetUp]` runs once per class. This means instance fields need explicit reset in `[SetUp]` if they are mutated by tests.

### When to Use Shared Fixtures
Shared fixtures are appropriate for *read-only* or *expensive-to-create* resources:
- Starting an in-memory HTTP server (`WebApplicationFactory`)
- Creating a database schema that tests only read from
- Establishing a connection to a third-party test container

> ⚠️ **Warning:** Never share *mutable* state in a fixture without per-test cleanup. Tests that mutate shared objects will interfere with each other, causing order-dependent failures.

### Async Fixtures in xUnit
xUnit supports `IAsyncLifetime` for async setup/teardown within a fixture:
```csharp
public class DbFixture : IAsyncLifetime
{
    public AppDbContext Db { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        // Async setup
        Db = await CreateDbContextAsync();
    }

    public async Task DisposeAsync() => await Db.DisposeAsync();
}
```

## Code Example
```csharp
// ── Per-test fixture (xUnit default) ─────────────────────────────────────────
namespace Catalog.Tests;

public class ProductServiceTests : IDisposable
{
    private readonly Mock<IProductRepository> _repo;
    private readonly ProductService _sut;

    // Constructor = Arrange phase shared across all tests in this class
    public ProductServiceTests()
    {
        _repo = new Mock<IProductRepository>();
        _sut = new ProductService(_repo.Object);
    }

    [Fact]
    public void GetById_WhenExists_ReturnsProduct()
    {
        _repo.Setup(r => r.FindById(1)).Returns(new Product { Id = 1, Name = "Widget" });
        _sut.GetById(1).Should().NotBeNull();
    }

    public void Dispose()
    {
        // Clean up any resources (e.g., temp files)
    }
}

// ── Shared fixture (IClassFixture) ────────────────────────────────────────────
public class DatabaseFixture : IAsyncLifetime
{
    public AppDbContext Db { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;
        Db = new AppDbContext(options);
        await Db.Database.EnsureCreatedAsync(); // run migrations once
    }

    public async Task DisposeAsync() => await Db.DisposeAsync();
}

public class OrderQueryTests : IClassFixture<DatabaseFixture>
{
    private readonly AppDbContext _db;

    public OrderQueryTests(DatabaseFixture fixture) => _db = fixture.Db;

    [Fact]
    public async Task GetOrders_ReturnsSeededData()
    {
        var orders = await _db.Orders.ToListAsync();
        orders.Should().NotBeEmpty();
    }
}
```

## Common Follow-up Questions
- What is the difference between `IClassFixture<T>` and `ICollectionFixture<T>` in xUnit?
- How do you handle database cleanup between tests when using a shared fixture?
- How does NUnit's `[OneTimeSetUp]` differ from xUnit's `IClassFixture`?
- What is `IAsyncLifetime` and when do you need it?
- How do you share a `WebApplicationFactory` across multiple test classes?
- What are the risks of sharing a mutable fixture?

## Common Mistakes / Pitfalls
- **Mutating shared fixture data** — tests modify data that other tests depend on; use per-test DB rollback or data reset.
- **Heavy logic in constructors** — long-running setup in constructors (vs. async init) blocks the test runner and hides errors poorly.
- **Forgetting `IDisposable`/`IAsyncLifetime`** on per-test resources — file handles, DB connections, or `HttpClient` instances leak.
- **Using `IClassFixture` for mutable mocks** — mock setups from one test bleed into the next; create mocks in the constructor instead.
- **Shared fixtures in NUnit without resetting mutable state** — NUnit reuses the class instance, so unguarded instance fields accumulate state.

## References
- [xUnit documentation — Shared context between tests](https://xunit.net/docs/shared-context)
- [Microsoft Learn — Unit testing in .NET with xUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [NUnit documentation — SetUp and TearDown](https://docs.nunit.org/articles/nunit/writing-tests/attributes/setup.html)
- [Andrew Lock — Shared test context in xUnit](https://andrewlock.net/creating-strongly-typed-xunit-theory-test-data-with-theorydata/) (verify URL)
