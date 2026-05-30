# When Is TDD Impractical or Counterproductive?

**Category:** Testing / TDD
**Difficulty:** 🔴 Senior
**Tags:** `TDD`, `limitations`, `spike`, `exploratory-code`, `pragmatic-testing`

## Question
> When is TDD impractical or counterproductive (e.g., exploratory code, spike solutions)?

## Short Answer
TDD is impractical when the design space is unknown (exploratory/spike code), when you're testing pure UI/pixel-level layout, when writing thin infrastructure adapters, or when the tests themselves would be more complex than the code. In these cases, use a spike to explore the design, then delete the spike and write tests first for the real implementation.

## Detailed Explanation

### 1. Exploratory / Spike Code
When you genuinely don't know what shape the solution should take, writing tests upfront is premature. A **spike** is a time-boxed, throw-away experiment:

- Explore a third-party API
- Prototype a data transformation approach
- Evaluate a new library

**Rule**: After the spike, delete the code and restart with tests. Keeping spike code without tests is the trap.

### 2. Pure UI / Presentation Code
Pixel-perfect layout, animation, styling — TDD doesn't add value here. Use:
- Visual regression tools (Playwright, Applitools)
- Snapshot testing for component output
- Manual/exploratory testing

### 3. Trivial CRUD / Thin Adapters
A repository that maps `IEnumerable<T>` to a Dapper query with zero logic doesn't benefit from TDD. Test it with integration tests against a real (containerized) database.

### 4. Tests More Complex Than the Code
If the test setup requires 50 lines of scaffolding to test 5 lines of logic, either:
- The code has a design problem (too many dependencies)
- The test is testing at the wrong level (use integration/acceptance tests instead)

### 5. Legacy Code Without Seams
Adding TDD to a class that has no interfaces, static dependencies, and hardcoded `new` expressions requires seam creation first (see Michael Feathers' "Working Effectively with Legacy Code"). Going straight to TDD without seams produces tangled, fragile tests.

### When TDD Is Most Valuable

| Scenario | TDD Benefit |
|---|---|
| Core domain logic | ✅ Very high |
| Algorithm / calculation | ✅ Very high |
| Complex conditional logic | ✅ High |
| Application services | ✅ Good |
| Controller action methods | 🟡 Moderate (integration tests may be better) |
| Infrastructure (DB, HTTP) | 🟡 Low (integration tests more appropriate) |
| UI layout | ❌ Low — use visual regression |
| Spike / prototype | ❌ N/A — delete afterward |

### The "Spike Then TDD" Pattern
```
1. Time-box: "I'll spend 90 minutes exploring this API"
2. Write exploratory code without tests
3. Learn what the design should be
4. Delete all exploratory code
5. Start again with TDD using the knowledge gained
```

## Code Example
```csharp
// ❌ SPIKE — exploring Stripe SDK (delete this before committing)
var client = new StripeClient("sk_test_...");
var service = new ChargeService(client);
var charge = service.Create(new ChargeCreateOptions
{
    Amount = 2000,
    Currency = "usd",
    Source = "tok_visa",
});
Console.WriteLine(charge.Id); // just exploring the API

// ✅ AFTER SPIKE — proper TDD with abstraction
// Test first:
[Fact]
public async Task Charge_ValidCard_ReturnsChargeId()
{
    var paymentGateway = new Mock<IPaymentGateway>();
    paymentGateway.Setup(g => g.ChargeAsync(It.IsAny<ChargeRequest>(), default))
                  .ReturnsAsync(new ChargeResult { Id = "ch_test_1" });

    var sut = new OrderPaymentService(paymentGateway.Object);
    var result = await sut.ChargeAsync(new ChargeRequest { Amount = 20m });
    result.Id.Should().StartWith("ch_");
}
// Then implement OrderPaymentService + IPaymentGateway + StripePaymentGateway
```

## Common Follow-up Questions
- What is a "seam" in legacy code and how do you create one to enable testing?
- How do you decide when to write integration tests vs. unit tests with TDD?
- What is "test-after" and when is it an acceptable approach?
- How do you transition a spike to a production-quality TDD implementation?
- How do you apply TDD in a Blazor or MAUI UI project?

## Common Mistakes / Pitfalls
- **Keeping spike code** — exploratory code that ships without tests is technical debt from day one.
- **Treating "it's hard to test" as an exemption** — testability issues are design issues; fix the design.
- **Applying TDD to generated code** — EF scaffolding, T4 templates, gRPC stubs don't need TDD.
- **Abandoning TDD after one difficult session** — the first spike is always hard; it gets faster with practice.

## References
- [Martin Fowler — Spike Solution](https://martinfowler.com/bliki/SpikeAndStabilize.html)
- [Michael Feathers — Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/)
- [See also: tdd-red-green-refactor.md](tdd-red-green-refactor.md)
