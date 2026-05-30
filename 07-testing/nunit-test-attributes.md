# What Attributes Does NUnit Use for Test Discovery?

**Category:** Testing / NUnit
**Difficulty:** 🟢 Junior
**Tags:** `nunit`, `[Test]`, `[TestFixture]`, `test-discovery`, `attributes`

## Question
> What attributes does NUnit use for test discovery (`[Test]`, `[TestFixture]`)?

## Short Answer
NUnit uses `[Test]` to mark individual test methods and `[TestFixture]` to mark a class containing tests. In modern NUnit 3+, `[TestFixture]` is optional on non-generic, non-parametrized classes — the runner discovers any public class with `[Test]` methods automatically.

## Detailed Explanation

### Core Test Discovery Attributes

| Attribute | Target | Purpose |
|---|---|---|
| `[TestFixture]` | Class | Marks a class as a test container (optional in NUnit 3+ for plain classes) |
| `[Test]` | Method | Marks a method as a single test (equivalent to xUnit's `[Fact]`) |
| `[TestCase]` | Method | Parameterised test (equivalent to xUnit's `[Theory]` + `[InlineData]`) |
| `[Theory]` | Method | Data theory with `[Datapoint]` sources (different from xUnit's `[Theory]`) |
| `[TestOf(typeof(T))]` | Class | Documents which class is being tested |

### `[TestFixture]` vs. No Attribute
In NUnit 3, if a class is `public`, not abstract, and has at least one `[Test]` method, NUnit will discover it **without** `[TestFixture]`. However:
- `[TestFixture]` is *required* for generic or parametrized test fixtures.
- It is still good practice to add it explicitly for clarity.

```csharp
// NUnit 3 — [TestFixture] optional for plain public class
public class CalculatorTests { ... }

// [TestFixture] required here — generic class
[TestFixture(typeof(int))]
[TestFixture(typeof(double))]
public class NumericTests<T> where T : struct { ... }
```

### Lifecycle Attributes

| Attribute | Equivalent in xUnit | Runs |
|---|---|---|
| `[SetUp]` | Constructor | Before **each** test |
| `[TearDown]` | `IDisposable.Dispose` | After **each** test |
| `[OneTimeSetUp]` | `IClassFixture.InitializeAsync` | Once before **all** tests in class |
| `[OneTimeTearDown]` | `IClassFixture.DisposeAsync` | Once after **all** tests in class |

### Other Useful Discovery Attributes

| Attribute | Purpose |
|---|---|
| `[Ignore("reason")]` | Skip a test or fixture with a reason |
| `[Category("Integration")]` | Categorise for filtering (`--where "cat == Integration"`) |
| `[Order(1)]` | Specify test execution order within a fixture |
| `[Parallelizable]` | Enable parallel execution |
| `[NonParallelizable]` | Force sequential execution |

### Comparison: xUnit vs NUnit vs MSTest

| Concept | xUnit | NUnit | MSTest |
|---|---|---|---|
| Container class | (none required) | `[TestFixture]` | `[TestClass]` |
| Single test | `[Fact]` | `[Test]` | `[TestMethod]` |
| Parameterised | `[Theory]` | `[TestCase]` | `[DataTestMethod]` |
| Skip | `[Fact(Skip="…")]` | `[Ignore("…")]` | `[Ignore]` |

## Code Example
```csharp
namespace Shop.Tests;

[TestFixture]
[TestOf(typeof(PriceCalculator))]
public class PriceCalculatorTests
{
    private PriceCalculator _sut = null!;

    [SetUp]
    public void SetUp()
    {
        // Runs before EACH test — creates fresh instance
        _sut = new PriceCalculator();
    }

    [TearDown]
    public void TearDown()
    {
        // Runs after EACH test — cleanup if needed
    }

    [Test]
    public void Calculate_WithZeroDiscount_ReturnsOriginalPrice()
    {
        decimal result = _sut.Calculate(100m, discount: 0);
        Assert.That(result, Is.EqualTo(100m));
    }

    [Test]
    [Ignore("Bug #456: incorrect rounding for negative discounts")]
    public void Calculate_WithNegativeDiscount_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => _sut.Calculate(100m, -5m));
    }

    [OneTimeSetUp]
    public void OneTimeSetUp()
    {
        // Runs once before all tests in this class
        TestContext.Progress.WriteLine("PriceCalculator test suite starting");
    }

    [OneTimeTearDown]
    public void OneTimeTearDown()
    {
        TestContext.Progress.WriteLine("PriceCalculator test suite complete");
    }
}
```

## Common Follow-up Questions
- When is `[TestFixture]` required vs. optional in NUnit 3?
- What is the difference between `[SetUp]` and `[OneTimeSetUp]`?
- How does NUnit's `[Category]` compare to xUnit's `[Trait]`?
- What is the `[Order]` attribute and should you rely on test order?
- How does NUnit discover tests in an assembly?
- How does NUnit's lifecycle differ from xUnit's per-instance model?

## Common Mistakes / Pitfalls
- **Relying on `[Order]` for test correctness** — test order should not affect outcomes; if it does, you have an isolation bug.
- **Using `[OneTimeSetUp]` for mutable state** — state created in `OneTimeSetUp` is shared by all tests; mutations in one test affect others.
- **Forgetting `[SetUp]` re-runs per test** — unlike xUnit which recreates the class instance, NUnit reuses the instance; `[SetUp]` must explicitly reset all mutable fields.
- **Ignoring `[TearDown]` exceptions** — if `[TearDown]` throws, the test is marked as error even if it passed; teardown must be robust.
- **Marking abstract base methods `[Test]`** — they will be discovered and run, possibly unexpectedly.

## References
- [NUnit documentation — Attributes](https://docs.nunit.org/articles/nunit/writing-tests/attributes.html)
- [NUnit documentation — TestFixture attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testfixture.html)
- [NUnit documentation — SetUp and TearDown](https://docs.nunit.org/articles/nunit/writing-tests/attributes/setup.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
