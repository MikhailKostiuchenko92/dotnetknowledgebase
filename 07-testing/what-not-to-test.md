# How Do You Decide What NOT to Test?

**Category:** Testing / Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `test-strategy`, `over-testing`, `cost-benefit`, `trivial-code`, `test-value`

## Question
> How do you decide what NOT to test?

## Short Answer
Skip tests when the cost of writing and maintaining them exceeds the value they deliver. In practice: don't test trivial code with no logic (getters/setters, DTOs), don't test the framework itself, don't test private implementation details, and don't test code that is covered more cheaply at another layer of the pyramid.

## Detailed Explanation

### The Value-Cost Model
Every test has a **cost** (write time, maintenance time, false positives) and a **value** (confidence, regression protection, documentation). Only write a test when `value > cost`.

Vladimir Khorikov distils this into four quadrants based on two axes:
- **Domain significance** (how business-critical is this code?)
- **Collaboration complexity** (how many dependencies does the code have?)

| | Low complexity | High complexity |
|---|---|---|
| **Low domain significance** | ❌ Don't test (controllers, simple glue code) | 🟡 Integration tests only |
| **High domain significance** | ✅ Unit test (algorithms, business rules) | ✅ Unit + integration |

### What Typically Is NOT Worth Unit Testing

#### 1. Trivial Code — No Logic
Auto-properties, constructors that just assign fields, pure DTOs/records, and `ToString()` overrides contain no branching logic. A failing test on them indicates a broken build, not a logic bug.

```csharp
// Not worth testing — no logic to break
public record ProductDto(int Id, string Name, decimal Price);
```

#### 2. Framework Behaviour
Do not test that `List<T>.Add` adds items, that EF Core `SaveChanges` persists data, or that ASP.NET Core routing resolves a URL. The framework is already tested by Microsoft.

#### 3. Private Methods
Private methods are an implementation detail. Test them through the public API they support. If a private method is large and complex enough to warrant direct testing, it is a signal to extract it into a separate class.

#### 4. Infrastructure Wiring That Integration Tests Cover Better
If you have an integration test that exercises the controller → service → DB path, a separate unit test of the controller that mocks the service is lower-value redundancy.

#### 5. Generated Code
Auto-generated code (EF Core migrations, protobuf/gRPC stubs, OpenAPI scaffolding) does not need unit tests. Focus on the logic built *on top of* generated code.

### The Productive Conflict: "But it increases coverage metrics"
Code coverage is a useful signal for *finding untested paths*, not a target to maximise. A test that only exists to push coverage from 94% to 96% on trivial code delivers negative value: it adds maintenance burden without meaningful protection.

> ⚠️ **Warning:** 100% unit test coverage is neither achievable nor desirable. Many of the most dangerous bugs live in integration paths (database constraints, serialization, auth), not in pure business logic.

### A Practical Checklist

Ask these questions before writing a test:
1. Does this code contain conditional logic, loops, or complex calculations? → **Write a unit test.**
2. Does this code coordinate I/O with external systems? → **Write an integration test.**
3. Is this a critical user workflow? → **Write one E2E test.**
4. Is this a property, DTO, or getter with no logic? → **Skip.**
5. Am I testing the framework or a third-party library? → **Skip.**
6. Will this test break whenever I rename a private method or reorganise code? → **Skip, reconsider design.**

## Code Example
```csharp
// ❌ Not worth testing — no logic
public class CustomerDto
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
}

// ❌ Not worth testing — framework responsibility
var list = new List<int>();
list.Add(1);
list.Count.Should().Be(1); // testing BCL, not your code

// ✅ Worth testing — non-trivial business rule
public class LoanEligibilityService
{
    public bool IsEligible(Customer customer, decimal requestedAmount)
    {
        if (customer.CreditScore < 600) return false;
        if (requestedAmount > customer.AnnualIncome * 5) return false;
        if (customer.HasActiveBankruptcy) return false;
        return true;
    }
}

// All three branches above warrant explicit unit tests
[Theory]
[InlineData(550, 50_000, false, 100_000, false)] // low credit score
[InlineData(700, 50_000, false, 5_000, false)]   // exceeds income ratio
[InlineData(700, 50_000, true,  50_000, false)]  // active bankruptcy
[InlineData(700, 50_000, false, 50_000, true)]   // eligible
public void IsEligible_ReturnsExpectedResult(
    int creditScore, decimal income, bool hasBankruptcy,
    decimal requested, bool expected)
{
    var sut = new LoanEligibilityService();
    var customer = new Customer
    {
        CreditScore = creditScore, AnnualIncome = income,
        HasActiveBankruptcy = hasBankruptcy
    };

    sut.IsEligible(customer, requested).Should().Be(expected);
}
```

## Common Follow-up Questions
- How do you measure test value in a codebase you didn't write?
- What are "test smells" that suggest over-testing?
- How do you respond to a code review comment that says "you didn't test X"?
- When does removing tests make a codebase healthier?
- How do you handle legacy code where even the trivial paths are risky?
- What is mutation testing and how does it reveal gaps in a test suite that has high coverage?

## Common Mistakes / Pitfalls
- **Testing auto-properties** — adds zero value, increases test count making the suite feel large but weak.
- **Testing private methods via reflection** — creates extremely brittle tests and signals a design problem.
- **Writing tests for third-party libraries** — waste of time; trust their own test suite.
- **Chasing 100% coverage on trivial paths** — distorts metrics without improving safety.
- **Not testing error paths to "keep tests simple"** — the most damaging bugs often live in edge cases and error flows.

## References
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
- [Vladimir Khorikov — What to test and what not to](https://enterprisecraftsmanship.com/posts/what-to-test-and-what-not-to/)
- [Martin Fowler — Test Coverage](https://martinfowler.com/bliki/TestCoverage.html)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Roy Osherove — The Art of Unit Testing, 3rd Ed.](https://www.manning.com/books/the-art-of-unit-testing-third-edition)
