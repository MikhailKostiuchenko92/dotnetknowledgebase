# What Attributes Does MSTest Use?

**Category:** Testing / MSTest
**Difficulty:** 🟢 Junior
**Tags:** `mstest`, `[TestClass]`, `[TestMethod]`, `[DataRow]`, `test-discovery`, `attributes`

## Question
> What attributes does MSTest use (`[TestClass]`, `[TestMethod]`, `[DataRow]`)?

## Short Answer
MSTest requires `[TestClass]` on a class and `[TestMethod]` on each test method for discovery. For parameterised tests, combine `[DataTestMethod]` with one or more `[DataRow]` attributes. MSTest also provides `[TestInitialize]`, `[TestCleanup]`, `[ClassInitialize]`, and `[ClassCleanup]` for lifecycle hooks.

## Detailed Explanation

### Core Test Discovery Attributes

| Attribute | Target | Purpose |
|---|---|---|
| `[TestClass]` | Class | Marks a class for test discovery (required) |
| `[TestMethod]` | Method | Single test (equivalent to xUnit `[Fact]`, NUnit `[Test]`) |
| `[DataTestMethod]` | Method | Parameterised test (equivalent to xUnit `[Theory]`) |
| `[DataRow]` | Method | One row of data for `[DataTestMethod]` |
| `[DynamicData]` | Method | Source data from a property or method |
| `[TestCategory]` | Method/Class | Grouping and filtering |
| `[Ignore]` | Method/Class | Skip the test with optional reason |

### Lifecycle Attributes

| Attribute | Runs | xUnit equivalent |
|---|---|---|
| `[TestInitialize]` | Before **each** test | Constructor |
| `[TestCleanup]` | After **each** test | `IDisposable.Dispose` |
| `[ClassInitialize]` | Once before **all** tests in class | `IClassFixture.InitializeAsync` |
| `[ClassCleanup]` | Once after **all** tests in class | `IClassFixture.DisposeAsync` |
| `[AssemblyInitialize]` | Once for entire test assembly | (no direct equivalent) |
| `[AssemblyCleanup]` | Once after all assemblies | (no direct equivalent) |

> ⚠️ `[ClassInitialize]` must be applied to a `static` method with a `TestContext` parameter: `public static void InitClass(TestContext ctx)`.

### `TestContext`
MSTest injects a `TestContext` object that provides:
- `TestContext.TestName` — name of the currently running test
- `TestContext.CurrentTestOutcome` — result in `[TestCleanup]`
- `TestContext.WriteLine(...)` — per-test output (like xUnit's `ITestOutputHelper`)

### Comparison: MSTest vs xUnit vs NUnit

| Concept | MSTest | xUnit | NUnit |
|---|---|---|---|
| Test class | `[TestClass]` | (none needed) | `[TestFixture]` |
| Single test | `[TestMethod]` | `[Fact]` | `[Test]` |
| Parameterised | `[DataTestMethod]`+`[DataRow]` | `[Theory]`+`[InlineData]` | `[TestCase]` |
| Per-test setup | `[TestInitialize]` | Constructor | `[SetUp]` |
| Per-test teardown | `[TestCleanup]` | `IDisposable` | `[TearDown]` |
| Category | `[TestCategory]` | `[Trait]` | `[Category]` |

## Code Example
```csharp
namespace Finance.Tests;

[TestClass]
public class TaxCalculatorTests
{
    private TaxCalculator _sut = null!;

    // Runs before each test
    [TestInitialize]
    public void Initialize()
    {
        _sut = new TaxCalculator(vatRate: 0.21m);
    }

    // Runs after each test
    [TestCleanup]
    public void Cleanup()
    {
        // Release resources if needed
    }

    // Single test
    [TestMethod]
    public void Calculate_WithZeroAmount_ReturnsZeroTax()
    {
        var result = _sut.Calculate(amount: 0m);
        Assert.AreEqual(0m, result);
    }

    // Parameterised test — DataRow maps positionally to method parameters
    [DataTestMethod]
    [DataRow(100.0, 21.0)]
    [DataRow(200.0, 42.0)]
    [DataRow(0.0,    0.0)]
    public void Calculate_ReturnsExpectedTax(double amount, double expectedTax)
    {
        var result = _sut.Calculate((decimal)amount);
        Assert.AreEqual((decimal)expectedTax, result);
    }

    // Skip a test
    [TestMethod]
    [Ignore("Bug #123 — rounding issue with negative amounts")]
    public void Calculate_NegativeAmount_ThrowsArgumentException()
    {
        Assert.ThrowsException<ArgumentException>(() => _sut.Calculate(-10m));
    }

    // Class-level one-time setup (must be static + TestContext param)
    [ClassInitialize]
    public static void ClassSetUp(TestContext ctx)
    {
        ctx.WriteLine("TaxCalculatorTests suite starting");
    }

    [ClassCleanup]
    public static void ClassTearDown()
    {
        // one-time cleanup
    }
}
```

## Common Follow-up Questions
- How do `[TestInitialize]` and `[ClassInitialize]` differ from each other?
- How do you use `[DynamicData]` for complex parameterised data in MSTest?
- What is `TestContext` and how do you use it for test output?
- What are the key differences between MSTest v1 and MSTest v2?
- How does MSTest handle parallel test execution?
- When would you choose MSTest over xUnit for a new project?

## Common Mistakes / Pitfalls
- **Forgetting `[TestClass]`** — class is silently ignored; tests never run.
- **`[DataTestMethod]` without `[DataRow]`** — generates one failing test that reports "no data was provided".
- **`[ClassInitialize]` on an instance method** — requires `static`; a non-static method causes a runtime exception.
- **Using `Assert.AreEqual(expected, actual)` with wrong parameter order** — produces misleading failure messages; always put expected first.
- **Async void test methods** — same as xUnit: silently swallows exceptions; use `async Task`.

## References
- [Microsoft Learn — MSTest framework](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-mstest)
- [MSTest GitHub — Test attributes](https://github.com/microsoft/testfx/blob/main/docs/overview.md)
- [Microsoft Learn — DataTestMethod and DataRow](https://learn.microsoft.com/en-us/visualstudio/test/how-to-create-a-data-driven-unit-test)
- [Microsoft Learn — TestContext class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.testcontext)
