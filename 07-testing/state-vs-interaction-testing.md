# What Is the Difference Between State-Based and Interaction-Based Testing?

**Category:** Testing / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `state-based-testing`, `interaction-based-testing`, `mocking`, `test-doubles`, `test-style`

## Question
> What is the difference between state-based and interaction-based testing?

## Short Answer
State-based testing asserts on the *observable state* after the act — return values, property values, or database contents. Interaction-based testing asserts on *how the system under test communicates with its collaborators* — which methods were called, how many times, and with what arguments.

## Detailed Explanation

### State-Based Testing (Classical / Detroit School)
You call the method under test and then inspect *what changed*. No mock framework is needed for the assertion itself.

- Assert on return values
- Assert on object properties after the call
- Assert on data in an in-memory repository or database

**When to use it:**
- Whenever the outcome is an observable value or state change.
- Preferred whenever possible — state assertions are more resilient to refactoring.

```csharp
// State-based: we check the cart's total, not how it was computed
cart.AddItem(new Item("SKU-1", Price: 25m));
cart.Total.Should().Be(25m);
```

### Interaction-Based Testing (London School / Mockist)
You configure a mock before the call and then *verify* that the mock received specific messages.

- `mock.Verify(m => m.Send(It.IsAny<Email>()), Times.Once)`
- Asserts on the *side effect* of calling an external service, not on state

**When to use it:**
- When the SUT's primary outcome is a side effect — sending an email, logging an audit event, publishing a message.
- When you cannot observe state directly (fire-and-forget operations, external services).

```csharp
// Interaction-based: we verify the email sender was called
emailSender.Verify(s => s.Send(It.Is<Email>(e => e.To == "user@example.com")), Times.Once);
```

### Comparison Table

| Dimension | State-Based | Interaction-Based |
|---|---|---|
| What is asserted | Return value / object state | Collaborator calls |
| Coupling to internals | Low | High (coupled to implementation) |
| Refactoring safety | High | Lower |
| Mocking needed? | No (or minimal) | Yes |
| Best for | Pure logic, repositories | Side effects (email, events, logs) |

### The London vs. Chicago Debate
- **London/Mockist** style: mock every collaborator, verify interactions. Leads to very isolated but implementation-coupled tests.
- **Chicago/Classical** style: use real objects where possible, only replace I/O. Leads to more robust, less brittle tests.

Vladimir Khorikov argues strongly for preferring state-based tests and using interaction-based tests *only* for unmanaged dependencies (outgoing messages to external systems that you cannot observe otherwise).

> ⚠️ **Warning:** Overusing interaction-based testing creates tests that break whenever you refactor internals — even when behaviour is unchanged. If you find yourself verifying every internal call, reconsider whether the test is testing behaviour or implementation.

### Practical Rule
Use **state-based** by default. Switch to **interaction-based** only when:
1. The outcome is a fire-and-forget side effect (email, event bus, audit log).
2. There is no feasible way to observe the state result.

## Code Example
```csharp
namespace Notifications.Tests;

public class OrderConfirmationServiceTests
{
    // ✅ State-based: assert on returned confirmation number
    [Fact]
    public void Confirm_ReturnsNonEmptyConfirmationNumber()
    {
        var repo = new InMemoryOrderRepository();
        var sut = new OrderConfirmationService(repo, Mock.Of<IEmailSender>());

        string confirmation = sut.Confirm(orderId: 42);

        confirmation.Should().NotBeNullOrEmpty();
    }

    // ✅ Interaction-based: the email send is an un-observable side-effect
    [Fact]
    public void Confirm_SendsConfirmationEmailToCustomer()
    {
        var emailSender = new Mock<IEmailSender>();
        var repo = new InMemoryOrderRepository();
        repo.Add(new Order { Id = 42, CustomerEmail = "alice@example.com" });

        var sut = new OrderConfirmationService(repo, emailSender.Object);
        sut.Confirm(orderId: 42);

        emailSender.Verify(
            s => s.Send(It.Is<Email>(e => e.To == "alice@example.com")),
            Times.Once);
    }

    // ❌ Over-specified interaction test — breaks on any internal refactoring
    [Fact]
    public void Confirm_BadExample_VerifiesInternalCalls()
    {
        var repo = new Mock<IOrderRepository>();
        repo.Setup(r => r.GetById(42)).Returns(new Order { Id = 42 });
        var sut = new OrderConfirmationService(repo.Object, Mock.Of<IEmailSender>());

        sut.Confirm(42);

        // Brittle: breaks if you rename GetById or add caching
        repo.Verify(r => r.GetById(42), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the London School vs. Chicago School of TDD?
- When is it wrong to use mocks in tests?
- How do you test a method whose only outcome is publishing a domain event?
- What is an "over-specified test" and why is it dangerous?
- How does choosing state-based vs. interaction-based testing affect test maintainability?
- What is the difference between a spy and a mock in this context?

## Common Mistakes / Pitfalls
- **Verifying every call to every collaborator** — couples tests to implementation, breaks on any refactoring.
- **Using state-based assertions on mocks** — reading the mock's state (`mock.Object.SomeProperty`) rather than asserting on a real result.
- **Missing interaction assertions on genuinely observable-only side effects** — e.g., not verifying that the audit log was written.
- **Mixing both styles in one test** — asserting state AND verifying interactions for the same logical outcome; pick one.
- **Forgetting `Times.Once` vs `Times.AtLeastOnce`** — verifying `Times.AtLeastOnce` on a side effect that must happen exactly once masks duplicate sends.

## References
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Vladimir Khorikov — State-based vs interaction-based testing](https://enterprisecraftsmanship.com/posts/state-vs-interaction-based-unit-testing/)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
- [Moq documentation](https://github.com/devlooped/moq/wiki/Quickstart)
