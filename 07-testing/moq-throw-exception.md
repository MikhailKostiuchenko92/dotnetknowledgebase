# How Do You Set Up a Mock to Throw an Exception in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `Throws`, `ThrowsAsync`, `exception`, `error-handling`

## Question
> How do you set up a mock to throw an exception?

## Short Answer
Use `.Throws<TException>()` or `.Throws(new TException("msg"))` on a setup for synchronous methods. For async methods use `.ThrowsAsync<TException>()`. This lets you test that your SUT handles errors from its dependencies correctly.

## Detailed Explanation

### Synchronous Methods
```csharp
// Throw by type (new instance created automatically)
mock.Setup(r => r.FindById(It.IsAny<int>()))
    .Throws<KeyNotFoundException>();

// Throw a specific instance (custom message, inner exception, etc.)
mock.Setup(r => r.FindById(It.IsAny<int>()))
    .Throws(new KeyNotFoundException("Product not found in catalog"));
```

### Async Methods: `ThrowsAsync`
```csharp
mock.Setup(s => s.SaveAsync(It.IsAny<Order>()))
    .ThrowsAsync(new DbUpdateException("Constraint violation"));
```

> ⚠️ Do NOT use `.Throws(...)` for async methods — it throws *before* the `Task` is created, meaning the exception is not wrapped in a faulted task. The test may pass incorrectly or produce confusing errors.

### Throws After Specific Arguments
```csharp
mock.Setup(repo => repo.GetById(0))
    .Throws(new ArgumentException("ID must be > 0", "id"));

mock.Setup(repo => repo.GetById(It.Is<int>(n => n > 0)))
    .Returns(new Product());
```

### Conditional Throw with `Callback`
For complex scenarios where the throw depends on logic:
```csharp
mock.Setup(s => s.Process(It.IsAny<Request>()))
    .Callback<Request>(req =>
    {
        if (req.Amount < 0) throw new ArgumentException("Amount must be positive");
    })
    .Returns(ProcessResult.Ok);
```

### Throw on Second Call (Using `SetupSequence`)
```csharp
mock.SetupSequence(s => s.Connect())
    .Returns(true)       // first call succeeds
    .Throws<TimeoutException>(); // second call fails
```

### Re-throwing the Exception in the SUT
Test that the SUT doesn't swallow exceptions it shouldn't:
```csharp
var repo = new Mock<IProductRepository>();
repo.Setup(r => r.FindById(It.IsAny<int>()))
    .Throws<DatabaseException>();

var sut = new CatalogService(repo.Object);
var act = () => sut.GetProduct(1);

act.Should().Throw<DatabaseException>();
// Or: Assert.ThrowsAsync<DatabaseException>(() => sut.GetProductAsync(1))
```

Test that the SUT wraps exceptions:
```csharp
act.Should().Throw<CatalogException>()
    .WithInnerException<DatabaseException>();
```

## Code Example
```csharp
namespace ErrorHandling.Tests;

public class PaymentServiceTests
{
    private readonly Mock<IPaymentGateway> _gateway = new();
    private readonly PaymentService _sut;

    public PaymentServiceTests()
        => _sut = new PaymentService(_gateway.Object);

    // Test: gateway error propagates as domain exception
    [Fact]
    public async Task ProcessPayment_WhenGatewayUnavailable_ThrowsPaymentException()
    {
        _gateway.Setup(g => g.ChargeAsync(It.IsAny<decimal>()))
                .ThrowsAsync(new GatewayTimeoutException("gateway timed out"));

        var act = async () => await _sut.ProcessAsync(new PaymentRequest { Amount = 100m });

        await act.Should().ThrowAsync<PaymentException>()
                 .WithInnerException<GatewayTimeoutException>();
    }

    // Test: transient failure is retried (first throws, second succeeds)
    [Fact]
    public async Task ProcessPayment_WhenTransientFailure_RetriesAndSucceeds()
    {
        _gateway.SetupSequence(g => g.ChargeAsync(It.IsAny<decimal>()))
                .ThrowsAsync(new TransientGatewayException())
                .ReturnsAsync(ChargeResult.Success);

        var result = await _sut.ProcessAsync(new PaymentRequest { Amount = 50m });

        result.Should().Be(PaymentResult.Succeeded);
        _gateway.Verify(g => g.ChargeAsync(It.IsAny<decimal>()), Times.Exactly(2));
    }

    // Test: amount validation before calling gateway
    [Fact]
    public async Task ProcessPayment_WhenAmountIsZero_ThrowsArgumentException_WithoutCallingGateway()
    {
        var act = async () => await _sut.ProcessAsync(new PaymentRequest { Amount = 0m });

        await act.Should().ThrowAsync<ArgumentException>()
                 .WithParameterName("Amount");
        _gateway.Verify(g => g.ChargeAsync(It.IsAny<decimal>()), Times.Never);
    }
}
```

## Common Follow-up Questions
- What is the difference between `Throws` and `ThrowsAsync` in Moq?
- How do you test that the SUT wraps a dependency exception in a domain exception?
- How do you set up a mock to throw on the second call but succeed on the first?
- How do you test exception messages and inner exceptions with FluentAssertions?
- How do you test that an exception is NOT thrown when the SUT should handle it gracefully?
- Can you use `Callback` to conditionally throw based on argument values?

## Common Mistakes / Pitfalls
- **Using `Throws` instead of `ThrowsAsync` for async methods** — the exception is thrown before the task is created, not as a faulted task; the `await` never sees it.
- **Not testing the exception type** — just testing that *any* exception is thrown misses regression when the exception type changes.
- **Testing that the gateway throws without testing SUT behaviour** — the mock throw setup is the Arrange; the Assert should validate what the SUT *does* with the exception (propagates, wraps, logs, swallows).
- **Forgetting to verify that retry logic actually called the dependency twice** — add a `Verify(..., Times.Exactly(2))` to confirm the retry occurred.
- **Mocking exception constructors with `new TException()`** — if `TException` requires a specific message format, hardcode a representative message to make failures readable.

## References
- [Moq documentation — Throwing exceptions](https://github.com/devlooped/moq/wiki/Quickstart#throwing-exceptions)
- [FluentAssertions — Exception assertions](https://fluentassertions.com/exceptions/)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
- [Microsoft Learn — Unit testing with Moq](https://learn.microsoft.com/en-us/dotnet/core/testing/)
