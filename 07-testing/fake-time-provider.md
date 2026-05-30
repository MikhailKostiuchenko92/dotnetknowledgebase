# What Is `FakeTimeProvider` and How Does It Solve Time-Dependent Test Problems?

**Category:** Testing / Async Code
**Difficulty:** 🔴 Senior
**Tags:** `FakeTimeProvider`, `TimeProvider`, `.NET 8`, `testing`, `time`, `ITimer`, `PeriodicTimer`

## Question
> What is `FakeTimeProvider` (from Microsoft.Extensions.TimeProvider.Testing) and how does it solve time-dependent test problems?

## Short Answer
`FakeTimeProvider` is a test-friendly implementation of the abstract `System.TimeProvider` class (introduced in .NET 8). It allows you to manually advance time in tests without sleeping, making tests that depend on `DateTime`, `Task.Delay`, `ITimer`, or `PeriodicTimer` fast and deterministic.

## Detailed Explanation

### Why `TimeProvider` Exists
Before .NET 8, code using `DateTime.UtcNow` or `Task.Delay` was hard to test:
- `DateTime.UtcNow` is a static property — untestable directly
- Custom `IDateTimeProvider` interfaces proliferated across codebases with no standard

.NET 8 introduces `System.TimeProvider` as the official abstraction:

```csharp
// Production
services.AddSingleton(TimeProvider.System);

// Tests
services.AddSingleton<TimeProvider>(new FakeTimeProvider());
```

### What `FakeTimeProvider` Provides

| Method / Property | Description |
|---|---|
| `Advance(TimeSpan)` | Moves simulated clock forward, triggering timers |
| `SetUtcNow(DateTimeOffset)` | Jumps the clock to a specific point |
| `UtcNow` | Returns the simulated current time |
| `CreateTimer(...)` | Returns a fake `ITimer` that fires based on `Advance` calls |

### Using `FakeTimeProvider` with `Task.Delay`

```csharp
// SUT (production code)
public async Task WaitAsync(TimeProvider tp)
    => await Task.Delay(TimeSpan.FromSeconds(10), tp);

// Test
var fake = new FakeTimeProvider();
var task = sut.WaitAsync(fake);

task.IsCompleted.Should().BeFalse();

fake.Advance(TimeSpan.FromSeconds(10));
await task; // completes without real waiting
```

> ⚠️ `Advance` does not literally complete `Task.Delay` synchronously in all cases. After `Advance`, allow a task schedule tick: `await Task.Yield()` before asserting.

### Using `FakeTimeProvider` with `ITimer` / `PeriodicTimer`
```csharp
int ticks = 0;
var fake = new FakeTimeProvider();
using var timer = fake.CreateTimer(_ => ticks++, null,
    dueTime: TimeSpan.FromSeconds(5),
    period: TimeSpan.FromSeconds(5));

fake.Advance(TimeSpan.FromSeconds(20));
ticks.Should().Be(4); // fired at 5, 10, 15, 20 seconds
```

### Full Example: Rate Limiter with `TimeProvider`
```csharp
public class BurstLimiter(int capacity, TimeSpan window, TimeProvider tp)
{
    private Queue<DateTimeOffset> _timestamps = new();

    public bool Allow()
    {
        var now = tp.GetUtcNow();
        while (_timestamps.Count > 0 && now - _timestamps.Peek() > window)
            _timestamps.Dequeue();
        if (_timestamps.Count >= capacity) return false;
        _timestamps.Enqueue(now);
        return true;
    }
}
```

```csharp
// Test
var fake = new FakeTimeProvider(DateTimeOffset.UtcNow);
var sut = new BurstLimiter(capacity: 2, window: TimeSpan.FromSeconds(10), tp: fake);

sut.Allow().Should().BeTrue();
sut.Allow().Should().BeTrue();
sut.Allow().Should().BeFalse();

fake.Advance(TimeSpan.FromSeconds(11));

sut.Allow().Should().BeTrue(); // window cleared
```

### DI Registration Pattern
```csharp
// Program.cs
builder.Services.AddSingleton(TimeProvider.System);

// Test fixture
var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(b =>
    b.ConfigureTestServices(s =>
        s.AddSingleton<TimeProvider>(new FakeTimeProvider())));
```

## Code Example
```csharp
namespace FakeTimeTests;

public class TokenExpiryTests
{
    [Fact]
    public void Token_ExpiredAfterWindow_ReturnsExpired()
    {
        var startTime = new DateTimeOffset(2024, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var fake = new FakeTimeProvider(startTime);
        var token = new ExpiringToken("abc123", TimeSpan.FromMinutes(30), fake);

        token.IsExpired.Should().BeFalse();

        fake.Advance(TimeSpan.FromMinutes(31));

        token.IsExpired.Should().BeTrue();
    }

    [Fact]
    public async Task Heartbeat_TicksEveryMinute_FiresExpectedTimes()
    {
        int heartbeats = 0;
        var fake = new FakeTimeProvider();
        var service = new HeartbeatService(fake, onBeat: () => heartbeats++);

        _ = service.RunAsync(CancellationToken.None);
        fake.Advance(TimeSpan.FromMinutes(5));
        await Task.Yield(); // allow scheduler to run callbacks

        heartbeats.Should().BeGreaterOrEqualTo(5);
    }
}
```

## Common Follow-up Questions
- How does `FakeTimeProvider` compare to the older `IClock` / `IDateTimeProvider` patterns?
- When was `System.TimeProvider` introduced and what .NET versions support it?
- How do you use `FakeTimeProvider` with `PeriodicTimer` in a hosted service?
- Is `FakeTimeProvider.Advance` synchronous? What is the interaction with `Task` scheduling?
- How do you combine `FakeTimeProvider` with `WebApplicationFactory` for integration tests?

## Common Mistakes / Pitfalls
- **Forgetting to inject `TimeProvider`** — statically calling `DateTime.UtcNow` bypasses the abstraction.
- **Not calling `await Task.Yield()` after `Advance`** — timer callbacks are scheduled on the thread pool; give the scheduler a chance to run.
- **Confusing `SetUtcNow` vs. `Advance`** — `SetUtcNow` jumps; `Advance` increments from current value.
- **Only available for .NET 8+** — for older targets, use the community port or `IClock` abstraction.

## References
- [Microsoft Learn — TimeProvider](https://learn.microsoft.com/en-us/dotnet/api/system.timeprovider)
- [NuGet — Microsoft.Extensions.TimeProvider.Testing](https://www.nuget.org/packages/Microsoft.Extensions.TimeProvider.Testing/)
- [.NET Blog — Introducing TimeProvider](https://devblogs.microsoft.com/dotnet/introducing-the-new-timeprovider-api/) (verify URL)
- [See also: testing-nondeterministic-dependencies.md](testing-nondeterministic-dependencies.md)
- [See also: testing-task-delay.md](testing-task-delay.md)
