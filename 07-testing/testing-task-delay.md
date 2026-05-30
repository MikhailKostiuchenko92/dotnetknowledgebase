# How Do You Test a Method That Uses `Task.Delay` or Time-Based Logic?

**Category:** Testing / Async Code
**Difficulty:** 🟡 Middle
**Tags:** `Task.Delay`, `TimeProvider`, `FakeTimeProvider`, `testing`, `async`, `time-based`

## Question
> How do you test a method that uses `Task.Delay` or time-based logic?

## Short Answer
Inject `TimeProvider` (available from .NET 8) and use `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing` in tests to advance time synchronously. For legacy code using `Task.Delay` directly, extract the delay behind an interface and stub it. Avoid `Thread.Sleep` or real `Task.Delay` delays in tests — they make the suite slow and unreliable.

## Detailed Explanation

### The Problem
```csharp
// Hard to test — real time dependency is baked in
public async Task RetryAsync(Func<Task> operation)
{
    for (int i = 0; i < 3; i++)
    {
        await operation();
        await Task.Delay(TimeSpan.FromSeconds(30)); // 90 second test!
    }
}
```

### Solution 1: Inject `TimeProvider` (.NET 8+)
`System.TimeProvider` is an abstract class in .NET 8. Use it for both "current time" and delay:

```csharp
public class RetryService(TimeProvider timeProvider)
{
    public async Task RetryAsync(Func<Task> operation)
    {
        for (int i = 0; i < 3; i++)
        {
            await operation();
            await Task.Delay(TimeSpan.FromSeconds(30), timeProvider);
        }
    }
}
```

In production, register `TimeProvider.System`. In tests, use `FakeTimeProvider`:

```csharp
// NuGet: Microsoft.Extensions.TimeProvider.Testing
var fakeTime = new FakeTimeProvider();
var sut = new RetryService(fakeTime);

// Advance time manually without waiting
fakeTime.Advance(TimeSpan.FromSeconds(90));
```

### Solution 2: Abstract Behind `ITimeService`
For legacy projects (pre-.NET 8) or codebases that can't adopt `TimeProvider`:

```csharp
public interface ITimeService
{
    Task DelayAsync(TimeSpan delay, CancellationToken ct = default);
    DateTimeOffset UtcNow { get; }
}

// Stub in tests:
_timeService.Setup(t => t.DelayAsync(It.IsAny<TimeSpan>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
```

### `FakeTimeProvider` in Detail
```csharp
var fake = new FakeTimeProvider(startDateTime: new DateTimeOffset(2024, 1, 1, 0, 0, 0, TimeSpan.Zero));
fake.UtcNow   // → 2024-01-01
fake.Advance(TimeSpan.FromDays(1));
fake.UtcNow   // → 2024-01-02
```

`FakeTimeProvider.Advance` also fires any `ITimer` callbacks scheduled via `TimeProvider.CreateTimer`.

### Testing `PeriodicTimer`
```csharp
var fake = new FakeTimeProvider();
using var timer = fake.CreateTimer(_ => fired++, null, TimeSpan.Zero, TimeSpan.FromMinutes(5));
fake.Advance(TimeSpan.FromMinutes(15));
fired.Should().Be(3); // fired at 0, 5, 10 minutes
```

## Code Example
```csharp
namespace TimeBased.Tests;

public class RateLimiterTests
{
    [Fact]
    public async Task Allow_AfterWindowExpires_ResetsCounter()
    {
        var fakeTime = new FakeTimeProvider(DateTimeOffset.UtcNow);
        var limiter = new SlidingWindowRateLimiter(maxRequests: 2,
                                                    window: TimeSpan.FromSeconds(10),
                                                    timeProvider: fakeTime);

        limiter.Allow("user1").Should().BeTrue();  // request 1
        limiter.Allow("user1").Should().BeTrue();  // request 2
        limiter.Allow("user1").Should().BeFalse(); // over limit

        fakeTime.Advance(TimeSpan.FromSeconds(11)); // window expired

        limiter.Allow("user1").Should().BeTrue();  // window reset
    }

    [Fact]
    public async Task Retry_Delay_IsAwaited_WithFakeTime()
    {
        var fakeTime = new FakeTimeProvider();
        int attempts = 0;

        var sut = new RetryService(fakeTime);
        var task = sut.RetryAsync(async () =>
        {
            attempts++;
            if (attempts < 3) throw new HttpRequestException();
        });

        // Advance time to skip all delays
        fakeTime.Advance(TimeSpan.FromSeconds(60));

        await task;
        attempts.Should().Be(3);
    }
}
```

## Common Follow-up Questions
- What is `System.TimeProvider` and when was it introduced?
- How does `FakeTimeProvider.Advance` differ from `Thread.Sleep` in tests?
- How do you register `TimeProvider` in the DI container?
- Can `FakeTimeProvider` simulate `ITimer` and `PeriodicTimer`?
- How did people solve this problem before .NET 8 introduced `TimeProvider`?

## Common Mistakes / Pitfalls
- **Using real `Task.Delay` in tests** — slows the test suite by seconds or minutes per test.
- **Not injecting `TimeProvider`** — calling `DateTime.Now` directly makes the class untestable.
- **Forgetting `CancellationToken` in `Task.Delay(TimeSpan, TimeProvider)`** — the overload requires both when using `TimeProvider`.
- **Using `DateTimeOffset.UtcNow` statically** — replace with `TimeProvider.GetUtcNow()`.

## References
- [Microsoft Learn — TimeProvider](https://learn.microsoft.com/en-us/dotnet/api/system.timeprovider)
- [NuGet — Microsoft.Extensions.TimeProvider.Testing](https://www.nuget.org/packages/Microsoft.Extensions.TimeProvider.Testing/)
- [Andrew Lock — Testing time with TimeProvider](https://andrewlock.net/exploring-the-dotnet-8-preview-timeprovider/) (verify URL)
- [See also: testing-nondeterministic-dependencies.md](testing-nondeterministic-dependencies.md)
