# What Is the Difference Between a Unit Test, Integration Test, and End-to-End Test?

**Category:** Testing / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `unit-test`, `integration-test`, `e2e`, `testing-pyramid`, `test-types`

## Question
> What is the difference between a unit test, an integration test, and an end-to-end test?

## Short Answer
Unit tests verify isolated logic in a single class or method with all dependencies replaced. Integration tests verify that two or more real components interact correctly (e.g., your code + a database). End-to-end (E2E) tests exercise the entire system stack — UI, API, database — through the real user interface or HTTP interface, verifying complete user workflows.

## Detailed Explanation

### Test Type Comparison

| Property | Unit | Integration | End-to-End |
|---|---|---|---|
| **Scope** | One class/method | 2–N components | Full system |
| **Dependencies** | All mocked/stubbed | Mix of real + fakes | All real |
| **Speed** | <5 ms | 100 ms–5 s | 5 s–5 min |
| **Reliability** | Very high | Medium | Lower (env-dependent) |
| **Debugging ease** | Easy | Medium | Hard |
| **Coverage type** | Logic, edge cases | Wiring, contracts | User workflows, regressions |
| **Cost to maintain** | Low | Medium | High |

### Unit Tests
Test a single unit of behaviour in total isolation. All collaborators (repositories, HTTP clients, loggers) are replaced with doubles.

**Good for:** business rules, algorithms, domain logic, edge cases, error paths.

**Not good for:** verifying that your EF Core mapping generates correct SQL, that your middleware executes in the right order, or that your auth token is validated correctly.

### Integration Tests
Verify that *components integrate correctly*. In .NET, this typically means:
- Your service code + real `DbContext` (using SQLite in-memory or a Testcontainers DB)
- Your ASP.NET Core pipeline + routing + DI + middleware (using `WebApplicationFactory`)
- Your message handler + real in-process broker

> 💡 The term "integration test" is overloaded. Some teams use "narrow integration tests" (two real classes, nothing else) vs. "broad integration tests" (multiple services with real DB). Both are valid — just be explicit.

### End-to-End Tests
Exercise the entire system through its public interface — usually HTTP or a browser:
- Playwright / Selenium drives a real browser
- An HTTP client hits a deployed (or `TestServer`) API and asserts on responses
- The database, auth server, and all dependencies are real

E2E tests are the highest-confidence but most expensive. They catch regressions that slip through unit and integration layers, but they are slow, brittle (dependent on environment), and hard to debug.

### The Relationship to the Testing Pyramid
Unit → Integration → E2E follows the testing pyramid: many fast unit tests at the base, fewer integration tests in the middle, very few (but critical) E2E tests at the top. See [testing-pyramid.md](testing-pyramid.md).

> ⚠️ **Antipattern — Ice-cream cone:** When there are *more* E2E tests than unit tests, the suite is slow, expensive, and difficult to maintain. This often happens when teams discover bugs through manual QA rather than automated unit tests.

## Code Example
```csharp
// ── 1. Unit test (no real dependencies) ──────────────────────────────────────
namespace Orders.Tests.Unit;

public class PricingEngineTests
{
    [Fact]
    public void GetPrice_WithBulkDiscount_ReturnsReducedPrice()
    {
        var engine = new PricingEngine(bulkThreshold: 10, discountRate: 0.05m);
        engine.GetPrice("SKU-1", quantity: 15).Should().Be(14.25m); // 15 * (1 - 0.05)
    }
}

// ── 2. Integration test (real DbContext + SQLite) ─────────────────────────────
public class OrderRepositoryTests : IClassFixture<SqliteFixture>
{
    private readonly AppDbContext _db;

    public OrderRepositoryTests(SqliteFixture f) => _db = f.CreateContext();

    [Fact]
    public async Task CreateOrder_PersistsAndReadsBack()
    {
        var repo = new OrderRepository(_db);
        var id = await repo.CreateAsync(new Order { CustomerId = 1, Total = 99m });

        var loaded = await repo.GetByIdAsync(id);
        loaded!.Total.Should().Be(99m);
    }
}

// ── 3. End-to-end / integration test (WebApplicationFactory) ─────────────────
public class OrdersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersApiTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task PostOrder_Returns201WithLocation()
    {
        var response = await _client.PostAsJsonAsync("/orders",
            new { CustomerId = 1, Items = new[] { new { Sku = "A", Qty = 2 } } });

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();
    }
}
```

## Common Follow-up Questions
- What is the testing pyramid and how do you decide how many tests of each type to write?
- What is a "narrow" vs. "broad" integration test?
- How does `WebApplicationFactory` enable in-process integration tests without a real HTTP server?
- What is Testcontainers and when would you use it over an in-memory provider?
- How do you balance test confidence with execution speed in a CI/CD pipeline?
- What is the "test trophy" (Kent C. Dodds) alternative to the pyramid?

## Common Mistakes / Pitfalls
- **Calling E2E tests "integration tests"** — they have very different maintenance cost profiles.
- **Under-investing in unit tests** — leads to the ice-cream cone antipattern: many slow E2E tests, few unit tests, high CI cost.
- **No integration tests at all** — pure unit tests can't catch SQL mapping errors, constraint violations, or DI misconfigurations.
- **Running E2E tests on every commit** — should gate release, not every PR; too slow for developer feedback.
- **Non-deterministic E2E tests** — timing-dependent waits (`Thread.Sleep`) instead of proper polling or `WaitUntil` constructs.

## References
- [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [Kent C. Dodds — The Testing Trophy](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications)
- [Andrew Lock — Testing ASP.NET Core apps with WebApplicationFactory (series)](https://andrewlock.net/tag/testing/)
- [Testcontainers for .NET](https://dotnet.testcontainers.org/)
