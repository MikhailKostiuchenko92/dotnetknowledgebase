# What Is the Testing Pyramid and How Should You Distribute Tests Across Layers?

**Category:** Testing / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `testing-pyramid`, `test-strategy`, `unit-test`, `integration-test`, `e2e`

## Question
> What is the testing pyramid and how should you distribute tests across layers?

## Short Answer
The testing pyramid is a model by Mike Cohn that recommends having many fast unit tests at the base, fewer integration tests in the middle, and very few end-to-end tests at the top. The wider a layer, the more tests you should have there. The model guides investment so teams get maximum confidence at minimum cost.

## Detailed Explanation

### The Classic Pyramid

```
         /▲\
        / E2E \       ← few, slow, expensive
       /-------\
      /  Integr. \    ← moderate, medium speed
     /-------------\
    /  Unit Tests   \ ← many, fast, cheap
   /-----------------\
```

### Layer-by-Layer Guidance

#### Unit Tests (Base — 70–80% of total tests)
- Test a single class or function in total isolation.
- Run in milliseconds; entire suite completes in seconds.
- Cover all logic branches, edge cases, and error paths.
- Cheap to write, cheap to maintain, high ROI.

#### Integration Tests (Middle — 15–25%)
- Test the interaction between two or more real components.
- In .NET: service + DbContext, ASP.NET Core pipeline, message handlers.
- Run in seconds; a subset should run on every PR, the full set on CI.
- Catch wiring bugs, SQL mapping errors, DI misconfiguration.

#### End-to-End Tests (Top — 5–10%)
- Drive the system through its real public interface (HTTP, browser).
- Run in minutes; gate deployments, not every commit.
- Catch environment-specific regressions and full workflow failures.
- Expensive to maintain; keep them focused on critical user journeys.

### Why the Pyramid Shape?
Higher tests are slower, more brittle, and more expensive to debug. You want *confidence* at the cheapest possible price. A unit test that covers a discount calculation in 1 ms is always preferable to an E2E test that covers the same logic in 30 seconds — as long as the unit test is actually testing the right thing.

### Alternative Models

| Model | Author | Key idea |
|---|---|---|
| Testing Pyramid | Mike Cohn | Many unit, few E2E |
| Testing Trophy | Kent C. Dodds | More integration tests; fewer unit tests |
| Testing Honeycomb | Spotify | Optimised for microservices; integration-heavy |
| Ice-cream Cone (antipattern) | — | Many E2E, few unit — slow and brittle |

> 💡 The Trophy model argues that integration tests using `WebApplicationFactory` give more confidence per dollar than pure unit tests for typical web apps. Both models agree: minimise E2E, maximise fast-and-cheap tests.

### .NET-Specific Guidance
- **Unit tests:** xUnit + Moq/NSubstitute + FluentAssertions
- **Integration tests:** xUnit + `WebApplicationFactory` + Testcontainers (or SQLite in-memory)
- **E2E tests:** Playwright or a dedicated `HttpClient` test against a staging environment

### How to Distribute in Practice
Start with a question: *"What is the cheapest test that gives me sufficient confidence for this behaviour?"*
- Pure business logic → unit test.
- DB persistence → integration test with real (or near-real) DB.
- Full API contract → integration test with `WebApplicationFactory`.
- Critical checkout workflow → one or two E2E tests.

## Code Example
```csharp
// ── Unit (base): fast, isolated, business logic ───────────────────────────────
[Fact]
public void Checkout_WhenCartIsEmpty_ThrowsEmptyCartException()
{
    var sut = new CheckoutService(Mock.Of<IOrderRepository>(), Mock.Of<IPaymentGateway>());
    var act = () => sut.Checkout(new Cart());
    act.Should().Throw<EmptyCartException>();
}

// ── Integration (middle): real HTTP pipeline ──────────────────────────────────
public class CheckoutApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public CheckoutApiTests(WebApplicationFactory<Program> f) => _client = f.CreateClient();

    [Fact]
    public async Task PostCheckout_WithEmptyCart_Returns400()
    {
        var response = await _client.PostAsJsonAsync("/checkout", new { Items = Array.Empty<object>() });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}

// ── E2E (top): full stack, critical path only ─────────────────────────────────
// Typically implemented with Playwright against a deployed staging environment.
// [Fact] public async Task BuyProduct_CompletesOrderAndSendsConfirmationEmail() { ... }
```

## Common Follow-up Questions
- What is the difference between the testing pyramid and the testing trophy?
- When is it acceptable to have more integration tests than unit tests?
- How do you prevent integration tests from becoming too slow to run on every PR?
- What is test flakiness and how does it relate to the pyramid?
- How do you measure the distribution of tests in an existing project?
- What happens to the pyramid model in a microservices architecture?

## Common Mistakes / Pitfalls
- **Ice-cream cone** — many E2E tests, few unit tests; usually the result of discovering bugs through QA rather than coding.
- **Testing only the happy path in unit tests** — leaving error branches to slow E2E tests wastes budget.
- **Over-relying on mocks in integration tests** — defeats the purpose; integration tests should use real components.
- **Running the full E2E suite on every commit** — kills developer velocity; reserve for pre-release gates.
- **Ignoring the middle tier** — teams with only unit tests + E2E miss integration bugs (DI, SQL, serialization).

## References
- [Mike Cohn — The Forgotten Layer of the Test Automation Pyramid](https://www.mountaingoatsoftware.com/blog/the-forgotten-layer-of-the-test-automation-pyramid)
- [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Kent C. Dodds — The Testing Trophy](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications)
- [Microsoft Learn — Testing in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/)
- [Spotify Engineering — Testing strategies in a microservice architecture](https://engineering.atspotify.com/2018/01/testing-of-microservices/) (verify URL)
