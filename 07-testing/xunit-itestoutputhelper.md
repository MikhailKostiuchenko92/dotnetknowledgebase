# How Do You Implement Custom `ITestOutputHelper` Logging in xUnit?

**Category:** Testing / xUnit
**Difficulty:** 🔴 Senior
**Tags:** `xunit`, `ITestOutputHelper`, `logging`, `diagnostics`, `ILogger`, `test-output`

## Question
> How do you implement custom `ITestOutputHelper` logging in xUnit?

## Short Answer
Inject `ITestOutputHelper` via the test class constructor — xUnit automatically provides it. Write to it with `output.WriteLine(...)`. For integration tests or code that uses `Microsoft.Extensions.Logging.ILogger`, bridge the two using `XunitLoggerProvider` (from `Xunit.Extensions.Logging` or a custom implementation).

## Detailed Explanation

### Why `ITestOutputHelper`?
xUnit captures test output per-test and displays it only for *failed* tests by default (or all tests when verbose). This is crucial for:
- Debugging why a test failed without polluting the console.
- Logging HTTP request/response details in integration tests.
- Capturing diagnostic information without affecting other tests.

Using `Console.WriteLine` in tests is an antipattern — the output is interleaved across parallel tests and invisible in most runners.

### Basic Usage
```csharp
public class MyTests(ITestOutputHelper output)
{
    [Fact]
    public void Something_IsTrue()
    {
        output.WriteLine("Setting up the test...");
        var result = ComputeSomething();
        output.WriteLine($"Result was: {result}");
        result.Should().BeTrue();
    }
}
```

xUnit injects `ITestOutputHelper` automatically if the constructor accepts it (no DI registration needed).

### Bridging to `ILogger<T>` / `ILoggerFactory`
Real application code uses `ILogger`. In integration tests, you want log output routed to xUnit's output rather than the console or void:

**Option 1: Use `Xunit.Extensions.Logging` package**
```bash
dotnet add package Xunit.Extensions.Logging
```

```csharp
using Xunit.Extensions.Logging;

public class ServiceTests(ITestOutputHelper output)
{
    [Fact]
    public void Process_LogsExpectedMessage()
    {
        var loggerFactory = LoggerFactory.Create(b =>
            b.AddXunit(output, LogLevel.Debug));

        var logger = loggerFactory.CreateLogger<OrderService>();
        var sut = new OrderService(logger);

        sut.Process(new Order());
        // xUnit output shows all ILogger calls from OrderService
    }
}
```

**Option 2: Custom `ILoggerProvider` (no package)**
Implement a minimal provider that writes to `ITestOutputHelper`:

```csharp
public sealed class XunitLoggerProvider(ITestOutputHelper output) : ILoggerProvider
{
    public ILogger CreateLogger(string categoryName) => new XunitLogger(output, categoryName);
    public void Dispose() { }
}

public sealed class XunitLogger(ITestOutputHelper output, string category) : ILogger
{
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
    public bool IsEnabled(LogLevel level) => level >= LogLevel.Debug;

    public void Log<TState>(LogLevel level, EventId id, TState state,
        Exception? ex, Func<TState, Exception?, string> formatter)
    {
        output.WriteLine($"[{level}] {category}: {formatter(state, ex)}");
        if (ex is not null)
            output.WriteLine(ex.ToString());
    }
}
```

### Using with `WebApplicationFactory`
Route all ASP.NET Core pipeline logs to xUnit output in integration tests:

```csharp
public class ApiTests(ITestOutputHelper output) : IClassFixture<WebApplicationFactory<Program>>
{
    // See next section for WebApplicationFactory setup
}
```

In the factory override:
```csharp
factory.WithWebHostBuilder(b =>
    b.ConfigureLogging(logging =>
    {
        logging.ClearProviders();
        logging.AddProvider(new XunitLoggerProvider(output));
    }));
```

> ⚠️ **Warning:** `ITestOutputHelper` is test-instance-scoped. If you share a `WebApplicationFactory` via `IClassFixture<T>`, you cannot directly pass `ITestOutputHelper` to the fixture constructor — the helper is created after the fixture. Capture it in each test class constructor and pass to the factory per-test client.

## Code Example
```csharp
namespace Diagnostics.Tests;

// ── Basic usage ───────────────────────────────────────────────────────────────
public class CurrencyConverterTests(ITestOutputHelper output)
{
    [Fact]
    public void Convert_USD_to_EUR_ReturnsPositiveAmount()
    {
        output.WriteLine("Testing USD→EUR conversion");
        var converter = new CurrencyConverter();

        decimal result = converter.Convert(100m, "USD", "EUR");

        output.WriteLine($"100 USD = {result} EUR");
        result.Should().BeGreaterThan(0);
    }
}

// ── Bridge to ILogger<T> ──────────────────────────────────────────────────────
public class EmailServiceTests(ITestOutputHelper output)
{
    [Fact]
    public async Task SendAsync_LogsDeliveryAttempt()
    {
        // All ILogger calls inside EmailService appear in xUnit output
        var loggerFactory = LoggerFactory.Create(b =>
        {
            b.SetMinimumLevel(LogLevel.Debug);
            b.AddProvider(new XunitLoggerProvider(output));
        });

        var sut = new EmailService(loggerFactory.CreateLogger<EmailService>());
        await sut.SendAsync(new Email { To = "test@example.com", Body = "Hi" });

        // Output (visible if the test fails or verbose mode):
        // [Debug] EmailService: Attempting to deliver to test@example.com
        // [Information] EmailService: Delivered successfully
    }
}
```

## Common Follow-up Questions
- How do you capture log output from the full ASP.NET Core pipeline in integration tests?
- What is the `Xunit.Extensions.Logging` package and how does it simplify ILogger bridging?
- How do you make `ITestOutputHelper` available inside a shared `IClassFixture`?
- Can you write to `ITestOutputHelper` from background threads or `Task.Run`?
- How do xUnit, NUnit, and MSTest differ in their test output / logging support?
- How do you suppress test output in successful test runs in CI?

## Common Mistakes / Pitfalls
- **Using `Console.WriteLine` in tests** — output is interleaved across parallel tests, invisible in most CI UIs, and lost on failure.
- **Writing to `ITestOutputHelper` after test disposal** — if you capture the helper in an async callback that outlives the test, `ObjectDisposedException` is thrown.
- **Sharing `ITestOutputHelper` from a test class into `IClassFixture`** — the fixture is created before the test class, so the helper isn't available in `InitializeAsync`; capture it per-test instead.
- **Not bridging `ILogger` to `ITestOutputHelper`** — diagnostic logs from the SUT are invisible, making failures hard to debug.
- **Verbose logging at `Trace` level in every test** — clutters output; set minimum level to `Debug` or higher in tests.

## References
- [xUnit documentation — Capturing output](https://xunit.net/docs/capturing-output)
- [NuGet — Xunit.Extensions.Logging](https://www.nuget.org/packages/Xunit.Extensions.Logging/)
- [Andrew Lock — Logging in xUnit tests](https://andrewlock.net/adding-logging-to-xunit-tests/) (verify URL)
- [Microsoft Learn — Logging in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging)
