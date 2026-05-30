# What Is the Difference Between a Stub and a Mock?

**Category:** Testing / Mocking
**Difficulty:** 🟢 Junior
**Tags:** `stub`, `mock`, `test-doubles`, `interaction-testing`, `state-based-testing`

## Question
> What is the difference between a stub and a mock?

## Short Answer
A stub provides **indirect inputs** to the system under test — you set it up to return canned values, then assert on the SUT's observable output. A mock verifies **indirect outputs** — you set expectations on how it should be called, then verify those expectations after the SUT runs. Stubs are used in state-based testing; mocks are used in interaction-based testing.

## Detailed Explanation

### The Core Distinction (Martin Fowler)
Fowler's rule: **"Mocks verify behaviour; stubs don't."**

| Aspect | Stub | Mock |
|---|---|---|
| Purpose | Feed inputs into the SUT | Verify interactions of the SUT |
| What you assert on | The SUT's return value / state | The double itself (call count, args) |
| Assertion timing | After SUT call | After SUT call (`Verify`) |
| Failure when unused | Never fails | Fails if expectations not met (Strict) |

### Stub — Indirect Input
A stub is set up to return specific data so the SUT can proceed. The test then asserts on the SUT's result, *not* on the stub.

```csharp
// Stub — we care about what the SUT RETURNS, not about the repo call
var repo = new Mock<IProductRepository>();
repo.Setup(r => r.FindById(1)).Returns(new Product { Price = 50m });

var sut = new PricingService(repo.Object);
decimal price = sut.GetDiscountedPrice(productId: 1, discount: 0.1m);

// Assert on the SUT's output — not on repo
price.Should().Be(45m);
```

### Mock — Indirect Output (Verification)
A mock is used to verify that the SUT called a dependency correctly. The test asserts on the mock's interaction record.

```csharp
// Mock — we care that the SUT CALLED the email service correctly
var emailSender = new Mock<IEmailSender>();

var sut = new OrderService(emailSender.Object);
sut.PlaceOrder(new Order { CustomerEmail = "alice@example.com", Total = 100m });

// Assert on the mock itself
emailSender.Verify(
    e => e.Send(It.Is<Email>(m => m.To == "alice@example.com")),
    Times.Once);
```

### The Same Moq Object Can Be Both
In Moq, one `Mock<T>` object can be used as a stub (via `Setup`) *and* a mock (via `Verify`). The terminology describes how you use it in a specific test, not a property of the object.

```csharp
var gateway = new Mock<IPaymentGateway>();
// Used as a stub: return value drives SUT state
gateway.Setup(g => g.Charge(It.IsAny<decimal>())).Returns(ChargeResult.Success);

sut.ProcessPayment(order);

// Same object used as a mock: verify the SUT interacted correctly
gateway.Verify(g => g.Charge(100m), Times.Once);
```

> ⚠️ **Warning:** Combining stub and mock roles in one test can lead to over-specified tests. If you're both stubbing *and* verifying the same call, ask whether the verification adds value or just duplicates the state-based assertion.

### When to Prefer Each
| Use | Prefer |
|---|---|
| Driving the SUT into a state | Stub |
| Verifying a side effect (email sent, event published) | Mock |
| Testing a value returned by the SUT | Stub |
| Testing that an external system was called correctly | Mock |
| Both drive state and verify side effect | Both (but keep tests focused) |

## Code Example
```csharp
namespace Billing.Tests;

public class InvoiceServiceTests
{
    // ── Stub example ──────────────────────────────────────────────────────────
    [Fact]
    public void Generate_SetsCorrectDueDate()
    {
        // Stub: provides the current date so the SUT can compute due date
        var timeProvider = new Mock<ITimeProvider>();
        timeProvider.Setup(t => t.UtcNow).Returns(new DateTime(2025, 1, 1));

        var sut = new InvoiceService(timeProvider.Object);
        var invoice = sut.Generate(customerId: 1, amount: 500m);

        // Assert on the SUT's output, not on the stub
        invoice.DueDate.Should().Be(new DateTime(2025, 1, 31));
    }

    // ── Mock example ──────────────────────────────────────────────────────────
    [Fact]
    public void Generate_SendsInvoiceByEmail()
    {
        // We don't care about the date here — stub it with any value
        var timeProvider = new Mock<ITimeProvider>();
        timeProvider.Setup(t => t.UtcNow).Returns(DateTime.UtcNow);

        // Mock: we want to verify the email was sent
        var emailSender = new Mock<IEmailSender>();

        var sut = new InvoiceService(timeProvider.Object, emailSender.Object);
        sut.Generate(customerId: 1, amount: 500m);

        // Assert on the mock
        emailSender.Verify(
            e => e.Send(It.Is<Email>(m => m.Subject.Contains("Invoice"))),
            Times.Once);
    }
}
```

## Common Follow-up Questions
- What is a spy and how does it differ from a mock?
- What is state-based vs. interaction-based testing?
- When does using a mock make a test fragile?
- What is `MockBehavior.Strict` and how does it relate to the mock/stub distinction?
- How do you decide whether to use a stub or a mock for a given dependency?
- What is the "London School" vs. "Chicago School" of TDD?

## Common Mistakes / Pitfalls
- **Verifying every stub call** — turning all stubs into mocks creates brittle tests that break on any internal refactoring.
- **Using "mock" to mean any test double** — blurs the distinction; try to say "stub" when you mean "provides data".
- **Asserting on stub return values** — you configured the return value, so asserting on it proves nothing about the SUT.
- **Using a mock when a fake is more appropriate** — a `FakeOrderRepository` with real add/find logic is often simpler than chaining `Setup` calls.
- **Forgetting that un-set-up calls on a Loose mock return default** — `null` for reference types, `0` for numerics; this can mask bugs where the SUT uses a dependency you didn't configure.

## References
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Gerard Meszaros — xUnit Test Patterns: Stub & Mock](http://xunitpatterns.com/Test%20Double.html)
- [Vladimir Khorikov — State-based vs interaction-based testing](https://enterprisecraftsmanship.com/posts/state-vs-interaction-based-unit-testing/)
- [Moq documentation — Quickstart](https://github.com/devlooped/moq/wiki/Quickstart)
