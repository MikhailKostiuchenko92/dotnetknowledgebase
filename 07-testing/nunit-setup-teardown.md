# What Are `[SetUp]` and `[TearDown]` in NUnit?

**Category:** Testing / NUnit
**Difficulty:** 🟢 Junior
**Tags:** `nunit`, `[SetUp]`, `[TearDown]`, `test-lifecycle`, `before-after`

## Question
> What are `[SetUp]` and `[TearDown]` in NUnit?

## Short Answer
`[SetUp]` marks a method that NUnit runs before *each* test in the class, and `[TearDown]` marks a method that runs after *each* test. They replace the constructor/`IDisposable` pattern used in xUnit and are NUnit's primary mechanism for per-test setup and cleanup.

## Detailed Explanation

### The NUnit Instance Model
Unlike xUnit (which creates a new test class instance per test), NUnit reuses **one class instance** for all tests in a fixture. This means:
- Instance fields retain values between tests.
- `[SetUp]` must explicitly reset or reinitialise every field that should be fresh per test.
- Without `[SetUp]`, state from one test leaks into the next.

### Execution Order Per Test
```
[OneTimeSetUp]           ← once for the fixture
  ┌─[SetUp]              ← before Test1
  │  Test1
  └─[TearDown]           ← after Test1 (even if Test1 fails)
  ┌─[SetUp]              ← before Test2
  │  Test2
  └─[TearDown]           ← after Test2
[OneTimeTearDown]        ← once for the fixture
```

> 💡 `[TearDown]` runs even if the test fails. This is important for releasing resources (DB connections, file handles) that must be freed regardless of test outcome.

### `[TearDown]` and Test Failure
If `[TearDown]` throws, the test is marked with a *TearDown error* state. The test result may be shown as an error even if the test itself passed. Keep teardown code simple and defensive.

### Setup Inheritance
NUnit supports setup/teardown in a class hierarchy:
```
BaseTests.[SetUp]() → DerivedTests.[SetUp]() → Test → DerivedTests.[TearDown]() → BaseTests.[TearDown]()
```

Base class setup runs first, derived class setup runs second — opposite order on teardown. This enables shared base fixtures with per-class specialisation.

### Async Support
Both attributes support `async Task`:
```csharp
[SetUp]
public async Task SetUpAsync()
{
    await _db.Database.EnsureCreatedAsync();
}
```

### Comparison with xUnit

| Responsibility | NUnit | xUnit |
|---|---|---|
| Per-test setup | `[SetUp]` | Constructor |
| Per-test teardown | `[TearDown]` | `IDisposable.Dispose` |
| Once-per-class setup | `[OneTimeSetUp]` | `IClassFixture<T>` |
| Once-per-class teardown | `[OneTimeTearDown]` | `IClassFixture<T>.DisposeAsync` |
| Async support | Yes | `IAsyncLifetime` |

## Code Example
```csharp
namespace Accounting.Tests;

[TestFixture]
public class InvoiceServiceTests
{
    private InvoiceService _sut = null!;
    private Mock<IInvoiceRepository> _repo = null!;

    // Runs before EVERY test — resets mocks and SUT
    [SetUp]
    public void SetUp()
    {
        _repo = new Mock<IInvoiceRepository>();
        _sut = new InvoiceService(_repo.Object);
    }

    // Runs after EVERY test — even on failure
    [TearDown]
    public void TearDown()
    {
        // Example: delete a temp file created during the test
        // _tempFile?.Delete();
    }

    [Test]
    public void Create_WithValidData_ReturnsNewInvoice()
    {
        var invoice = _sut.Create(customerId: 1, amount: 250m);
        Assert.That(invoice.Id, Is.GreaterThan(0));
    }

    [Test]
    public void Create_WithNegativeAmount_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => _sut.Create(customerId: 1, amount: -10m));
    }
}

// Async [SetUp] example
[TestFixture]
public class AsyncSetupTests
{
    private AppDbContext _db = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        _db = new AppDbContext(SqliteInMemoryOptions());
        await _db.Database.EnsureCreatedAsync();
        await SeedTestDataAsync(_db);
    }

    [TearDown]
    public async Task TearDownAsync()
    {
        await _db.Database.EnsureDeletedAsync();
        await _db.DisposeAsync();
    }

    [Test]
    public async Task GetOrders_ReturnsSeedData()
    {
        var orders = await _db.Orders.ToListAsync();
        Assert.That(orders, Is.Not.Empty);
    }

    private static DbContextOptions<AppDbContext> SqliteInMemoryOptions()
        => new DbContextOptionsBuilder<AppDbContext>()
               .UseSqlite("DataSource=:memory:")
               .Options;

    private static async Task SeedTestDataAsync(AppDbContext db)
    {
        db.Orders.Add(new Order { CustomerId = 1, Total = 100m });
        await db.SaveChangesAsync();
    }
}
```

## Common Follow-up Questions
- What is the difference between `[SetUp]` and `[OneTimeSetUp]`?
- How does NUnit's instance-reuse model differ from xUnit's per-instance model?
- What happens if `[SetUp]` throws?
- Can a derived class have its own `[SetUp]`?
- How do `[SetUp]`/`[TearDown]` interact with inheritance?
- How do you perform async setup in NUnit?

## Common Mistakes / Pitfalls
- **Not reinitialising mutable fields in `[SetUp]`** — since NUnit reuses the instance, fields carry state between tests; always fully reset in `[SetUp]`.
- **Throwing in `[TearDown]`** — marks the test as error even if it passed; wrap teardown in try/catch when necessary.
- **Heavy database queries in `[SetUp]`** — runs per test; if the suite has hundreds of tests, this dominates test time. Use `[OneTimeSetUp]` with read-only data.
- **Forgetting `[SetUp]` is synchronous by default** — `async void` setup is silently broken; always use `async Task`.
- **Hidden coupling through shared base `[SetUp]`** — complex inheritance chains make test flow hard to follow; prefer composition over inheritance in test fixtures.

## References
- [NUnit documentation — SetUp and TearDown](https://docs.nunit.org/articles/nunit/writing-tests/attributes/setup.html)
- [NUnit documentation — TearDown](https://docs.nunit.org/articles/nunit/writing-tests/attributes/teardown.html)
- [Microsoft Learn — Unit testing with NUnit in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
- [NUnit GitHub](https://github.com/nunit/nunit)
