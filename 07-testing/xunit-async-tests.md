# How Do You Write Async Tests in xUnit and What Pitfalls Exist?

**Category:** Testing / xUnit
**Difficulty:** 🔴 Senior
**Tags:** `xunit`, `async`, `async-await`, `Task`, `async void`, `CancellationToken`

## Question
> How do you write async tests in xUnit and what pitfalls exist?

## Short Answer
Declare the test method as `async Task` (not `async void`) and `await` the system under test normally. xUnit natively supports `Task`-returning test methods and will propagate exceptions correctly. The critical pitfall is `async void` — xUnit cannot await it, so exceptions escape the test context silently.

## Detailed Explanation

### Correct Async Test Pattern
```csharp
[Fact]
public async Task MyAsyncMethod_WhenCondition_ReturnsExpected()
{
    var result = await sut.DoWorkAsync();
    result.Should().Be(expected);
}
```

xUnit awaits the returned `Task` and reports exceptions from that task as test failures.

### The `async void` Pitfall
```csharp
// ❌ WRONG — xUnit cannot await void; exceptions are silently swallowed
[Fact]
public async void BadAsyncTest()
{
    await sut.DoWorkAsync(); // if this throws, the test PASSES
}
```

With `async void`:
1. The method returns immediately after the first `await`.
2. Continuation runs on the thread pool.
3. Any exception throws on the thread pool — outside the test context.
4. The test *passes* even if an exception was thrown.

**Always use `async Task`**, not `async void`, for test methods.

### Timeout Handling
xUnit does not have a built-in test timeout, but you can:
1. Use `CancellationTokenSource` with a timeout.
2. Use `Task.WhenAny` with a delay task.
3. Use xUnit v3's `Timeout` parameter: `[Fact(Timeout = 5000)]` (milliseconds).

### Testing Async Methods That Throw
```csharp
// FluentAssertions approach
[Fact]
public async Task SaveAsync_WhenDuplicate_ThrowsConstraintException()
{
    var act = async () => await repo.SaveAsync(duplicateEntity);
    await act.Should().ThrowAsync<DbConstraintException>();
}

// xUnit built-in approach
[Fact]
public async Task SaveAsync_WhenDuplicate_ThrowsConstraintException()
{
    await Assert.ThrowsAsync<DbConstraintException>(
        () => repo.SaveAsync(duplicateEntity));
}
```

> ⚠️ **Warning:** `Assert.Throws<T>` (sync) does not catch exceptions from async lambdas. Always use `Assert.ThrowsAsync<T>` for async code.

### Handling `CancellationToken` in Tests
Pass a real `CancellationToken` to test cancellation paths:
```csharp
[Fact]
public async Task ProcessAsync_WhenCancelled_ThrowsOperationCanceledException()
{
    using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(10));
    var act = async () => await sut.ProcessAsync(cts.Token);
    await act.Should().ThrowAsync<OperationCanceledException>();
}
```

### `SynchronizationContext` in Tests
xUnit runs tests without a `SynchronizationContext` by default (similar to a console app). This means:
- `ConfigureAwait(false)` vs `ConfigureAwait(true)` behaves identically in test code.
- Code that calls `.Result` or `.Wait()` in tests may deadlock if the production code uses `ConfigureAwait(true)` — always `await` in tests.

## Code Example
```csharp
namespace Async.Tests;

public class DataFetcherTests
{
    private readonly Mock<IHttpService> _http = new();
    private readonly DataFetcher _sut;

    public DataFetcherTests()
        => _sut = new DataFetcher(_http.Object);

    // ✅ Correct: async Task
    [Fact]
    public async Task FetchAsync_WhenServiceReturnsData_ReturnsDeserializedResult()
    {
        _http.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
             .ReturnsAsync("{\"id\": 1, \"name\": \"Widget\"}");

        var result = await _sut.FetchAsync("/products/1");

        result.Should().NotBeNull();
        result!.Name.Should().Be("Widget");
    }

    // ✅ Correct: async exception assertion
    [Fact]
    public async Task FetchAsync_WhenServiceThrows_PropagatesHttpException()
    {
        _http.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
             .ThrowsAsync(new HttpRequestException("timeout"));

        var act = async () => await _sut.FetchAsync("/products/1");

        await act.Should().ThrowAsync<HttpRequestException>()
                 .WithMessage("*timeout*");
    }

    // ✅ Test with CancellationToken
    [Fact]
    public async Task FetchAsync_WhenCancelled_ThrowsOperationCanceledException()
    {
        _http.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
             .Returns<string, CancellationToken>(async (_, ct) =>
             {
                 await Task.Delay(1000, ct); // respects cancellation
                 return "{}";
             });

        using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(50));
        var act = async () => await _sut.FetchAsync("/products/1", cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
```

## Common Follow-up Questions
- What is `IAsyncLifetime` and how does it relate to async test setup?
- How do you test an `IAsyncEnumerable<T>` method?
- What is `FakeTimeProvider` and how does it help test time-dependent async code?
- How do you set a timeout for an xUnit test?
- What is the `ConfigureAwait(false)` guideline in library vs. application code, and does it matter in tests?
- How do you test code that uses `Task.WhenAll` or `Task.WhenAny`?

## Common Mistakes / Pitfalls
- **`async void` test methods** — test passes even when an exception is thrown; always use `async Task`.
- **Mixing `async` and `.Result`/`.Wait()`** — can cause deadlocks; `await` everything.
- **Using `Assert.Throws<T>` for async methods** — sync version doesn't await; use `Assert.ThrowsAsync<T>`.
- **Blocking on async in constructor** — `.GetAwaiter().GetResult()` in test constructor can deadlock; use `IAsyncLifetime`.
- **Non-deterministic async timing** — using `Thread.Sleep` or `Task.Delay` to wait for background work; use proper synchronization primitives or `await` directly.

## References
- [xUnit documentation — Async tests](https://xunit.net/docs/getting-started/netcore/cmdline)
- [Stephen Cleary — Don't Block on Async Code](https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html)
- [Stephen Toub — Async/Await FAQ](https://devblogs.microsoft.com/pfxteam/asyncawait-faq/)
- [Microsoft Learn — Unit testing async code](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [FluentAssertions — Async assertions](https://fluentassertions.com/exceptions/)
