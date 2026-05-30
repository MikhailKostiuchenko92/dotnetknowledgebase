# How Do You Write an Async Unit Test in xUnit/NUnit?

**Category:** Testing / Async Code
**Difficulty:** 🟢 Junior
**Tags:** `async`, `await`, `Task`, `xUnit`, `NUnit`, `unit-testing`

## Question
> How do you write an async unit test in xUnit/NUnit?

## Short Answer
Mark the test method `async Task` (not `async void`) and use `await` normally inside it. The testing framework natively supports `Task`-returning test methods and will correctly observe exceptions thrown from awaited operations.

## Detailed Explanation

### The Basic Pattern
All three major .NET test frameworks — xUnit, NUnit, MSTest — support `async Task` test methods natively. The runner awaits the returned `Task` and reports failures correctly:

```csharp
// xUnit
[Fact]
public async Task GetProduct_ReturnsExpected() { ... }

// NUnit
[Test]
public async Task GetProduct_ReturnsExpected() { ... }

// MSTest
[TestMethod]
public async Task GetProduct_ReturnsExpected() { ... }
```

### What Happens Under the Hood
The test runner calls the method, receives a `Task`, and `await`s it. Any exception that propagates through the `Task` is unwrapped and reported as a test failure. This mirrors how `async` works in production code.

### Asserting on Async Exceptions
Use the assertion library helpers; do NOT use `try/catch`:

```csharp
// FluentAssertions
var act = async () => await sut.ProcessAsync(null);
await act.Should().ThrowAsync<ArgumentNullException>();

// xUnit built-in
await Assert.ThrowsAsync<ArgumentNullException>(() => sut.ProcessAsync(null));
```

### Do NOT fire-and-forget inside a test
```csharp
// ❌ Wrong — exception is lost; test may pass even when it shouldn't
[Fact]
public void Bad_FireAndForget()
{
    _ = sut.ProcessAsync(); // exception swallowed
}
```

### Nested async calls are fine
```csharp
[Fact]
public async Task MultipleAwaits_AllObserved()
{
    var result1 = await sut.GetAsync(1);
    var result2 = await sut.GetAsync(2);
    result1.Should().NotBeNull();
    result2.Should().NotBeNull();
}
```

## Code Example
```csharp
namespace AsyncTests;

public class OrderServiceTests
{
    private readonly Mock<IOrderRepository> _repo = new();
    private readonly OrderService _sut;

    public OrderServiceTests() => _sut = new OrderService(_repo.Object);

    [Fact]
    public async Task GetOrderAsync_KnownId_ReturnsOrder()
    {
        // Arrange
        var expected = new Order { Id = 1, Total = 99.99m };
        _repo.Setup(r => r.FindByIdAsync(1, It.IsAny<CancellationToken>()))
             .ReturnsAsync(expected);

        // Act
        var result = await _sut.GetOrderAsync(1);

        // Assert
        result.Should().BeEquivalentTo(expected);
    }

    [Fact]
    public async Task GetOrderAsync_UnknownId_ThrowsNotFoundException()
    {
        _repo.Setup(r => r.FindByIdAsync(99, It.IsAny<CancellationToken>()))
             .ReturnsAsync((Order?)null);

        var act = async () => await _sut.GetOrderAsync(99);

        await act.Should().ThrowAsync<NotFoundException>()
                 .WithMessage("*99*");
    }
}
```

## Common Follow-up Questions
- Why is `async void` dangerous in test methods?
- How do you handle `ConfigureAwait(false)` in test code?
- How do you test a method that uses `CancellationToken`?
- How does xUnit's `IAsyncLifetime` differ from a regular `async Task` test?
- What happens if you return `Task.CompletedTask` from a test method instead of actually awaiting?

## Common Mistakes / Pitfalls
- **Using `async void`** — exceptions propagate on the SynchronizationContext and are not caught by the test runner, causing silent passes or process crashes.
- **Blocking with `.Result` or `.GetAwaiter().GetResult()`** — can deadlock in environments with a SynchronizationContext; always `await`.
- **Not awaiting the Act** — if the method under test returns `Task` and you don't `await` it, the test may pass before the work is done.
- **Asserting synchronously on async methods** — `Assert.Throws<T>` (not `ThrowsAsync<T>`) will not catch async exceptions.

## References
- [xUnit async tests](https://xunit.net/docs/async)
- [Microsoft Learn — Asynchronous programming patterns](https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/)
- [FluentAssertions — Async assertions](https://fluentassertions.com/exceptions/)
