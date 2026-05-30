# What Attributes Does xUnit Use to Mark Test Methods?

**Category:** Testing / xUnit
**Difficulty:** 🟢 Junior
**Tags:** `xunit`, `[Fact]`, `[Theory]`, `test-discovery`, `attributes`

## Question
> What attributes does xUnit use to mark test methods (`[Fact]`, `[Theory]`)?

## Short Answer
xUnit uses `[Fact]` to mark a test that always runs the same way with no parameters, and `[Theory]` to mark a parameterised test that runs once per set of data provided via `[InlineData]`, `[MemberData]`, or `[ClassData]`. Both attributes trigger test discovery by the xUnit runner.

## Detailed Explanation

### `[Fact]`
`[Fact]` denotes a single, unconditional test. It takes no data and produces a single test result. This is the most common xUnit attribute.

```csharp
[Fact]
public void Add_TwoPositiveNumbers_ReturnsSum() { ... }
```

**Optional parameters:**
- `DisplayName` — overrides the name shown in test output.
- `Skip` — marks the test as skipped with a reason string.

```csharp
[Fact(DisplayName = "Adder: 2+3=5", Skip = "Under investigation")]
public void MyTest() { ... }
```

### `[Theory]`
`[Theory]` marks a test that accepts parameters. xUnit runs the method once for each data row supplied by a companion attribute. A `[Theory]` without at least one data attribute will throw a `TheoryWithoutDataException` at runtime.

Companion data attributes:

| Attribute | Where data lives | Best for |
|---|---|---|
| `[InlineData]` | Inline in source code | Simple primitives |
| `[MemberData]` | Static property/method on a class | Complex objects, shared data |
| `[ClassData]` | Separate class implementing `IEnumerable<object[]>` | Encapsulated, reusable data sets |

### Other Discovery Attributes (less common)

| Attribute | Purpose |
|---|---|
| `[SkippableFact]` | Skips dynamically based on a condition (via `Skip.If`) |
| `[Trait("Category","Slow")]` | Adds metadata for filtering |
| `[Collection("DB")]` | Assigns test class to a named collection |

### Comparison: xUnit vs NUnit vs MSTest

| Concept | xUnit | NUnit | MSTest |
|---|---|---|---|
| Simple test | `[Fact]` | `[Test]` | `[TestMethod]` |
| Parameterised test | `[Theory]` | `[TestCase]` | `[DataTestMethod]` |
| Inline data | `[InlineData]` | Arguments on `[TestCase]` | `[DataRow]` |

> 💡 xUnit intentionally has fewer attributes than NUnit or MSTest. There are no `[SetUp]`/`[TearDown]` attributes — setup belongs in the constructor; teardown in `IDisposable`.

## Code Example
```csharp
namespace Math.Tests;

public class CalculatorTests
{
    // [Fact] — no parameters, runs once
    [Fact]
    public void Divide_ByZero_ThrowsDivideByZeroException()
    {
        var sut = new Calculator();
        var act = () => sut.Divide(10, 0);
        act.Should().Throw<DivideByZeroException>();
    }

    // [Theory] + [InlineData] — runs once per data row
    [Theory]
    [InlineData(6,  2, 3)]
    [InlineData(10, 5, 2)]
    [InlineData(0,  1, 0)]
    public void Divide_ValidInputs_ReturnsExpectedQuotient(
        int dividend, int divisor, int expected)
    {
        var sut = new Calculator();
        sut.Divide(dividend, divisor).Should().Be(expected);
    }

    // [Fact] with DisplayName
    [Fact(DisplayName = "Calculator handles negative dividend correctly")]
    public void Divide_NegativeDividend_ReturnsNegativeQuotient()
    {
        new Calculator().Divide(-8, 2).Should().Be(-4);
    }
}
```

## Common Follow-up Questions
- What is the difference between `[Fact]` and `[Theory]`?
- What happens if you add a `[Theory]` with no data attribute?
- How do you skip a specific test case within a `[Theory]`?
- How does xUnit discover tests at build time vs runtime?
- What is the `[Trait]` attribute and how is it used for test filtering?
- How do you run only tests with a specific trait in `dotnet test`?

## Common Mistakes / Pitfalls
- **`[Theory]` with no data source** — causes a runtime exception, not a compilation error.
- **Using `[Fact]` for parameterised scenarios** — leads to duplicate test methods with slight variations; use `[Theory]` instead.
- **Forgetting the test method must be `public`** — xUnit ignores non-public test methods without warning.
- **Async void test methods** — `async void` silently swallows exceptions; use `async Task` instead.
- **Putting `[Fact]` on a non-void, non-Task method** — the return value is ignored and exceptions may not surface correctly.

## References
- [xUnit documentation — Getting started](https://xunit.net/docs/getting-started/netcore/cmdline)
- [xUnit documentation — Attributes reference](https://xunit.net/docs/comparisons)
- [Microsoft Learn — Unit testing with xUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [Andrew Lock — Getting started with xUnit](https://andrewlock.net/creating-parameterised-tests-in-xunit-with-inlinedata-classdata-and-memberdata/)
