# What Coverage Percentage Should You Aim For?

**Category:** Testing / Code Coverage
**Difficulty:** 🟡 Middle
**Tags:** `code-coverage`, `coverage-threshold`, `testing-strategy`, `quality`

## Question
> What coverage percentage should you aim for and why is 100% not always meaningful?

## Short Answer
A common pragmatic target is **80% line / 70% branch coverage** for business-critical code. 100% coverage is achievable but rarely worthwhile — it incentivises writing tests that cover lines without asserting anything, and it consumes effort better spent on meaningful high-value tests for complex and risky paths.

## Detailed Explanation

### What 100% Coverage Actually Means
High coverage tells you that each line was *executed*. It says nothing about whether:
- The assertions are correct
- Edge cases produce the right result
- The method under test is even called with realistic inputs

```csharp
[Fact]
public void Covers_Line_But_Asserts_Nothing()
{
    var sut = new DiscountService();
    sut.Calculate(100m, "VIP"); // executes lines — but no assertion!
}
// Coverage: 100% | Value: 0
```

### Why the Magic Number Is Not 100%

| Coverage % | Interpretation |
|---|---|
| < 60% | Likely under-tested; high risk in production |
| 60–80% | Acceptable baseline; identify critical paths first |
| 80–90% | Good for most business applications |
| > 90% | High value only if assertions are meaningful |
| 100% | Often wastes effort on trivial getters, constructors, generated code |

### Practical Guidance by Code Area

| Area | Recommended coverage |
|---|---|
| Core domain logic | 90–100% branch |
| Application services | 80–90% |
| Controllers/endpoints | 60–80% (integration tests may handle this) |
| Infrastructure (repo, DB) | Integration tests cover this; unit coverage may be low |
| Auto-generated code | 0% (exclude it) |

### Excluding Auto-Generated Code
Use `[ExcludeFromCodeCoverage]` on EF migrations, generated files, and scaffolded code:
```csharp
[ExcludeFromCodeCoverage]
public partial class AddOrdersTable : Migration { ... }
```

Or via Coverlet filter:
```shell
/p:Exclude="[*.Migrations]*"
```

### What to Measure Instead
- **Mutation score** (Stryker.NET) — reveals tests that don't actually verify behaviour
- **Critical path coverage** — verify that your most important workflows are tested end-to-end
- **Defect escape rate** — what % of production bugs had test coverage at the time?

## Code Example
```csharp
// ❌ 100% coverage, zero value:
[Fact]
public void PriceCalculator_Runs()
{
    new PriceCalculator().Calculate(100, 0.2m); // no assertion
}

// ✅ 80% coverage, high value:
[Theory]
[InlineData(100, 0.0, 100)]
[InlineData(100, 0.2, 80)]
[InlineData(0,   0.5, 0)]
public void PriceCalculator_AppliesDiscount_Correctly(
    decimal price, decimal discount, decimal expected)
{
    var sut = new PriceCalculator();
    sut.Calculate(price, discount).Should().Be(expected);
}
```

## Common Follow-up Questions
- How do you set a minimum coverage threshold in CI to fail the build?
- What is mutation testing and why is it better than raw coverage metrics?
- How does coverage percentage interact with test quality?
- What parts of a .NET application are hardest to cover and how do you approach them?
- Should you measure branch coverage or line coverage as your KPI?

## Common Mistakes / Pitfalls
- **Setting 100% as a hard CI gate** — developers write meaningless tests to satisfy the metric.
- **Using global coverage numbers** — an 80% total might hide 10% coverage on the most critical business logic.
- **Not excluding generated code** — EF migrations, scaffolded Razor Pages, or source generators lower coverage scores unfairly.
- **Treating coverage as a substitute for test review** — code review of test quality matters more than the coverage number.

## References
- [Martin Fowler — Test Coverage](https://martinfowler.com/bliki/TestCoverage.html)
- [Microsoft Learn — Code coverage thresholds](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage#thresholds)
- [Coverlet — Threshold configuration](https://github.com/coverlet-coverage/coverlet#threshold)
