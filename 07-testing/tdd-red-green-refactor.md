# What Are the Three Steps of TDD (Red–Green–Refactor)?

**Category:** Testing / TDD
**Difficulty:** 🟢 Junior
**Tags:** `TDD`, `test-driven-development`, `Red-Green-Refactor`, `testing-methodology`

## Question
> What are the three steps of TDD (Red–Green–Refactor)?

## Short Answer
**Red** — write a failing test that captures the desired behaviour. **Green** — write the simplest code that makes the test pass. **Refactor** — improve the code's design without breaking the tests. Repeat for each small increment of functionality.

## Detailed Explanation

### The Cycle

```
  Write failing test (RED)
         ↓
  Make it pass (GREEN)
         ↓
  Clean up code (REFACTOR)
         ↓
  (repeat)
```

### Step 1: Red — Write a Failing Test
Before any production code exists, write a test that defines what the code *should* do. The test must fail — if it passes immediately, the requirement is already satisfied or the test is wrong.

```csharp
[Fact]
public void Add_TwoPositiveNumbers_ReturnsSum()
{
    var calc = new Calculator();
    calc.Add(2, 3).Should().Be(5); // Fails: Calculator doesn't exist yet
}
```

### Step 2: Green — Make It Pass (Simply)
Write the minimum production code that makes the test pass. Do not over-engineer.

```csharp
public class Calculator
{
    public int Add(int a, int b) => a + b; // simplest implementation
}
```

### Step 3: Refactor — Clean Up
With the safety net of passing tests, improve the code:
- Extract methods / classes
- Remove duplication
- Improve naming
- Ensure tests still pass after each change

### Why the Cycle Matters
- **Red** ensures the test actually verifies something (a test that can't fail is worthless)
- **Green** focuses on making something work before making it beautiful
- **Refactor** ensures design quality without regression risk

### Typical Cadence
Each cycle should be **minutes**, not hours. If a cycle takes too long, the increment is too large — break it down further.

### TDD vs. Writing Tests After
| | TDD (test first) | Test-after |
|---|---|---|
| Design pressure | Tests drive API design | Design may not be testable |
| Feedback loop | Immediate, fine-grained | Discovered after implementation |
| Confidence | Built incrementally | Added after, may miss paths |
| Refactoring safety | Strong (tests exist) | Weak (tests written for existing code) |

## Code Example
```csharp
// RED: Failing test for string calculator kata
[Fact]
public void StringCalculator_EmptyString_ReturnsZero()
{
    var sut = new StringCalculator();
    sut.Add("").Should().Be(0); // FAILS — class doesn't exist yet
}

// GREEN: Minimal implementation
public class StringCalculator
{
    public int Add(string input)
    {
        if (string.IsNullOrEmpty(input)) return 0;
        return input.Split(',').Sum(int.Parse);
    }
}

// REFACTOR: Extract parsing; improve readability
public class StringCalculator
{
    public int Add(string input) =>
        string.IsNullOrEmpty(input) ? 0
            : ParseNumbers(input).Sum();

    private static IEnumerable<int> ParseNumbers(string input) =>
        input.Split(',').Select(int.Parse);
}
```

## Common Follow-up Questions
- What is the difference between Outside-In and Inside-Out TDD?
- How do you apply TDD when you don't know what the API should look like yet?
- Is TDD appropriate for all types of code (UI, infrastructure)?
- What is the "transformation priority premise"?
- How do you refactor safely without breaking passing tests?

## Common Mistakes / Pitfalls
- **Skipping the Red step** — writing production code before the test means the test may be validating nothing.
- **Over-implementing in Green** — writing more than what's needed to pass the current test defers refactoring and grows scope.
- **Skipping Refactor** — accumulating technical debt defeats the sustainability goal of TDD.
- **Writing too many assertions in one test** — makes the cycle longer and harder to pin failures.

## References
- [Kent Beck — Test-Driven Development: By Example](https://www.oreilly.com/library/view/test-driven-development/0321146530/)
- [Martin Fowler — Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
