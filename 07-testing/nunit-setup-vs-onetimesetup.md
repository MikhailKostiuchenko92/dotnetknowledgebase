# What Is the Difference Between `[SetUp]`/`[TearDown]` and `[OneTimeSetUp]`/`[OneTimeTearDown]` in NUnit?

**Category:** Testing / NUnit
**Difficulty:** 🟡 Middle
**Tags:** `nunit`, `[SetUp]`, `[TearDown]`, `[OneTimeSetUp]`, `[OneTimeTearDown]`, `test-lifecycle`

## Question
> What is the difference between `[SetUp]`/`[TearDown]` and `[OneTimeSetUp]`/`[OneTimeTearDown]` in NUnit?

## Short Answer
`[SetUp]` and `[TearDown]` run before and after **each individual test** in the fixture. `[OneTimeSetUp]` and `[OneTimeTearDown]` run **once** for the entire test fixture class — before the first test and after the last test, respectively. Use the "one-time" variants for expensive, shared resources; use the per-test variants for state that must be fresh for every test.

## Detailed Explanation

### Execution Sequence
```
[OneTimeSetUp]
  ├── [SetUp]
  │   Test1
  │   [TearDown]
  ├── [SetUp]
  │   Test2
  │   [TearDown]
  └── [SetUp]
      Test3
      [TearDown]
[OneTimeTearDown]
```

### Per-Test: `[SetUp]` and `[TearDown]`
Runs around every test. Use for:
- Reinitialising the system under test (SUT).
- Creating fresh mock objects.
- Resetting in-memory state (collections, caches).

Because NUnit reuses the test class instance, `[SetUp]` must explicitly reset all fields that should be fresh per test.

### Once-Per-Fixture: `[OneTimeSetUp]` and `[OneTimeTearDown]`
Runs once for the lifetime of the test fixture. Use for:
- Opening a database connection.
- Creating a database schema.
- Starting a server or container.
- Loading large static reference data.

> ⚠️ **Warning:** Any state created in `[OneTimeSetUp]` is shared by all tests in the class. If tests *mutate* this shared state, they interfere with each other. Use `[OneTimeSetUp]` only for **read-only** or **reset-between-tests** resources.

### Inheritance
Both types work in class hierarchies. NUnit calls them from base to derived on setup, and derived to base on teardown:

```
BaseTests.[OneTimeSetUp]
  DerivedTests.[OneTimeSetUp]
    BaseTests.[SetUp]
      DerivedTests.[SetUp]
        Test
      DerivedTests.[TearDown]
    BaseTests.[TearDown]
  DerivedTests.[OneTimeTearDown]
BaseTests.[OneTimeTearDown]
```

### Async Support
All four attributes support `async Task`:
```csharp
[OneTimeSetUp]
public async Task SetUpSchemaAsync()
    => await _db.Database.EnsureCreatedAsync();

[OneTimeTearDown]
public async Task TearDownSchemaAsync()
    => await _db.Database.EnsureDeletedAsync();
```

### xUnit Equivalents

| NUnit | xUnit equivalent |
|---|---|
| `[SetUp]` | Constructor |
| `[TearDown]` | `IDisposable.Dispose()` |
| `[OneTimeSetUp]` | `IClassFixture<T>.InitializeAsync()` |
| `[OneTimeTearDown]` | `IClassFixture<T>.DisposeAsync()` |

The key difference: xUnit enforces the per-test scope by constructing a new object per test, making `[SetUp]`-like bugs impossible. NUnit requires discipline in `[SetUp]`.

## Code Example
```csharp
namespace Reporting.Tests;

[TestFixture]
public class ReportGeneratorTests
{
    // Shared expensive resource — created once
    private static AppDbContext _sharedDb = null!;

    // Cheap, per-test resource — must be fresh each time
    private ReportGenerator _sut = null!;

    [OneTimeSetUp]
    public static async Task CreateSchemaAsync()
    {
        // Runs ONCE — create schema and seed read-only reference data
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;
        _sharedDb = new AppDbContext(options);
        await _sharedDb.Database.EnsureCreatedAsync();

        _sharedDb.ReportTypes.AddRange(
            new ReportType { Code = "MONTHLY" },
            new ReportType { Code = "QUARTERLY" });
        await _sharedDb.SaveChangesAsync();
    }

    [SetUp]
    public void SetUp()
    {
        // Runs before EACH test — fresh SUT with shared read-only DB
        _sut = new ReportGenerator(_sharedDb);
    }

    [Test]
    public async Task Generate_MonthlyReport_IncludesCorrectHeader()
    {
        var report = await _sut.GenerateAsync("MONTHLY", year: 2025, month: 1);
        Assert.That(report.Header, Does.Contain("January 2025"));
    }

    [Test]
    public async Task Generate_QuarterlyReport_IncludesQuarterLabel()
    {
        var report = await _sut.GenerateAsync("QUARTERLY", year: 2025, quarter: 1);
        Assert.That(report.Header, Does.Contain("Q1 2025"));
    }

    [OneTimeTearDown]
    public static async Task DestroySchemaAsync()
    {
        // Runs ONCE — clean up the shared resource
        await _sharedDb.Database.EnsureDeletedAsync();
        await _sharedDb.DisposeAsync();
    }
}
```

## Common Follow-up Questions
- What happens if `[OneTimeSetUp]` throws — do the tests still run?
- Can you have both `[SetUp]` and `[OneTimeSetUp]` in the same class?
- How does NUnit handle `[OneTimeSetUp]` in a parallel test run?
- How do you write async `[OneTimeSetUp]`?
- What is the xUnit equivalent of `[OneTimeSetUp]`?
- Can you call `[OneTimeSetUp]` methods from a base class?

## Common Mistakes / Pitfalls
- **Mutating `[OneTimeSetUp]` state in tests** — shared state causes order-dependent failures; treat it as read-only.
- **Using `[OneTimeSetUp]` for mocks** — mock objects with per-test `Setup()` calls can't be shared; create mocks in `[SetUp]`.
- **Static field for shared state** — `[OneTimeSetUp]` can target instance methods, but if the NUnit runner creates multiple instances, static state is safer; be explicit.
- **Throwing in `[OneTimeTearDown]`** — may mask earlier test failures; keep teardown safe and log errors rather than rethrowing.
- **Not resetting per-test fields in `[SetUp]`** — the most common NUnit isolation bug; if `[SetUp]` doesn't reinitialise a field, the value from the previous test persists.

## References
- [NUnit documentation — OneTimeSetUp](https://docs.nunit.org/articles/nunit/writing-tests/attributes/onetimesetup.html)
- [NUnit documentation — SetUp](https://docs.nunit.org/articles/nunit/writing-tests/attributes/setup.html)
- [NUnit documentation — Test lifecycle](https://docs.nunit.org/articles/nunit/writing-tests/setup-teardown/index.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
