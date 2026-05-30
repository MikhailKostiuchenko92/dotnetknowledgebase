# What Is `SetupSequence` in Moq and When Is It Useful?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `SetupSequence`, `successive-calls`, `retry`, `state-machine`

## Question
> What is `SetupSequence` in Moq and when is it useful?

## Short Answer
`SetupSequence` configures a mock to return different values or throw different exceptions on successive calls to the same method. Each `Returns`/`Throws` call in the chain handles one invocation in order. After the sequence is exhausted, the mock falls back to the default behavior. Use it for testing retry logic, polling patterns, and state machines.

## Detailed Explanation

### Basic Syntax
```csharp
mock.SetupSequence(x => x.Method())
    .Returns(firstValue)
    .Returns(secondValue)
    .Throws<TransientException>()
    .Returns(thirdValue);
```

- First call → `firstValue`
- Second call → `secondValue`
- Third call → throws `TransientException`
- Fourth call → `thirdValue`
- Fifth+ calls → default (Loose: `default(T)`; Strict: throws `MockException`)

### When to Use `SetupSequence`

| Scenario | Example |
|---|---|
| Retry logic | First call throws transient error, second succeeds |
| Polling / eventual consistency | Returns "Pending", "Pending", then "Complete" |
| Stateful services | Returns different data per call (e.g., pagination) |
| Circuit breaker testing | Multiple failures then recovery |

### Async Version
```csharp
mock.SetupSequence(s => s.FetchStatusAsync())
    .ReturnsAsync(Status.Processing)
    .ReturnsAsync(Status.Processing)
    .ReturnsAsync(Status.Complete);
```

### `SetupSequence` vs. Multiple `Setup` Calls
A plain `Setup` call for the same method/argument always overrides the previous one — only the last setup applies. `SetupSequence` is the correct way to have different behaviour per call.

```csharp
// ❌ This does NOT produce a sequence — only the last Setup applies
mock.Setup(x => x.GetValue()).Returns(1);
mock.Setup(x => x.GetValue()).Returns(2); // overrides the first

// ✅ Correct — SetupSequence for successive-call behaviour
mock.SetupSequence(x => x.GetValue())
    .Returns(1)
    .Returns(2);
```

### After Sequence Exhaustion
Once all setups are consumed:
- **Loose** mock: returns `default(T)`
- **Strict** mock: throws `MockException`

To loop or reset, you'll need a callback-based custom approach or restructure the test.

## Code Example
```csharp
namespace Retry.Tests;

public class ResilienceTests
{
    // Test retry: first two calls fail, third succeeds
    [Fact]
    public async Task ProcessWithRetry_TransientFailures_EventuallySucceeds()
    {
        var service = new Mock<IExternalService>();
        service.SetupSequence(s => s.CallAsync())
               .ThrowsAsync(new TransientException())
               .ThrowsAsync(new TransientException())
               .ReturnsAsync(new ServiceResponse { Success = true });

        var retryPolicy = new RetryPolicy(maxAttempts: 3, delayMs: 0);
        var sut = new ResilienceClient(service.Object, retryPolicy);

        var result = await sut.ExecuteAsync();

        result.Success.Should().BeTrue();
        service.Verify(s => s.CallAsync(), Times.Exactly(3));
    }

    // Test polling: status changes from pending to complete
    [Fact]
    public async Task PollUntilComplete_ReturnsFinalStatusWhenReady()
    {
        var statusChecker = new Mock<IStatusChecker>();
        statusChecker.SetupSequence(s => s.GetStatusAsync("job-1"))
                     .ReturnsAsync(JobStatus.Queued)
                     .ReturnsAsync(JobStatus.Processing)
                     .ReturnsAsync(JobStatus.Complete);

        var sut = new JobPoller(statusChecker.Object, pollIntervalMs: 0);
        var finalStatus = await sut.WaitForCompletionAsync("job-1");

        finalStatus.Should().Be(JobStatus.Complete);
        statusChecker.Verify(s => s.GetStatusAsync("job-1"), Times.Exactly(3));
    }

    // Test that permanent failure is not retried beyond max attempts
    [Fact]
    public async Task ProcessWithRetry_PermanentFailure_ThrowsAfterMaxAttempts()
    {
        var service = new Mock<IExternalService>();
        service.SetupSequence(s => s.CallAsync())
               .ThrowsAsync(new PermanentException("fatal"))
               .ThrowsAsync(new PermanentException("fatal"))
               .ThrowsAsync(new PermanentException("fatal"));

        var retryPolicy = new RetryPolicy(maxAttempts: 3, delayMs: 0);
        var sut = new ResilienceClient(service.Object, retryPolicy);

        var act = async () => await sut.ExecuteAsync();
        await act.Should().ThrowAsync<PermanentException>();
        service.Verify(s => s.CallAsync(), Times.Exactly(3));
    }
}
```

## Common Follow-up Questions
- What happens after all `SetupSequence` entries are consumed?
- Can you mix `Returns` and `Throws` in the same sequence?
- How do you reset a `SetupSequence` to replay it?
- How does `SetupSequence` interact with `MockBehavior.Strict`?
- Is `SetupSequence` available for async methods?
- How do you test a polly retry policy with `SetupSequence`?

## Common Mistakes / Pitfalls
- **Using multiple `Setup` calls for successive-call behaviour** — only the last setup takes effect; use `SetupSequence`.
- **Sequence exhaustion not accounted for** — if the SUT calls the method more times than the sequence has entries, the Loose default (`null`/`0`) kicks in silently.
- **Expecting `SetupSequence` to loop** — the sequence is finite; design tests to match the exact number of expected calls.
- **`ThrowsAsync` vs `Throws` confusion** — use `ThrowsAsync` for async methods in the sequence.
- **Not verifying call count** — if the retry makes 3 attempts but you set up 5 entries, the last 2 entries are never reached; add a `Verify(..., Times.Exactly(3))` to confirm exact invocation count.

## References
- [Moq documentation — SetupSequence](https://github.com/devlooped/moq/wiki/Quickstart#sequences)
- [Moq GitHub](https://github.com/devlooped/moq)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
