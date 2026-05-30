# What Are "Test Smells" and What Are Common Examples?

**Category:** Testing / Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `test-smells`, `test-quality`, `anti-patterns`, `maintainability`, `mystery-guest`, `eager-test`

## Question
> What are "test smells" and can you name common ones (e.g., Mystery Guest, Eager Test, Logic in Tests)?

## Short Answer
Test smells are patterns in test code that signal potential problems: reduced readability, maintainability, or trustworthiness. Like production code smells, they don't always mean the test is broken, but they indicate it may be fragile, hard to understand, or failing to provide real value.

## Detailed Explanation

### Why Test Smells Matter
A test suite is a safety net. If the tests themselves are poorly written, they erode trust, produce false positives/negatives, and become a maintenance burden that developers want to bypass. Identifying and addressing test smells is as important as addressing production code smells.

### Catalogue of Common Test Smells

#### 1. Mystery Guest 🕵️
The test depends on external state — a file, a database record, a global config — that is not visible in the test body. Readers cannot understand the test without hunting for the external resource.

**Symptom:** Test passes locally but fails on CI; you need to read three files to understand one test.  
**Fix:** Create all required state in the Arrange section of the test itself.

#### 2. Eager Test (Testing Too Much)
A single test method verifies multiple, unrelated behaviours. When it fails, you cannot tell which behaviour broke.

**Symptom:** Test method has 10+ assertions across different logical concerns.  
**Fix:** Split into multiple focused tests — one test, one concept.

#### 3. Logic in Tests
The test contains `if`, `for`, `switch`, or other control flow. Logic in tests means the test itself can have bugs.

**Symptom:** A test that "always passes" because the assertion is inside an `if` block that is never entered.  
**Fix:** Use `[Theory]` / `[InlineData]` for parameterised cases; keep each test linear.

#### 4. Chatty / Over-Specified Test
The test verifies every intermediate interaction with every collaborator, rather than the final observable outcome. Breaks on every internal refactoring.

**Symptom:** `Verify(r => r.FindById(...), Times.Once)` everywhere, even when it is not the outcome you care about.  
**Fix:** Only verify interactions that are the *purpose* of the test (see [state-vs-interaction-testing.md](state-vs-interaction-testing.md)).

#### 5. Flaky Test
Passes sometimes and fails other times without code changes. Destroys trust in the entire suite.

**Common causes:** `Thread.Sleep`, real clocks, random values, shared mutable state, race conditions.  
**Fix:** Remove non-determinism — inject time, seed randomness, ensure isolation.

#### 6. Test Pollution / Fixture Teardown Missing
A test leaves behind state (DB rows, temp files, modified singletons) that affects subsequent tests.

**Fix:** Implement `IDisposable` or use transactional rollback to clean up after each test.

#### 7. Obscure Test / Long Arrange
The Arrange section is so long and complex that the intent is lost. Related to large, tangled classes that have too many dependencies.

**Fix:** Extract a Test Data Builder or Object Mother to encapsulate setup.

#### 8. Dead Test
A `[Skip]`-ed or commented-out test that was never fixed. Accumulates and silently reduces coverage.

**Fix:** Fix it, delete it, or file a ticket — never leave broken tests permanently skipped.

#### 9. Assertion Roulette
Multiple assertions with no messages; when one fails you cannot tell which assertion triggered or why.

**Fix:** Use descriptive assertion libraries (FluentAssertions) or add `.Because()` messages; alternatively split into separate tests.

#### 10. Slow Test
A unit test that takes hundreds of milliseconds because it hits the file system, does real network I/O, or spins up a container.

**Fix:** Replace infrastructure with fakes; move genuine I/O tests to the integration layer.

### Quick Reference Table

| Smell | Core Problem | Quick Fix |
|---|---|---|
| Mystery Guest | Hidden dependencies | Move setup into test body |
| Eager Test | Multiple behaviours | One test per concept |
| Logic in Tests | Tests can have bugs | Use `[Theory]` or linear assertions |
| Over-Specified | Brittle to refactoring | Assert outcomes, not internals |
| Flaky Test | Non-determinism | Inject/abstract non-deterministic sources |
| Test Pollution | Order-dependent | Cleanup in `IDisposable` |
| Obscure Test | Long Arrange | Test Data Builder / Object Mother |
| Dead Test | Silent coverage loss | Fix or delete |
| Assertion Roulette | Unknown failure point | One assertion or descriptive messages |
| Slow Test | I/O in unit test | Replace with fakes |

## Code Example
```csharp
// ❌ Mystery Guest + Logic in Tests + Eager Test
[Fact]
public void BadTest()
{
    var customer = File.ReadAllText("testdata/customer.json"); // mystery guest
    var sut = new CustomerService();

    if (customer != null) // logic in test
    {
        var result = sut.Process(customer);
        result.IsValid.Should().BeTrue();      // multiple concepts...
        result.Points.Should().BeGreaterThan(0); // ...in one test
        result.Tier.Should().Be("Gold");
    }
}

// ✅ Clean: self-contained, single concept, no control flow
[Fact]
public void Process_WhenHighSpender_AssignsGoldTier()
{
    // Arrange — all state visible in the test body
    var customer = new CustomerBuilder()
        .WithAnnualSpend(10_000m)
        .Build();
    var sut = new CustomerService();

    // Act
    var result = sut.Process(customer);

    // Assert — one logical concept
    result.Tier.Should().Be("Gold");
}

[Fact]
public void Process_WhenHighSpender_AwardsLoyaltyPoints()
{
    var customer = new CustomerBuilder().WithAnnualSpend(10_000m).Build();
    var result = new CustomerService().Process(customer);
    result.Points.Should().BeGreaterThan(0);
}
```

## Common Follow-up Questions
- How do you identify test smells in a CI pipeline (tools, metrics)?
- What is the relationship between test smells and production code design issues?
- How do you refactor tests without breaking them?
- What is an Object Mother pattern and how does it solve the Mystery Guest smell?
- How do you decide when a flaky test is acceptable vs. a blocker?
- What is mutation testing and how does it expose hidden test smells?

## Common Mistakes / Pitfalls
- **Skipping tests instead of fixing them** — accumulates dead tests that erode coverage.
- **Believing passing tests mean good tests** — a test can pass and be worthless (no assertion, always-true logic).
- **Refactoring production code without updating tests** — often the test smell was papering over a design problem.
- **Mass-commenting tests under deadline pressure** — creates technical debt that is rarely addressed.
- **Not reviewing test code in PRs** — tests should receive the same scrutiny as production code.

## References
- [Gerard Meszaros — xUnit Test Patterns: Refactoring Test Code (book)](http://xunitpatterns.com/)
- [Lasse Koskela — Test Smells catalogue at xunitpatterns.com](http://xunitpatterns.com/Test%20Smells.html)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
- [Martin Fowler — Test Climate / Obscure Test (refactoring catalog)](https://refactoring.com/) (verify URL)
- [Roy Osherove — The Art of Unit Testing, 3rd Ed.](https://www.manning.com/books/the-art-of-unit-testing-third-edition)
