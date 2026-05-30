# What Is the Danger of `async void` in Test Methods?

**Category:** Testing / Async Code
**Difficulty:** 🟡 Middle
**Tags:** `async`, `void`, `async void`, `exceptions`, `test-runner`, `xUnit`, `NUnit`

## Question
> What is the danger of `async void` in test methods?

## Short Answer
`async void` test methods return immediately (before the async work completes). The test runner has no `Task` to await, so it marks the test as **passed before the work finishes**. Any exception thrown inside the method propagates to the `SynchronizationContext` rather than back to the runner — causing either a silent pass, an unhandled exception crash, or a timeout, but never a clean test failure.

## Detailed Explanation

### How `async void` Breaks Test Runners

When a test runner calls a method, it either:
- Receives `void` → the method is considered done immediately
- Receives `Task` → the runner awaits it, observing exceptions

With `async void`, the method signature says `void`, so the runner treats it as complete the moment it hits the first `await`. Any continuation (and any exception thrown after that `await`) runs on the `SynchronizationContext` without any connection to the original test invocation.

### Scenario 1: Silent Pass (Most Dangerous)
```csharp
// ❌ This test always passes — even when it should fail
[Fact]
public async void Bad_SilentPass()
{
    var result = await sut.GetOrderAsync(999); // throws NotFoundException
    result.Should().NotBeNull(); // never reached — but test already "passed"
}
```

### Scenario 2: Unhandled Exception → Process Crash
If the exception isn't caught anywhere, it surfaces as an unhandled exception on the SynchronizationContext, which **kills the test process** in some environments.

### Scenario 3: Flaky Timeout
In environments with synchronisation (e.g., WPF's dispatcher), the test might occasionally hang.

### Correct: Always `async Task`
```csharp
// ✅ Correct — exception propagates through the Task back to the runner
[Fact]
public async Task Good_ExceptionPropagates()
{
    var act = async () => await sut.GetOrderAsync(999);
    await act.Should().ThrowAsync<NotFoundException>();
}
```

### Why Do People Write `async void` Tests?
- Copy-pasting event handler patterns (which must be `async void`)
- Forgetting to change the return type from `void` to `Task`
- Older test framework documentation that predates native `Task` support

### Detecting It
Many code analyzers flag this:
- **xUnit1998** (xunit.analyzers) — warns when a test method is `async void`
- **CA2007** — reminds to `ConfigureAwait`
- Install `xunit.analyzers` NuGet package to get analyzer coverage

## Code Example
```csharp
namespace AsyncVoidDemo;

public class OrderServiceTests
{
    private readonly OrderService _sut = new(new FakeOrderRepo());

    // ❌ DANGEROUS — this test will always appear green
    [Fact]
    public async void Dangerous_AsyncVoidTest()
    {
        var order = await _sut.GetOrderAsync(999); // throws
        order.Should().NotBeNull();   // never evaluated!
    }                                 // runner sees void return, marks as passed

    // ✅ CORRECT — exception propagates through Task
    [Fact]
    public async Task Correct_AsyncTaskTest()
    {
        var act = async () => await _sut.GetOrderAsync(999);
        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    // ✅ Also correct with xUnit Assert.ThrowsAsync
    [Fact]
    public async Task Correct_AssertThrowsAsync()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _sut.GetOrderAsync(999));
    }
}
```

## Common Follow-up Questions
- Is there any legitimate use of `async void` in production code?
- What is a SynchronizationContext and how does it interact with async void?
- How does xUnit detect async void methods in its runner?
- Why don't test frameworks just detect and warn about async void at runtime?
- What happens to `async void` exceptions in ASP.NET Core?

## Common Mistakes / Pitfalls
- **Trusting a green test** — an `async void` test that "passes" may have never actually run the assertions.
- **Using `async void` for test helpers** — private helper methods called from tests also must return `Task`.
- **Not installing xunit.analyzers** — without the analyzer you won't get a build-time warning.
- **Event-handler pattern copy-paste** — event handlers `must` be `async void`; test methods `must not`.

## References
- [xUnit.net analyzers — xunit1998](https://xunit.net/xunit.analyzers/rules/xUnit1998)
- [Stephen Cleary — Async/Await Best Practices](https://learn.microsoft.com/en-us/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [Andrew Lock — async void dangers](https://andrewlock.net/series/exploring-dotnet/) (verify URL)
