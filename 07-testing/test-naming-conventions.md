# How Should You Name Test Methods?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `test-naming`, `test-design`, `readability`, `MethodName_Scenario_ExpectedBehavior`

## Question
> How should you name test methods? (e.g., `MethodName_Scenario_ExpectedBehavior`)

## Short Answer
The most widely used convention is `MethodUnderTest_Scenario_ExpectedBehavior` — three parts separated by underscores. The name should read as a specification of behaviour: what is tested, under what conditions, and what the outcome is. A good test name is a failing test's first debugging clue — it should tell you what broke without opening the file.

## Detailed Explanation

### Convention 1: `Method_Scenario_ExpectedBehavior` (Most Common)
```csharp
[Fact]
public void ProcessOrder_ValidOrder_ReturnsConfirmedStatus() { }

[Fact]
public void ProcessOrder_NullOrder_ThrowsArgumentNullException() { }

[Fact]
public void ProcessOrder_ZeroAmount_ThrowsArgumentException() { }
```

### Convention 2: `Given_When_Then` (BDD-inspired)
```csharp
[Fact]
public void GivenValidOrder_WhenProcessed_ThenStatusIsConfirmed() { }

[Fact]
public void GivenNullCustomer_WhenRegistering_ThenArgumentNullExceptionIsThrown() { }
```

### Convention 3: Fluent Sentence (Verbose but Expressive)
```csharp
[Fact]
public void Process_should_return_confirmed_status_for_a_valid_order() { }
```
Used by some BDD frameworks and Shouldly-style communities. Reads well in test reports.

### Convention 4: `When...` / `Should...` Prefix
```csharp
[Fact]
public void WhenOrderAmountIsNegative_ShouldThrowArgumentException() { }
```

### Choosing a Convention
| Convention | Readability | Length | Common in |
|---|---|---|---|
| `Method_Scenario_Expected` | ✅ High | Short–Medium | Most .NET codebases |
| `Given_When_Then` | ✅ High | Medium | BDD-inspired projects |
| Sentence style | ✅✅ Very High | Long | SpecFlow, Shouldly teams |
| `WhenX_ShouldY` | ✅ High | Medium | NUnit-heavy codebases |

> 💡 Pick one convention per codebase and enforce it consistently. Mixed conventions inside a single project are worse than any single convention.

### What Makes a Bad Name
```csharp
// ❌ Too vague
[Fact] public void Test1() { }
[Fact] public void ProcessTest() { }
[Fact] public void OrderTest2() { }

// ❌ Describes implementation, not behaviour
[Fact] public void ProcessOrder_CallsRepository_ThenCallsNotifier() { }

// ✅ Describes observable behaviour
[Fact] public void ProcessOrder_ValidOrder_SendsConfirmationEmail() { }
```

### Using `[Trait]` / Display Names for Test Reports
```csharp
[Fact(DisplayName = "Process order: confirmed status returned for valid input")]
public void ProcessOrder_ValidOrder_ReturnsConfirmedStatus() { }
```

## Code Example
```csharp
namespace NamingConventions.Tests;

public class DiscountServiceTests
{
    private readonly DiscountService _sut = new();

    // ── Method_Scenario_Expected ──────────────────────────
    [Fact]
    public void ApplyDiscount_ValidVoucher_ReducesPriceByVoucherAmount() { /* ... */ }

    [Fact]
    public void ApplyDiscount_ExpiredVoucher_ThrowsVoucherExpiredException() { /* ... */ }

    [Fact]
    public void ApplyDiscount_NullVoucher_ThrowsArgumentNullException() { /* ... */ }

    [Fact]
    public void ApplyDiscount_ZeroPercentVoucher_ReturnsOriginalPrice() { /* ... */ }

    [Fact]
    public void ApplyDiscount_HundredPercentVoucher_ReturnsFreeOrder() { /* ... */ }

    // ── Theory variant with descriptive scenario in InlineData ────
    [Theory]
    [InlineData(0, "zero")]
    [InlineData(-1, "negative")]
    [InlineData(101, "over 100 percent")]
    public void ApplyDiscount_InvalidPercentage_ThrowsArgumentOutOfRangeException(
        int percent, string scenario)
    {
        Action act = () => _sut.ApplyDiscount(100m, percent);
        act.Should().Throw<ArgumentOutOfRangeException>(
            $"because {scenario} percent is invalid");
    }
}
```

## Common Follow-up Questions
- Which naming convention is most common in .NET OSS projects?
- How do you make `[Theory]` test names descriptive in CI output?
- Should you include "should" in test names?
- How do you enforce naming conventions with analyzers?
- What is `DisplayName` in xUnit and NUnit and when should you use it?
- How do you name tests for private-method behaviour (tested indirectly)?

## Common Mistakes / Pitfalls
- **Generic names like `Test1`, `ProcessTest`** — impossible to diagnose failures from the test report.
- **Describing implementation (`CallsRepository`) rather than behaviour (`SendsConfirmationEmail`)** — breaks when internals refactor.
- **Omitting the scenario part** — `ProcessOrder_ReturnsConfirmedStatus` doesn't say *when* it returns confirmed status.
- **Inconsistent conventions** — mixing `_Should_` and `_Returns_` and `Given_When_Then` in the same class is harder to scan than any single convention.
- **Too long names** — over 80 characters become unreadable in CI output; prefer concise scenarios.

## References
- [Microsoft Learn — Unit testing best practices — naming](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices#naming-your-tests)
- [Roy Osherove — The Art of Unit Testing](https://www.artofunittesting.com/)
- [xUnit documentation](https://xunit.net/)
