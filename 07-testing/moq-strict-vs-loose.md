# What Is `MockBehavior.Strict` vs `MockBehavior.Loose` in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `MockBehavior`, `Strict`, `Loose`, `mock-configuration`

## Question
> What is `MockBehavior.Strict` vs `MockBehavior.Loose` in Moq?

## Short Answer
`MockBehavior.Loose` (the default) returns default values for any un-configured method call. `MockBehavior.Strict` throws `MockException` for any call that was not explicitly set up. Strict mocks catch unexpected interactions but require more setup; Loose mocks are easier to write but may silently hide missing setup.

## Detailed Explanation

### `MockBehavior.Loose` (Default)
```csharp
var mock = new Mock<IEmailSender>();               // Loose by default
var mock2 = new Mock<IEmailSender>(MockBehavior.Loose);
```
Any call to a member that was not set up:
- Returns `default(T)` for value types (`0`, `false`, `Guid.Empty`)
- Returns `null` for reference types
- Returns `Task.CompletedTask` / `Task.FromResult(default)` for async methods
- Returns empty collections for `IEnumerable` return types

**Benefit:** Less setup boilerplate — only configure what you care about.  
**Risk:** If the SUT calls a method you forgot to configure, it silently receives `null`/`0`/`false`, potentially causing the test to pass when it shouldn't.

### `MockBehavior.Strict`
```csharp
var mock = new Mock<IEmailSender>(MockBehavior.Strict);
```
Any call to a member that was not set up throws:
```
MockException: IEmailSender.Send(email) invocation failed with strict mock behavior.
All invocations on the mock must have a corresponding setup.
```

**Benefit:** Forces you to be explicit about all dependencies the SUT uses — catches forgotten setups immediately.  
**Risk:** More verbose; any new call the SUT makes (even an innocent log call) breaks all Strict mocks that don't set it up.

### Comparison Table

| Dimension | Loose | Strict |
|---|---|---|
| Un-set-up calls | Return default values | Throw `MockException` |
| Setup verbosity | Low | High |
| Catches missing setup | No | Yes |
| Fragility on refactoring | Low | High |
| Best for | Most unit tests | Security-critical paths, or when over-mocking is intentional |

### Recommended Practice
Most teams use **Loose** as the default and verify only the interactions that are the *purpose* of the test. This avoids the maintenance overhead of Strict.

Use **Strict** when:
- You want to detect if the SUT starts calling a collaborator it shouldn't.
- You're auditing a security or audit-log path where unexpected calls are a bug.
- You prefer explicit contracts and are willing to maintain the extra setup.

> ⚠️ **Warning:** `MockBehavior.Strict` combined with `VerifyNoOtherCalls()` is the most brittle configuration possible. Every new line of production code that adds a log call, a metrics call, or a cache check will break dozens of tests.

### The `Verifiable()` Approach (Middle Ground)
Instead of Strict, mark specific setups as verifiable and call `mock.VerifyAll()`:
```csharp
var mock = new Mock<IOrderRepository>();                // Loose
mock.Setup(r => r.Save(It.IsAny<Order>())).Verifiable(); // mark as expected
// ...
mock.VerifyAll(); // only checks Verifiable setups — not ALL calls
```
This gives the "must be called" guarantee of Strict without requiring setup for every possible call.

## Code Example
```csharp
namespace Payments.Tests;

public class PaymentGatewayBehaviorTests
{
    [Fact]
    public void Loose_UnconfiguredCallReturnsDefault()
    {
        var gateway = new Mock<IPaymentGateway>(); // Loose

        // gateway.Charge is not set up — returns false (default bool)
        bool result = gateway.Object.Charge(100m); // false, no exception

        result.Should().Be(false); // default bool
    }

    [Fact]
    public void Strict_UnconfiguredCallThrows()
    {
        var gateway = new Mock<IPaymentGateway>(MockBehavior.Strict);

        // Nothing is set up — any call throws
        var act = () => gateway.Object.Charge(100m);

        act.Should().Throw<MockException>()
            .WithMessage("*strict mock*");
    }

    [Fact]
    public void Strict_WithSetup_WorksNormally()
    {
        var gateway = new Mock<IPaymentGateway>(MockBehavior.Strict);

        // Explicit setup required for every call the SUT makes
        gateway.Setup(g => g.Charge(It.IsAny<decimal>())).Returns(true);
        gateway.Setup(g => g.GetTransactionId()).Returns("TXN-001");

        var sut = new CheckoutService(gateway.Object);
        var result = sut.ProcessPayment(new Cart { Total = 99m });

        result.TransactionId.Should().Be("TXN-001");
    }

    [Fact]
    public void Verifiable_MiddleGroundApproach()
    {
        var repo = new Mock<IOrderRepository>(); // Loose
        repo.Setup(r => r.Save(It.IsAny<Order>())).Verifiable(); // must be called

        var sut = new OrderService(repo.Object);
        sut.PlaceOrder(new Order { Total = 50m });

        repo.VerifyAll(); // verifies only Verifiable setups
    }
}
```

## Common Follow-up Questions
- What is the default `MockBehavior` in Moq?
- How does `MockBehavior.Strict` interact with `VerifyNoOtherCalls()`?
- When would you choose Strict over Loose in a large codebase?
- What is `Verifiable()` and how does it compare to Strict?
- How do you globally configure `MockBehavior` for all mocks in a test class?
- Is there a `MockBehavior.Default` and what does it map to?

## Common Mistakes / Pitfalls
- **Setting all mocks to Strict** — every refactoring that changes internal calls (e.g., adding a log) breaks tests; prefer Loose with targeted `Verify`.
- **Relying on Loose's `null` return to detect missing setup** — a `NullReferenceException` deep in the SUT is harder to diagnose than a clear `MockException` from Strict.
- **`MockBehavior.Strict` with a Logger mock** — logging interfaces have many methods; a strict Logger mock requires setup for every `IsEnabled` / `Log` overload the framework calls.
- **Forgetting `MockBehavior.Default` is `Loose`** — passing `MockBehavior.Default` is the same as not passing it; it's not a third, different mode.
- **Using Strict to avoid writing `Verify`** — Strict verifies that configured methods were called only in `MockBehavior.Strict` mode with `VerifyAll`; for interaction verification, Strict alone is not enough.

## References
- [Moq documentation — MockBehavior](https://github.com/devlooped/moq/wiki/Quickstart#mock-behaviors)
- [Moq GitHub — MockBehavior enum source](https://github.com/devlooped/moq/blob/main/src/Moq/MockBehavior.cs)
- [Vladimir Khorikov — When to use strict mock behavior](https://enterprisecraftsmanship.com/posts/strict-mock-behavior/)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
