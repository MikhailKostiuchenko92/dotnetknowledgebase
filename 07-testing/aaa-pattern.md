# What Is the AAA (Arrange–Act–Assert) Pattern and Why Is It Important?

**Category:** Testing / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `aaa`, `arrange-act-assert`, `test-structure`, `readability`

## Question
> What is the AAA (Arrange–Act–Assert) pattern and why is it important?

## Short Answer
AAA is a three-phase structure for writing unit tests: **Arrange** sets up preconditions and inputs, **Act** exercises the system under test, and **Assert** verifies the expected outcome. It improves test readability by making the intent of every test immediately clear to any reader.

## Detailed Explanation

### The Three Phases

| Phase | Purpose | Typical content |
|---|---|---|
| **Arrange** | Set the scene | Create objects, configure mocks, prepare input data |
| **Act** | Execute the behaviour | Call the method or trigger the event under test (usually one line) |
| **Assert** | Verify the result | Check return values, state changes, or interactions |

### Why It Matters

**Readability** — A developer reading a test for the first time can immediately identify *what is being set up*, *what is being tested*, and *what the expected outcome is*. Without structure, test methods become walls of code where assertion failures are ambiguous.

**Maintainability** — When a test fails, a clear Act section tells you exactly which call broke. When requirements change, a clear Arrange section makes it obvious what data needs updating.

**Communication** — Tests are living documentation. The AAA structure makes that documentation legible to every team member, including those who didn't write the code.

### Blank-Line Convention
Separate the three phases with a blank line. Use `// Arrange`, `// Act`, `// Assert` comments — especially in tests longer than five lines — so scanners can jump straight to what they need.

### One `Act` Line Rule
The Act section should almost always be a single statement. If you find yourself calling multiple methods in Act, you are either testing a workflow (which is fine for an integration test) or you have a design problem where the API forces callers to do too much work.

### Variations
- **BDD / Given-When-Then** — functionally identical to AAA; just uses different vocabulary. *Given* = Arrange, *When* = Act, *Then* = Assert.
- **Act–Assert (no Arrange)** — valid for trivial tests where no setup is needed.
- **Multiple Asserts** — generally acceptable when they all verify the same logical outcome. Avoid asserting unrelated things in the same test.

> ⚠️ **Warning:** Putting assertion logic inside the Arrange phase (e.g., asserting a mock was set up correctly) is a smell — keep each phase pure.

## Code Example
```csharp
namespace Finance.Tests;

public class DiscountCalculatorTests
{
    [Fact]
    public void Calculate_WhenCartExceedsThreshold_AppliesTenPercentDiscount()
    {
        // Arrange
        var calculator = new DiscountCalculator(threshold: 100m, discountRate: 0.10m);
        var cart = new Cart { Total = 150m };

        // Act
        decimal discounted = calculator.Calculate(cart);

        // Assert
        discounted.Should().Be(135m); // 150 - 15 (10%)
    }

    [Fact]
    public void Calculate_WhenCartBelowThreshold_AppliesNoDiscount()
    {
        // Arrange
        var calculator = new DiscountCalculator(threshold: 100m, discountRate: 0.10m);
        var cart = new Cart { Total = 80m };

        // Act
        decimal discounted = calculator.Calculate(cart);

        // Assert
        discounted.Should().Be(80m);
    }
}
```

## Common Follow-up Questions
- What is the BDD Given-When-Then naming convention and how does it relate to AAA?
- When is it acceptable to have multiple `Assert` statements in one test?
- What does it indicate when the Arrange section of a test is very long?
- How does AAA relate to the Single Responsibility Principle for tests?
- What is the difference between AAA and the Four-Phase Test pattern (also includes Teardown)?
- How would you refactor a test that mixes setup logic inside the Act phase?

## Common Mistakes / Pitfalls
- **Multiple Acts in one test** — testing a chain of operations rather than one behaviour; split into separate tests.
- **Assertions scattered throughout the Arrange phase** — impossible to tell which assertions belong to what scenario.
- **Bloated Arrange blocks** — more than 10 lines of setup is a sign the class has too many dependencies; consider a Test Data Builder.
- **Missing blank-line separators** — the test reads as one undifferentiated block; add spacing or comments.
- **Side-effect assertions hidden in Act** — e.g., `var result = sut.Save(order); // saves to DB` where the save is also the assertion target; make it explicit in Assert.

## References
- [Bill Wake — 3A – Arrange, Act, Assert (original article)](https://xp123.com/articles/3a-arrange-act-assert/)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Vladimir Khorikov — The AAA pattern](https://enterprisecraftsmanship.com/posts/aaa-pattern/)
- [xUnit documentation](https://xunit.net/docs/getting-started/netcore/cmdline)
