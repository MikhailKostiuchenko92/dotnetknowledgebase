# How Does xUnit Handle Test Class Instantiation (New Instance Per Test)?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `test-isolation`, `constructor`, `IDisposable`, `instance-per-test`

## Question
> How does xUnit handle test class instantiation — does it create a new instance per test?

## Short Answer
Yes — xUnit creates a **new instance of the test class for every test method**. This is a deliberate design choice to enforce test isolation by default. Setup belongs in the constructor; teardown in `IDisposable.Dispose()` or `IAsyncLifetime.DisposeAsync()`.

## Detailed Explanation

### The Instance-Per-Test Model
For each `[Fact]` or `[Theory]` row, xUnit:
1. Constructs a new instance of the test class.
2. Runs the test method.
3. Calls `Dispose()` (if the class implements `IDisposable`).

This is architecturally different from NUnit and MSTest, which reuse the same class instance across all tests in the class (resetting state only if you use `[SetUp]`).

```
Test run with xUnit:
  new OrderTests() → Run Test1 → Dispose()
  new OrderTests() → Run Test2 → Dispose()
  new OrderTests() → Run Test3 → Dispose()

Test run with NUnit (same instance reused):
  new OrderTests()
    → [SetUp] → Run Test1 → [TearDown]
    → [SetUp] → Run Test2 → [TearDown]
    → [SetUp] → Run Test3 → [TearDown]
  [OneTimeTearDown]
```

### Why This Matters
Instance-per-test means:
- **Instance fields are always fresh** — no risk of state leaking between tests.
- **No need for `[SetUp]`/`[TearDown]` attributes** — use the constructor and `Dispose`.
- **Constructor can throw** — if setup fails, the test is marked as failed, not silently skipped.
- **Parallel-safe by default** — tests in the same class can run in parallel without sharing mutable state.

### Setting Up Resources
```csharp
public class OrderServiceTests : IDisposable
{
    private readonly Mock<IOrderRepository> _repo;
    private readonly OrderService _sut;

    // Constructor = xUnit's [SetUp] equivalent
    public OrderServiceTests()
    {
        _repo = new Mock<IOrderRepository>();
        _sut = new OrderService(_repo.Object);
    }

    // IDisposable.Dispose = xUnit's [TearDown] equivalent
    public void Dispose()
    {
        // Clean up file handles, connections, etc.
    }
}
```

### Shared (Expensive) Resources: `IClassFixture<T>`
If setup is expensive (e.g., starting a web server, creating a DB schema), creating it per test is wasteful. Use `IClassFixture<T>` to create the fixture *once* for the entire class:

```csharp
// Fixture created once; injected into each test instance
public class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient(); // reuses the existing server
}
```

The distinction:
- **Constructor parameters** → resolved by `IClassFixture<T>` or `ICollectionFixture<T>` (shared).
- **Plain `new` in constructor** → created fresh per test (isolated).

### Async Setup/Teardown
For async initialization, implement `IAsyncLifetime`:

```csharp
public class AsyncSetupTests : IAsyncLifetime
{
    public async Task InitializeAsync()
    {
        // Async setup — called after constructor
        await SomeAsyncSetup();
    }

    public async Task DisposeAsync()
    {
        // Async teardown
        await SomeAsyncCleanup();
    }
}
```

## Code Example
```csharp
namespace Ordering.Tests;

// New instance of this class is created for EACH test method
public class CartServiceTests : IDisposable
{
    private readonly CartService _sut;
    private readonly TempFile _tempLog; // resource that needs cleanup

    public CartServiceTests()
    {
        _tempLog = TempFile.Create(); // isolated per test
        _sut = new CartService(logPath: _tempLog.Path);
    }

    [Fact]
    public void AddItem_IncreasesTotalCount()
    {
        _sut.Add(new CartItem("SKU-1", 1));
        _sut.ItemCount.Should().Be(1);
    }

    [Fact]
    public void AddItem_SameItemTwice_IncrementsQuantity()
    {
        // This test starts with a FRESH CartService and FRESH TempFile
        _sut.Add(new CartItem("SKU-1", 1));
        _sut.Add(new CartItem("SKU-1", 1));
        _sut.ItemCount.Should().Be(1);  // quantity = 2, but distinct items = 1
    }

    public void Dispose() => _tempLog.Delete();
}
```

## Common Follow-up Questions
- How does `IClassFixture<T>` differ from instance-per-test setup?
- What is `IAsyncLifetime` and when do you need it instead of `IDisposable`?
- How do you share state between tests in xUnit when isolation is not needed?
- How does xUnit's instantiation model compare to NUnit's `[SetUp]`/`[TearDown]`?
- Can you run tests in a class in parallel, and how does instance-per-test help?
- What happens if the constructor of a test class throws?

## Common Mistakes / Pitfalls
- **Static fields on the test class** — shared across all instances; circumvents isolation. Never use `static` mutable state in test classes.
- **Using `[SetUp]`-style method naming** — naming a method `Setup()` without any attribute does nothing in xUnit.
- **Forgetting `IDisposable` for resource-owning tests** — file handles, `HttpClient`, or DB connections leak.
- **Expensive setup in the constructor** — if setup is slow, the test suite will be slow because the constructor runs per test. Use `IClassFixture<T>` for shared expensive resources.
- **Async constructor** — C# doesn't support `async` constructors; use `IAsyncLifetime.InitializeAsync()` for async setup.

## References
- [xUnit documentation — Shared context between tests](https://xunit.net/docs/shared-context)
- [xUnit documentation — Getting started](https://xunit.net/docs/getting-started/netcore/cmdline)
- [Andrew Lock — Why does xUnit create a new instance per test?](https://andrewlock.net/creating-a-custom-xunit-theory-test-dataattribute-to-load-data-from-json-files/) (verify URL)
- [Microsoft Learn — Unit testing with xUnit in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
