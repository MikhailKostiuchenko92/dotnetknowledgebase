# What Makes a "Good" Unit Test? (FIRST Criteria)

**Category:** Testing / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `FIRST`, `unit-test`, `test-quality`, `best-practices`

## Question
> What makes a "good" unit test? Describe the FIRST criteria.

## Short Answer
The FIRST acronym — **Fast, Isolated, Repeatable, Self-validating, Timely** — defines the properties of a high-quality unit test. Tests that violate any of these properties erode trust in the test suite and slow the development cycle.

## Detailed Explanation

### F — Fast
Unit tests should run in **milliseconds**, not seconds. A suite of thousands of slow tests discourages frequent execution, which defeats their purpose as a fast feedback loop. Slowness is usually caused by hitting real I/O (database, file system, network) — replace these with fakes or in-memory alternatives.

### I — Isolated (Independent)
Each test must be **fully independent** from every other test:
- No shared mutable state between test instances.
- No dependency on test execution order.
- Teardown any state changes (or avoid them altogether by using fresh objects per test).

xUnit enforces this by constructing a new test class instance per test method, which is the right default.

### R — Repeatable
A test must produce the **same result every time** it runs, in any environment, on any machine, at any time of day. Flaky tests destroy confidence and cause false positives in CI.

Common causes of non-repeatability:
- Reading `DateTime.Now` or `DateTime.UtcNow` directly
- Relying on `Guid.NewGuid()` for equality checks
- Depending on file paths or environment variables
- Concurrency bugs in test setup

Wrap non-deterministic dependencies behind abstractions (`ITimeProvider`, `IGuidProvider`) and inject them.

### S — Self-validating
Tests must **pass or fail automatically** without manual inspection of log files, console output, or database contents. An assertion must be present and it must check the right thing. A test that runs without throwing is not self-validating unless there is a meaningful `Assert`.

### T — Timely
Write tests **at the same time as (or before) the production code** they verify. Tests written long after the fact are harder to write well — the API may already be untestable, and the author's memory of edge cases has faded. This is the TDD principle baked into FIRST.

### Summary Table

| Letter | Property | Violation symptom |
|---|---|---|
| F | Fast | Tests take seconds; developers skip the run |
| I | Isolated | Tests pass solo but fail together |
| R | Repeatable | Tests pass on dev machine, fail on CI |
| S | Self-validating | Test "passes" but has no assertions |
| T | Timely | Tests written months after code is shipped |

> 💡 **Tip:** The "I" is sometimes expanded to *Independent* **and** *Isolated from external systems*, covering both test-to-test independence and infrastructure independence.

## Code Example
```csharp
namespace Billing.Tests;

public class InvoiceGeneratorTests
{
    // ✅ FIRST-compliant test
    [Fact]
    public void Generate_ProducesInvoiceWithCorrectTotal()
    {
        // Fast   — no I/O, runs in <1 ms
        // Isolated — no shared state; fresh objects per test
        // Repeatable — no DateTime.Now; time injected via interface
        // Self-validating — explicit assertion
        // Timely — written alongside the production code

        var timeProvider = new FakeTimeProvider(new DateTime(2025, 1, 15));
        var sut = new InvoiceGenerator(timeProvider);
        var items = new[] { new LineItem(Price: 10m, Qty: 3) };

        var invoice = sut.Generate(customerId: 42, items);

        invoice.Total.Should().Be(30m);
        invoice.IssuedAt.Should().Be(new DateTime(2025, 1, 15));
    }

    // ❌ Violates Repeatable and Isolated (depends on current time)
    [Fact]
    public void Generate_BadExample_UsesRealDateTime()
    {
        var sut = new InvoiceGenerator(); // internally calls DateTime.Now
        var invoice = sut.Generate(42, [new LineItem(10m, 1)]);

        // This assertion may behave differently depending on the day
        invoice.IssuedAt.Date.Should().Be(DateTime.Today);
    }
}
```

## Common Follow-up Questions
- How do you make a test that uses `DateTime.Now` repeatable?
- What is the relationship between the FIRST properties and the testing pyramid?
- How do you handle tests that *need* shared expensive setup (e.g., database schema creation)?
- What is the difference between FIRST and the AAA pattern?
- How do you diagnose and fix a flaky test?
- When is a test "fast enough"? Is there a threshold?

## Common Mistakes / Pitfalls
- **Static mutable state** (`static List<T>` caches, singletons with state) makes tests non-isolated — tests pass individually but fail when run together.
- **Asserting on `Console.WriteLine` output** instead of return values or observable state violates S (Self-validating).
- **`Thread.Sleep` in tests** to wait for async operations is both slow (F) and flaky (R); use `async/await` properly.
- **Tests that always pass regardless of implementation** — empty assertions, catching all exceptions silently — violate S.
- **Writing tests after a bug is found in production** rather than as part of development violates T.

## References
- [Robert C. Martin — Clean Code, Chapter 9 (Unit Tests)](https://www.goodreads.com/book/show/3735293-clean-code)
- [Microsoft Learn — Unit testing best practices in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Vladimir Khorikov — What makes a good unit test?](https://enterprisecraftsmanship.com/posts/unit-test-value-estimation/)
- [Tim Ottinger & Jeff Langr — Clean Code's F.I.R.S.T principles (OreillY)](https://www.oreilly.com/library/view/clean-code-a/9780136083238/) (verify URL)
