# How Do You Verify a Method Was Called Using `Verify` in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `Verify`, `Times`, `VerifyAll`, `VerifyNoOtherCalls`, `interaction-testing`

## Question
> How do you verify a method was called using `Verify` in Moq?

## Short Answer
Call `mock.Verify(x => x.Method(args), Times.Once)` after the system under test runs. `Times` specifies the expected call count. `VerifyAll()` checks all setups were called; `VerifyNoOtherCalls()` ensures no unexpected calls happened.

## Detailed Explanation

### Basic `Verify`
```csharp
mock.Verify(x => x.Send(It.IsAny<Email>()), Times.Once);
```
If `Send` was not called exactly once, Moq throws `MockException` with a detailed message.

### `Times` Options

| Expression | Meaning |
|---|---|
| `Times.Once` | Called exactly once |
| `Times.Never` | Never called |
| `Times.AtLeastOnce` | Called one or more times |
| `Times.AtMostOnce` | Called zero or one times |
| `Times.Exactly(n)` | Called exactly n times |
| `Times.AtLeast(n)` | Called n or more times |
| `Times.AtMost(n)` | Called at most n times |
| `Times.Between(min, max, RangeKind.Inclusive)` | Called between min and max times |

### Argument Matching in `Verify`
You can verify with specific values or matchers:
```csharp
// Specific value
mock.Verify(e => e.Send(new Email { To = "user@test.com" }), Times.Once);

// Any argument
mock.Verify(e => e.Send(It.IsAny<Email>()), Times.Once);

// Predicate matcher — most precise
mock.Verify(
    e => e.Send(It.Is<Email>(m => m.To == "user@test.com" && m.Subject.Contains("Confirm"))),
    Times.Once);
```

### `VerifyAll()`
Verifies that **all setups on the mock were called at least once**. Useful to catch setups that were added but the SUT never triggered.

```csharp
var repo = new Mock<IOrderRepository>();
repo.Setup(r => r.Save(It.IsAny<Order>()));

sut.PlaceOrder(order);

repo.VerifyAll(); // throws if Save was never called
```

### `VerifyNoOtherCalls()`
Verifies that **no calls were made** to the mock other than those explicitly verified. Use with caution — it creates very strict tests that break on adding new behaviour.

```csharp
mock.Verify(e => e.Send(It.IsAny<Email>()), Times.Once);
mock.VerifyNoOtherCalls(); // throws if any other method was called
```

### `Verifiable()` + `VerifyAll()`
Mark individual setups as expected calls:
```csharp
repo.Setup(r => r.Save(It.IsAny<Order>())).Verifiable();
// ... test runs ...
repo.VerifyAll(); // only checks setups marked Verifiable()
```

### Failure Messages
Moq provides detailed failure output:
```
Expected invocation on the mock once, but was 0 times:
  e => e.Send(It.Is<Email>(m => m.To == "user@test.com"))
```

> ⚠️ **Warning:** Avoid verifying *every* interaction on every mock. Over-verification creates brittle tests that break when you add logging, caching, or other internal calls. Only verify interactions that are **the purpose of the test**.

## Code Example
```csharp
namespace Notifications.Tests;

public class NotificationServiceTests
{
    [Fact]
    public void Notify_WhenOrderShipped_SendsShippingEmail()
    {
        var emailSender = new Mock<IEmailSender>();
        var logger = Mock.Of<ILogger<NotificationService>>();
        var sut = new NotificationService(emailSender.Object, logger);

        sut.Notify(NotificationEvent.OrderShipped, new Order
        {
            Id = 1,
            CustomerEmail = "bob@example.com"
        });

        // Verify exact interaction
        emailSender.Verify(
            e => e.Send(It.Is<Email>(m =>
                m.To == "bob@example.com" &&
                m.Subject == "Your order has shipped")),
            Times.Once);
    }

    [Fact]
    public void Notify_WhenOrderCancelled_NeverSendsShippingEmail()
    {
        var emailSender = new Mock<IEmailSender>();
        var sut = new NotificationService(emailSender.Object, Mock.Of<ILogger<NotificationService>>());

        sut.Notify(NotificationEvent.OrderCancelled, new Order { Id = 2, CustomerEmail = "x@y.com" });

        // Verify shipping email was NOT sent
        emailSender.Verify(
            e => e.Send(It.Is<Email>(m => m.Subject.Contains("shipped"))),
            Times.Never);
    }

    [Fact]
    public void Notify_SendsExactlyOneEmail_PerEvent()
    {
        var emailSender = new Mock<IEmailSender>();
        var sut = new NotificationService(emailSender.Object, Mock.Of<ILogger<NotificationService>>());

        sut.Notify(NotificationEvent.OrderShipped, new Order { CustomerEmail = "a@b.com" });

        // Verify total count
        emailSender.Verify(e => e.Send(It.IsAny<Email>()), Times.Exactly(1));
    }
}
```

## Common Follow-up Questions
- What is the difference between `VerifyAll()` and calling `Verify()` on individual methods?
- When should you use `VerifyNoOtherCalls()` vs. not using it?
- What is `MockBehavior.Strict` and how does it relate to verification?
- How do you verify a method was called with any argument vs. a specific argument?
- How do you capture the argument passed to a verified call?
- What happens if `Verify` is called on a method that was never set up?

## Common Mistakes / Pitfalls
- **Over-verifying** — calling `Verify` on every mock call, not just the purpose of the test; creates brittle, maintenance-heavy tests.
- **Forgetting the `Times` argument** — `mock.Verify(...)` without `Times` defaults to `Times.AtLeastOnce`, not `Times.Once`; be explicit.
- **Verifying setup calls that are stub-only** — if a method is a stub (returns data), you shouldn't need to verify it; if you do, question whether the test is over-specified.
- **Mixing `VerifyAll()` and `Verify()` carelessly** — `VerifyAll` checks all setups; individual `Verify` checks can be more targeted.
- **Not verifying async method completion** — `Verify(e => e.SendAsync(...))` must use the async form of the method; it checks that the call was made, not that the task completed.

## References
- [Moq documentation — Verify](https://github.com/devlooped/moq/wiki/Quickstart#verification)
- [Moq GitHub — Times class source](https://github.com/devlooped/moq/blob/main/src/Moq/Times.cs)
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Vladimir Khorikov — When to use Verify in Moq](https://enterprisecraftsmanship.com/posts/state-vs-interaction-based-unit-testing/)
