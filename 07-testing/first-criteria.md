# What Does the Acronym F.I.R.S.T Stand for in Unit Testing?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟢 Junior
**Tags:** `FIRST`, `unit-testing`, `test-principles`, `test-quality`

## Question
> What does the acronym F.I.R.S.T stand for in unit testing?

## Short Answer
F.I.R.S.T describes five properties of well-written unit tests: **F**ast, **I**solated (Independent), **R**epeatable, **S**elf-validating, and **T**imely (or Thorough). Tests that satisfy all five criteria are maintainable, reliable, and give developers fast, trustworthy feedback.

## Detailed Explanation

### F — Fast
Tests should run in milliseconds, not seconds. A slow test suite discourages frequent runs and delays feedback.
- **Do:** Use in-memory fakes, mocks, and SQLite in-memory instead of real databases.
- **Don't:** Hit real networks, file systems, or external services in unit tests.

### I — Isolated / Independent
Each test must be independent of every other test. Tests should not share state, depend on execution order, or leave side effects.
- **Do:** Set up everything the test needs in its own `Arrange` section.
- **Don't:** Use `static` mutable fields, global singletons, or `TestInitialize` that builds state across tests.

### R — Repeatable
Running the same test with the same code must always produce the same result — on any machine, at any time, in any environment.
- **Do:** Inject `ISystemClock` / `TimeProvider` instead of `DateTime.Now`, use fixed random seeds.
- **Don't:** Depend on `DateTime.UtcNow`, `Guid.NewGuid()`, environment variables, or network availability.

### S — Self-Validating
Tests must produce a clear pass/fail result automatically — no manual inspection of output required.
- **Do:** Use assertion libraries (`Assert`, FluentAssertions); ensure every test has at least one assertion.
- **Don't:** Write tests that `Console.WriteLine` results and require human review.

### T — Timely (or Thorough)
Write tests **before** or **alongside** code (TDD principle). Tests written long after are often skipped.  
*Thorough* variant: tests cover edge cases, not just happy paths.
- **Do:** Write the failing test first in TDD; test boundary conditions and error cases.
- **Don't:** Only test the main success path and ignore null inputs, empty collections, or exceptions.

### Summary Table

| Letter | Property | Violation Example |
|---|---|---|
| F | Fast | Test hits a real SQL Server |
| I | Isolated | Test relies on data left by a previous test |
| R | Repeatable | Test fails on weekends due to `DayOfWeek` check |
| S | Self-Validating | Test passes without assertions |
| T | Timely | Tests written 6 months after the feature |

## Code Example
```csharp
namespace FIRST.Tests;

// ❌ Violates F (slow DB), I (shared state), R (DateTime), S (no assertion)
public class BadOrderTest
{
    private static int _lastId; // shared state — violates I

    [Fact]
    public async Task Process()
    {
        // F: hits real DB
        using var db = new SqlConnection("Server=localhost;Database=orders;...");
        // R: result depends on current time
        var order = new Order { CreatedAt = DateTime.Now, Id = ++_lastId };
        await db.ExecuteAsync("INSERT INTO Orders ...", order);
        Console.WriteLine("Inserted order " + order.Id); // S: no Assert!
    }
}

// ✅ Satisfies all FIRST criteria
public class GoodOrderTest
{
    [Fact]
    public void ProcessOrder_ValidOrder_UpdatesStatus()
    {
        // Fast: in-memory fake, no DB
        // Isolated: all state created here, no shared fields
        // Repeatable: fixed time via IClock
        var clock = new FakeClock(new DateTime(2024, 6, 1, 12, 0, 0));
        var repo = new InMemoryOrderRepository();
        var sut = new OrderProcessor(repo, clock);
        var order = new Order { Id = 1, Amount = 100m };

        // Act
        sut.Process(order);

        // Self-Validating: explicit assertion
        order.Status.Should().Be(OrderStatus.Processed);
        order.ProcessedAt.Should().Be(clock.UtcNow);
    }
}
```

## Common Follow-up Questions
- Why is "fast" the most important of the FIRST criteria?
- What is the difference between "Isolated" and "Independent"?
- How do you make a test Repeatable when it depends on the current time?
- What is the "T" in FIRST — Timely or Thorough?
- How does violating "Self-Validating" lead to false-positive tests?
- How do FIRST criteria relate to the testing pyramid?

## Common Mistakes / Pitfalls
- **Tests without assertions** — if no `Assert`/`Should()` is called, the test always passes (violates S).
- **Shared mutable state in test class fields** — static or instance state carried between tests violates I and makes failures non-deterministic.
- **Using `DateTime.Now` in test data** — causes date-sensitive failures in CI on certain days/timezones (violates R).
- **Test that depends on test order** — setting up data in `TestInitialize` that accumulates across tests violates I.
- **Slow tests left in the unit test suite** — integration tests should be in a separate project/category to keep the unit suite fast.

## References
- [Robert C. Martin — Clean Code (Chapter 9: Unit Tests)](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [xUnit documentation](https://xunit.net/)
