# How Do You Assert on Exceptions with FluentAssertions?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🟡 Middle
**Tags:** `FluentAssertions`, `exceptions`, `Throw`, `ThrowAsync`, `WithMessage`

## Question
> How do you assert on exceptions with FluentAssertions?

## Short Answer
Wrap the call in an `Action` or `Func<Task>` and use `.Should().Throw<TException>()` for synchronous code and `.Should().ThrowAsync<TException>()` for async. You can chain `.WithMessage()`, `.WithParameterName()`, and `.WithInnerException<T>()` to make assertions precise without a try/catch block.

## Detailed Explanation

### Synchronous Exception Assertions
```csharp
Action act = () => sut.Process(-1);

act.Should().Throw<ArgumentException>();

// Assert specific message (wildcard * supported)
act.Should().Throw<ArgumentException>()
   .WithMessage("*must be positive*");

// Assert parameter name (for ArgumentException)
act.Should().Throw<ArgumentException>()
   .WithParameterName("amount");

// Full chain
act.Should().Throw<ArgumentException>()
   .WithMessage("Amount must be positive")
   .And.ParamName.Should().Be("amount");
```

### Async Exception Assertions
```csharp
Func<Task> act = async () => await sut.ProcessAsync(-1);

await act.Should().ThrowAsync<ArgumentException>();
await act.Should().ThrowAsync<ArgumentException>()
         .WithMessage("*positive*");
```

> ⚠️ For async methods you MUST use `ThrowAsync` and `await` the assertion. Using `Throw` on a `Func<Task>` will only check that the task was returned, not that it faulted.

### Inner Exceptions
```csharp
act.Should().Throw<DomainException>()
   .WithInnerException<DbException>()
   .WithMessage("*connection refused*");
```

### Not Throwing
```csharp
act.Should().NotThrow();
await act.Should().NotThrowAsync();
```

### Capturing the Exception for Further Assertions
```csharp
var exception = act.Should().Throw<OrderException>().Which;
exception.OrderId.Should().Be(42);
exception.FailureReason.Should().Contain("invalid state");
```

`.Which` returns the exception itself for custom property assertions beyond what the built-in methods offer.

### Comparison: xUnit vs FluentAssertions

| Pattern | xUnit | FluentAssertions |
|---|---|---|
| Assert throws | `Assert.Throws<T>(act)` | `act.Should().Throw<T>()` |
| Async throws | `await Assert.ThrowsAsync<T>(act)` | `await act.Should().ThrowAsync<T>()` |
| Message check | Manual: `ex.Message.Contains(...)` | `.WithMessage("*pattern*")` |
| Inner exception | Manual | `.WithInnerException<T>()` |
| Custom properties | Manual | `.Which.PropertyName.Should()...` |

## Code Example
```csharp
namespace ExceptionAssertions.Tests;

public class PaymentServiceExceptionTests
{
    private readonly PaymentService _sut = new(new FakeGateway());

    [Fact]
    public void Charge_NegativeAmount_ThrowsArgumentException()
    {
        Action act = () => _sut.Charge(-50m);

        act.Should().Throw<ArgumentException>()
           .WithMessage("*must be positive*")
           .WithParameterName("amount");
    }

    [Fact]
    public async Task ChargeAsync_GatewayFailure_ThrowsPaymentException()
    {
        Func<Task> act = async () => await _sut.ChargeAsync(100m);

        await act.Should().ThrowAsync<PaymentException>()
                 .WithInnerException<GatewayTimeoutException>();
    }

    [Fact]
    public void Charge_ValidAmount_DoesNotThrow()
    {
        Action act = () => _sut.Charge(100m);

        act.Should().NotThrow();
    }

    [Fact]
    public void Charge_Unauthorized_ExceptionContainsOrderId()
    {
        Action act = () => _sut.Charge(999m, orderId: 42);

        var exception = act.Should().Throw<UnauthorizedPaymentException>().Which;
        exception.OrderId.Should().Be(42);
        exception.Reason.Should().Be("insufficient funds");
    }
}
```

## Common Follow-up Questions
- What is `.Which` in FluentAssertions exception assertions?
- Why must you `await` `ThrowAsync` assertions?
- How do you assert on a specific exception message with a wildcard?
- How do you assert on inner exceptions with FluentAssertions?
- Can you use FluentAssertions to assert a specific derived exception type?
- How does FluentAssertions exception assertion compare to `Assert.Throws<T>` in xUnit?

## Common Mistakes / Pitfalls
- **Using `Throw` (sync) for async methods** — the lambda returns a `Task`; the exception is inside the task, not thrown synchronously.
- **Forgetting `await` on `ThrowAsync`** — without `await`, the assertion runs but the result `Task` is ignored; no assertion failure occurs if the exception is missing.
- **Asserting message with exact string instead of wildcard** — exception messages often contain variable data; use `*` wildcard patterns.
- **Not using `.Which` for custom properties** — built-in matchers don't cover every exception property; `.Which` is the escape hatch for custom exception fields.
- **Asserting `Throw` on `Action` that swallows exceptions** — if the SUT catches and suppresses an exception, `NotThrow` passes but the behavior is wrong; assert on observable side effects too.

## References
- [FluentAssertions — Exceptions](https://fluentassertions.com/exceptions/)
- [FluentAssertions on GitHub](https://github.com/fluentassertions/fluentassertions)
- [NuGet — FluentAssertions](https://www.nuget.org/packages/FluentAssertions/)
