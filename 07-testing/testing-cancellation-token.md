# How Do You Test a Method That Uses `CancellationToken`?

**Category:** Testing / Async Code
**Difficulty:** 🟡 Middle
**Tags:** `CancellationToken`, `async`, `testing`, `cooperative-cancellation`, `OperationCanceledException`

## Question
> How do you test a method that uses `CancellationToken`?

## Short Answer
Create a `CancellationTokenSource`, optionally cancel it before or during the call, and assert that `OperationCanceledException` (or its subtype `TaskCanceledException`) is thrown. For the happy path, pass `CancellationToken.None` or a non-cancelled token. Test both the cancelled and non-cancelled branches.

## Detailed Explanation

### Three Scenarios to Test

| Scenario | Token state | Expected outcome |
|---|---|---|
| Happy path | `CancellationToken.None` | Returns result normally |
| Pre-cancelled | Already cancelled before call | Throws `OperationCanceledException` immediately |
| Cancelled mid-flight | Cancelled after delay | Throws before full result is produced |

### Scenario 1: Happy Path
```csharp
var result = await sut.GetDataAsync(CancellationToken.None);
result.Should().NotBeNull();
```

### Scenario 2: Pre-Cancelled Token
```csharp
var cts = new CancellationTokenSource();
cts.Cancel(); // cancel before calling

var act = async () => await sut.GetDataAsync(cts.Token);
await act.Should().ThrowAsync<OperationCanceledException>();
```

### Scenario 3: Cancel After a Delay
Use `CancelAfter` for methods that block:
```csharp
var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(50));

var act = async () => await sut.GetDataAsync(cts.Token);
await act.Should().ThrowAsync<OperationCanceledException>();
```

### Testing That Cancellation Is Propagated to Dependencies
If the SUT calls a dependency with `CancellationToken`, verify it's forwarded:
```csharp
_repo.Setup(r => r.FindAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
     .ReturnsAsync(new Order());

var cts = new CancellationTokenSource();
await sut.ProcessAsync(1, cts.Token);

_repo.Verify(r => r.FindAsync(1, cts.Token), Times.Once);
```

### Testing Cancellation in Background Methods
For methods that loop with cancellation:
```csharp
[Fact]
public async Task Worker_CancelledToken_StopsGracefully()
{
    var cts = new CancellationTokenSource();
    var task = sut.RunAsync(cts.Token);

    await Task.Delay(20); // let it start
    cts.Cancel();

    await task; // should complete, not hang
}
```

### `TaskCanceledException` vs `OperationCanceledException`
`TaskCanceledException` inherits `OperationCanceledException`. Assert on the base type unless you specifically test for `TaskCanceledException`:
```csharp
await act.Should().ThrowAsync<OperationCanceledException>();
// This also catches TaskCanceledException
```

## Code Example
```csharp
namespace Cancellation.Tests;

public class ProductLoaderTests
{
    private readonly Mock<IHttpService> _http = new();
    private readonly ProductLoader _sut;

    public ProductLoaderTests() =>
        _sut = new ProductLoader(_http.Object);

    [Fact]
    public async Task LoadAsync_NonCancelledToken_ReturnsProducts()
    {
        _http.Setup(h => h.GetAsync(It.IsAny<string>(), CancellationToken.None))
             .ReturnsAsync(new[] { new Product { Id = 1 } });

        var result = await _sut.LoadAsync(CancellationToken.None);

        result.Should().HaveCount(1);
    }

    [Fact]
    public async Task LoadAsync_PreCancelledToken_ThrowsImmediately()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var act = async () => await _sut.LoadAsync(cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
        _http.Verify(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
                     Times.Never);
    }

    [Fact]
    public async Task LoadAsync_CancellationPropagated_ToHttpService()
    {
        using var cts = new CancellationTokenSource();
        _http.Setup(h => h.GetAsync(It.IsAny<string>(), cts.Token))
             .ReturnsAsync(Array.Empty<Product>());

        await _sut.LoadAsync(cts.Token);

        _http.Verify(h => h.GetAsync(It.IsAny<string>(), cts.Token), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the difference between `OperationCanceledException` and `TaskCanceledException`?
- Should methods accept `CancellationToken.None` as a default parameter?
- How do you test a background service that uses cancellation for graceful shutdown?
- How does cooperative cancellation work (i.e., `token.ThrowIfCancellationRequested()`)?
- Can you cancel a `Task` that doesn't accept a `CancellationToken`?

## Common Mistakes / Pitfalls
- **Asserting `TaskCanceledException`** — if the method throws `OperationCanceledException` instead (both are valid), the assertion fails. Use the base type.
- **Not verifying the token is forwarded** — the SUT may ignore the token and never check it; test that it's passed to I/O calls.
- **Using `Thread.Sleep` to delay cancellation** — blocks the test runner thread; use `await Task.Delay` instead.
- **Forgetting to dispose `CancellationTokenSource`** — use `using var cts = new CancellationTokenSource()`.

## References
- [Microsoft Learn — Cancellation in managed threads](https://learn.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads)
- [Stephen Toub — Cooperative Cancellation](https://devblogs.microsoft.com/pfxteam/)
- [FluentAssertions — ThrowAsync](https://fluentassertions.com/exceptions/)
