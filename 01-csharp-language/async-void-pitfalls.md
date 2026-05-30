# Async Void Pitfalls

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `async void`, `async Task`, `exception`, `event-handler`, `fire-and-forget`

## Question

> Why is `async void` dangerous, and when is it the only correct choice?

Also asked as:
- "What happens to an exception thrown inside an `async void` method?"
- "How do you safely implement a fire-and-forget async operation without `async void`?"

## Short Answer

`async void` methods cannot be awaited, so their exceptions propagate to the `SynchronizationContext` that was active when they started — and in most environments this crashes the process. The caller has no `Task` to observe, cancel, or coordinate on. The **only** legitimate use is event handlers, where the delegate signature `void (object, EventArgs)` is imposed by the framework. For fire-and-forget scenarios use `async Task` and deliberately discard the task (`_ = DoWorkAsync()`), or use a wrapper that logs the exception.

## Detailed Explanation

### What `async void` Compiles To

The compiler generates the same state machine as for `async Task`, but the builder is `AsyncVoidMethodBuilder` instead of `AsyncTaskMethodBuilder`. The critical difference: `AsyncVoidMethodBuilder` has no backing `Task` object. When the state machine encounters an unhandled exception, it calls `SynchronizationContext.Current?.Post(...)` to re-throw on the context — or, if there is no context, re-throws on the thread pool directly via `ExceptionDispatchInfo.Throw()`.

### Exception Behavior by Environment

| Environment | `async void` exception outcome |
|---|---|
| WPF / WinForms | Posted to `Dispatcher` / `Application.ThreadException` — **crashes app** unless handled globally |
| Classic ASP.NET | Posted to `AspNetSynchronizationContext` — **crashes request** or app pool |
| ASP.NET Core (no SC) | Thrown on thread pool — raises `AppDomain.UnhandledException` — **crashes process** |
| Console (no SC) | Thrown on thread pool — **crashes process** |
| xUnit / NUnit tests | Likely **silently swallowed** — test passes even though the async part threw |

In every environment, the caller of an `async void` method has no way to catch the exception with a `try/catch` around the call site.

### Why You Cannot `await` It

`async void` returns `void`, so there is nothing to `await`:

```csharp
async void DoSomethingAsync() { await Task.Delay(100); }

// Cannot await:
// await DoSomethingAsync();   // CS4008 — cannot await void

// Cannot observe:
// var t = DoSomethingAsync(); // CS0029 — void is not assignable to Task
```

You also cannot use `Task.WhenAll`, add a timeout, or attach a continuation.

### The Only Legitimate Use: Event Handlers

Framework event delegates have the signature `void (object? sender, EventArgs e)`. When the event handler itself must do async work, `async void` is the *only* way to use `await` inside it:

```csharp
private async void Button_Click(object? sender, RoutedEventArgs e)
{
    Button.IsEnabled = false;
    try
    {
        await LoadDataAsync();   // ✅ async work inside event handler
    }
    catch (Exception ex)
    {
        MessageBox.Show(ex.Message);   // handle manually — no caller to propagate to
    }
    finally
    {
        Button.IsEnabled = true;
    }
}
```

**Rule:** Always wrap the entire body of an `async void` event handler in `try/catch`. The framework will not propagate exceptions for you.

### Safe Fire-and-Forget Alternatives

**Option 1 — Discard with explicit exception handling in the method:**

```csharp
_ = RunFireAndForgetAsync();   // caller discards Task; method must handle its own exceptions
```

**Option 2 — Extension method wrapper:**

```csharp
public static void FireAndForget(this Task task, Action<Exception>? onError = null)
{
    task.ContinueWith(t =>
    {
        if (t.IsFaulted)
            (onError ?? (ex => Console.Error.WriteLine(ex)))(t.Exception!.Flatten().InnerException!);
    }, TaskContinuationOptions.OnlyOnFaulted);
}

// Usage:
DoWorkAsync().FireAndForget(ex => _logger.LogError(ex, "Background work failed"));
```

**Option 3 — `IHostedService` / `BackgroundService` in ASP.NET Core:**

For long-lived background tasks, use a proper hosted service with structured lifetime and cancellation.

### Detecting `async void` with Roslyn Analyzers

Roslyn / .NET SDK ships the analyzer rule `VSTHRD100` (via the `Microsoft.VisualStudio.Threading.Analyzers` package) and the community analyzer `AsyncFixer` both flag `async void` outside event handlers. Enable them in `<Analyzers>` in your project file.

## Code Example

```csharp
using System;
using System.Threading.Tasks;

// ❌ BAD — async void in non-event-handler code
async void BrokenFireAndForget()
{
    await Task.Delay(50);
    throw new InvalidOperationException("This will crash the process!");
}

// Try/catch at call site does NOT catch it:
try
{
    BrokenFireAndForget();   // exception escapes to SynchronizationContext / thread pool
}
catch
{
    Console.WriteLine("Never reached");
}

// ✅ GOOD — async Task, fire-and-forget with discarded task
async Task SafeWorkAsync()
{
    await Task.Delay(50);
    Console.WriteLine("Done");
    // Any exception stays inside the Task and can be observed
}

// Option A: discard (exception is unobserved unless the method handles it)
_ = SafeWorkAsync();

// Option B: .FireAndForget() extension logs exceptions
SafeWorkAsync().ContinueWith(t =>
{
    if (t.IsFaulted)
        Console.Error.WriteLine($"Background error: {t.Exception!.Flatten().InnerException!.Message}");
}, TaskContinuationOptions.OnlyOnFaulted);

// ✅ ONLY CORRECT async void: event handler
class Form
{
    public event EventHandler? ButtonClicked;

    void Raise() => ButtonClicked?.Invoke(this, EventArgs.Empty);

    // async void is justified here — delegate signature is void
    async void OnButtonClicked(object? sender, EventArgs e)
    {
        try
        {
            await Task.Delay(10);
            Console.WriteLine("Button handled");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Handler error: {ex.Message}");
        }
    }
}
```

## Common Follow-up Questions

- How does `Func<Task>` allow you to write an async delegate that an event system can invoke without `async void`?
- How do you unit-test async void event handlers — does the test wait for them?
- What is the `TaskScheduler.UnobservedTaskException` event and when does it fire for discarded tasks?
- How does `IAsyncRelayCommand` in MVVM toolkits avoid `async void` for button commands?
- What is `GlobalExceptionHandlers` in MAUI/WPF and how does it relate to `async void` crashes?

## Common Mistakes / Pitfalls

- **Using `async void` for fire-and-forget outside event handlers.** Always use `async Task` and either `await` it or explicitly manage its lifetime.
- **Not wrapping `async void` event handlers in `try/catch`.** An unhandled exception in a WPF event handler posted to the dispatcher will raise `Application.DispatcherUnhandledException` — in the best case showing an error dialog; in the worst case crashing.
- **Assuming tests catch `async void` exceptions.** xUnit's test runner doesn't observe the Task because there is none — the test can pass while the async part silently failed.
- **Using `async void` as a lazy shortcut for interface methods.** You cannot implement `interface IHandler { Task HandleAsync(); }` with `async void` — the signatures are incompatible and the compiler rejects it.
- **Calling `async void` methods on interfaces and expecting polymorphic behavior.** If a derived class overrides an event handler as `async void`, the base class `virtual void OnEvent()` does not track the async work — the override may complete "instantly" from the base class's perspective.

## References

- [Async/Await Best Practices — Stephen Cleary (MSDN)](https://learn.microsoft.com/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [AsyncVoidMethodBuilder — .NET Runtime GitHub](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Runtime/CompilerServices/AsyncVoidMethodBuilder.cs)
- [VSTHRD100 Avoid async void — Microsoft.VisualStudio.Threading.Analyzers](https://github.com/microsoft/vs-threading/blob/main/doc/analyzers/VSTHRD100.md)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: event-memory-leaks.md](./event-memory-leaks.md)
