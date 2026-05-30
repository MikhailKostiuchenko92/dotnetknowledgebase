# How Do You Assert on Async Methods That Throw with FluentAssertions?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🟡 Middle
**Tags:** `FluentAssertions`, `ThrowAsync`, `async`, `Task`, `exceptions`

## Question
> How do you assert on async methods that throw with FluentAssertions?

## Short Answer
Capture the async operation in a `Func<Task>` and use `await act.Should().ThrowAsync<TException>()`. You must `await` the assertion call — the method returns a `Task` that performs the assertion asynchronously. Forgetting the `await` silently skips the assertion.

## Detailed Explanation

### Basic Pattern
```csharp
// Always: Func<Task>, not Action
Func<Task> act = async () => await sut.DeleteAsync(orderId: 0);

// Always: await the assertion
await act.Should().ThrowAsync<ArgumentException>();
```

### Chaining Message / Inner Exception Checks
```csharp
await act.Should().ThrowAsync<OrderNotFoundException>()
         .WithMessage("Order * not found")
         .WithInnerException<DbException>();
```

### Asserting Custom Exception Properties with `.Which`
```csharp
var assertion = await act.Should().ThrowAsync<ApiException>();
assertion.Which.StatusCode.Should().Be(HttpStatusCode.NotFound);
assertion.Which.RequestId.Should().NotBeNullOrEmpty();
```

### `NotThrowAsync`
```csharp
Func<Task> act = async () => await sut.ProcessAsync(validOrder);
await act.Should().NotThrowAsync();
```

### Common Pitfall: Missing `await`
```csharp
// ❌ The assertion task is created but never awaited — test always passes!
act.Should().ThrowAsync<Exception>(); // bug: no await

// ✅ Correct
await act.Should().ThrowAsync<Exception>();
```

### Comparison: xUnit vs FluentAssertions for Async Exceptions

| Pattern | xUnit | FluentAssertions |
|---|---|---|
| Assert async throw | `await Assert.ThrowsAsync<T>(act)` | `await act.Should().ThrowAsync<T>()` |
| Message check | `ex.Message.Should().Contain(...)` (manual) | `.WithMessage(...)` (chained) |
| Inner exception | `ex.InnerException.Should().BeOfType<T>()` | `.WithInnerException<T>()` |
| Custom properties | `var ex = await ...; ex.Prop.Should()...` | `.Which.Prop.Should()...` |

### `CancellationToken` and `OperationCanceledException`
```csharp
using var cts = new CancellationTokenSource();
cts.Cancel();

Func<Task> act = async () => await sut.FetchAsync(cts.Token);
await act.Should().ThrowAsync<OperationCanceledException>();
```

## Code Example
```csharp
namespace AsyncExceptions.Tests;

public class OrderServiceAsyncTests
{
    private readonly Mock<IOrderRepository> _repo = new();
    private readonly OrderService _sut;

    public OrderServiceAsyncTests()
        => _sut = new OrderService(_repo.Object);

    [Fact]
    public async Task DeleteAsync_InvalidId_ThrowsArgumentException()
    {
        Func<Task> act = async () => await _sut.DeleteAsync(orderId: -1);

        await act.Should().ThrowAsync<ArgumentException>()
                 .WithMessage("*must be positive*")
                 .WithParameterName("orderId");
    }

    [Fact]
    public async Task DeleteAsync_NotFound_ThrowsOrderNotFoundException()
    {
        _repo.Setup(r => r.GetByIdAsync(99)).ReturnsAsync((Order?)null);

        Func<Task> act = async () => await _sut.DeleteAsync(orderId: 99);

        var result = await act.Should().ThrowAsync<OrderNotFoundException>();
        result.Which.OrderId.Should().Be(99);
    }

    [Fact]
    public async Task DeleteAsync_DbFailure_ThrowsDomainExceptionWithInnerDbException()
    {
        _repo.Setup(r => r.GetByIdAsync(It.IsAny<int>()))
             .ThrowsAsync(new DbException("connection lost"));

        Func<Task> act = async () => await _sut.DeleteAsync(1);

        await act.Should().ThrowAsync<DomainException>()
                 .WithInnerException<DbException>();
    }

    [Fact]
    public async Task DeleteAsync_ValidId_DoesNotThrow()
    {
        _repo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(new Order { Id = 1 });

        Func<Task> act = async () => await _sut.DeleteAsync(1);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DeleteAsync_CancelledToken_ThrowsOperationCancelledException()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        Func<Task> act = async () => await _sut.DeleteAsync(1, cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
```

## Common Follow-up Questions
- Why must you `await` the `ThrowAsync` assertion?
- What is the difference between `ThrowAsync` and `Throw` in FluentAssertions?
- How do you assert custom exception properties on an async exception?
- Can you use `ThrowAsync` with `ValueTask`-returning methods?
- How does `NotThrowAsync` differ from not writing an exception assertion at all?
- What happens if the exception is thrown synchronously in a `Task`-returning method?

## Common Mistakes / Pitfalls
- **Forgetting `await`** — the test passes silently even if the exception was not thrown; always `await act.Should().ThrowAsync<T>()`.
- **Using `Action` instead of `Func<Task>`** — `Action act = async () => await ...` discards the task; the exception becomes unobserved.
- **Using `Throw` (sync) for async methods** — `Throw` only catches synchronous exceptions before the first `await`; use `ThrowAsync` to capture faulted task exceptions.
- **Asserting on a non-awaited lambda** — calling `act.Should().ThrowAsync<T>()` without awaiting creates the assertion but the test framework never observes the result.
- **Not testing `CancellationToken` propagation** — async methods should check `cts.IsCancellationRequested` and throw `OperationCanceledException`; test this path explicitly.

## References
- [FluentAssertions — Exceptions (async)](https://fluentassertions.com/exceptions/)
- [FluentAssertions on GitHub](https://github.com/fluentassertions/fluentassertions)
- [NuGet — FluentAssertions](https://www.nuget.org/packages/FluentAssertions/)
