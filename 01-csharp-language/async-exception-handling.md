# Async Exception Handling

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `async`, `exception`, `AggregateException`, `Task`, `unawaited`

## Question

> How and where do exceptions surface in async methods? What happens to an exception thrown in an unawaited `Task`, and how does exception handling differ between `async Task` and `async void`?

Also asked as:
- "If I don't `await` a `Task`, what happens to an exception thrown inside it?"
- "How does `AggregateException` behave when you `await` a task vs calling `.Result`?"

## Short Answer

Exceptions thrown inside an `async Task` method are captured and stored in the returned `Task`. They surface only when the task is observed — via `await`, `.Result`, `.Wait()`, or inspecting `.Exception`. If a task is never observed, the exception fires `TaskScheduler.UnobservedTaskException` on finalization (in .NET 4.5+ this no longer crashes the process by default, but the exception is silently lost). In `async void` methods, exceptions cannot be observed at all and are re-thrown on the `SynchronizationContext`, typically crashing the app.

## Detailed Explanation

### How `async Task` Captures Exceptions

When a method is `async Task`, the compiler wraps the body in a try/catch. Any unhandled exception is stored in the `Task` via `AsyncTaskMethodBuilder.SetException()`. The task transitions to `Faulted` state.

```
async method throws → Task.Status = Faulted
                    → Task.Exception = AggregateException { InnerException = original }
```

The exception is inert until the task is observed.

### Observing the Exception

**Via `await`:**
```csharp
try
{
    await FaultingAsync();
}
catch (InvalidOperationException ex)
{
    // ✅ catches the original exception (unwrapped from AggregateException)
}
```

`await` unwraps `AggregateException` and re-throws the first `InnerException` directly. This is the most natural pattern.

**Via `.Result` or `.Wait()`:**
```csharp
try
{
    task.Wait();              // or: var v = task.Result;
}
catch (AggregateException ae)
{
    // ❌ Must unwrap manually — exceptions are wrapped
    ae.Handle(ex => ex is InvalidOperationException);
    // or: ae.InnerException
}
```

`.Result`/`.Wait()` wrap the exception in `AggregateException`. This is a common friction point when mixing sync and async code.

### `GetAwaiter().GetResult()` — Cleaner Sync Unwind

```csharp
// Throws the original exception directly (not wrapped), same as await:
task.GetAwaiter().GetResult();
```

Use this when you must block synchronously (rare cases) and want the same exception shape as `await`.

### `Task.WhenAll` — All Exceptions Available

`await Task.WhenAll(t1, t2, t3)` re-throws only the first exception. To see all:

```csharp
var all = Task.WhenAll(t1, t2, t3);
try { await all; }
catch
{
    foreach (var ex in all.Exception!.InnerExceptions)
        _logger.LogError(ex, "Task failed");
}
```

### Unawaited Tasks — Silent Exception Loss

```csharp
_ = FaultingAsync();   // task discarded; exception stored in GC-collected Task
```

When the `Task` is garbage-collected, its finalizer checks `IsCompleted` and whether the exception was observed. If not, it raises `TaskScheduler.UnobservedTaskException`.

In .NET 4.5+, this event is **informational** — the process is not terminated by default (unlike .NET 4.0). You can subscribe to log these:

```csharp
TaskScheduler.UnobservedTaskException += (_, e) =>
{
    _logger.LogError(e.Exception, "Unobserved task exception");
    e.SetObserved();   // mark as handled to suppress further propagation
};
```

> **Warning:** Relying on `UnobservedTaskException` as your error handling strategy is wrong. The exception is raised non-deterministically (at GC finalization). Always ensure tasks are awaited or have explicit exception handling.

### `async void` — Unobservable Exceptions

```csharp
async void DoStuff()
{
    await Task.Delay(10);
    throw new Exception("boom");   // goes to SynchronizationContext → crashes app
}

try { DoStuff(); } catch { }   // NEVER catches the exception — runs after return
```

The exception is re-thrown via `SynchronizationContext.Post` — outside any `try/catch` you write. In WPF/WinForms this triggers `Application.DispatcherUnhandledException`; in console apps it crashes immediately.

### Exception Handling Pattern for `async` Methods

```csharp
public async Task<Result> ProcessAsync(Command cmd, CancellationToken ct)
{
    try
    {
        var data = await _repo.LoadAsync(cmd.Id, ct);
        var result = await _service.TransformAsync(data, ct);
        return result;
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        _logger.LogInformation("Processing cancelled");
        throw;   // propagate cancellation — don't swallow
    }
    catch (DbException ex)
    {
        _logger.LogError(ex, "Database error during processing");
        throw new ServiceException("Failed to process command", ex);   // wrap and re-throw
    }
    // Let unexpected exceptions propagate naturally — don't catch Exception unless logging
}
```

### `finally` in Async Methods

`finally` blocks run correctly in async methods, including when the method is cancelled:

```csharp
async Task WithCleanupAsync()
{
    await AcquireResourceAsync();
    try { await DoWorkAsync(); }
    finally { await ReleaseResourceAsync(); }   // runs even if DoWorkAsync throws
}
```

`using` and `await using` are the preferred patterns for resource cleanup.

## Code Example

```csharp
using System;
using System.Threading.Tasks;

static async Task<int> FaultingAsync(bool fault)
{
    await Task.Delay(10);
    if (fault) throw new InvalidOperationException("Something went wrong");
    return 42;
}

// --- await: exception unwrapped ---
try
{
    int v = await FaultingAsync(fault: true);
}
catch (InvalidOperationException ex)
{
    Console.WriteLine($"Caught: {ex.Message}");   // ✅ direct exception type
}

// --- .Result: wrapped in AggregateException ---
var t = FaultingAsync(fault: true);
try { _ = t.Result; }
catch (AggregateException ae)
{
    Console.WriteLine($"AggregateException inner: {ae.InnerException!.Message}");
}

// --- GetAwaiter().GetResult(): same as await for exception shape ---
var t2 = FaultingAsync(fault: true);
try { t2.GetAwaiter().GetResult(); }
catch (InvalidOperationException ex)
{
    Console.WriteLine($"GetResult: {ex.Message}");   // ✅ unwrapped
}

// --- WhenAll: capture all failures ---
var all = Task.WhenAll(FaultingAsync(true), FaultingAsync(true), FaultingAsync(false));
try { await all; }
catch
{
    foreach (var ex in all.Exception!.InnerExceptions)
        Console.WriteLine($"  WhenAll failure: {ex.Message}");
}

// --- Unobserved task exception subscription ---
TaskScheduler.UnobservedTaskException += (_, e) =>
{
    Console.WriteLine($"Unobserved: {e.Exception.InnerException?.Message}");
    e.SetObserved();
};

// Fire a faulting task and discard it (bad practice — for illustration only)
_ = FaultingAsync(fault: true);
GC.Collect();
GC.WaitForPendingFinalizers();   // triggers UnobservedTaskException
```

## Common Follow-up Questions

- How does `ExceptionDispatchInfo` preserve the original stack trace when re-throwing exceptions across threads?
- How do you propagate multiple exceptions from a parallel fan-out without losing any of them?
- What is the difference between `Task.Status == Faulted` and `Task.Status == Canceled`?
- How does exception handling in `IAsyncEnumerable<T>` / `await foreach` work compared to a regular `await`?
- How do you write global exception handling for unobserved task exceptions in an ASP.NET Core application?

## Common Mistakes / Pitfalls

- **Discarding tasks without observing their exceptions.** `_ = FaultingAsync()` drops the exception silently. At minimum, attach a `.ContinueWith` that logs on fault.
- **Catching `AggregateException` when using `await`.** `await` unwraps the exception, so catching `AggregateException` after `await` will never match — catch the actual exception type.
- **Swallowing `OperationCanceledException`.** Catching and ignoring cancellation makes it impossible for callers to know the operation was cancelled and may leave the system in an inconsistent state. Always re-throw cancellation.
- **Not re-throwing in `catch` when just logging.** Log the exception, then `throw;` (not `throw ex;` — preserve the stack trace). Swallowing exceptions makes bugs invisible in production.
- **Assuming `finally` doesn't run on cancellation.** It always runs. `finally` combined with `await` inside is perfectly valid in C# — the compiler handles it correctly.

## References

- [Exception Handling in Async Methods — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios#handling-exceptions-with-await)
- [TaskScheduler.UnobservedTaskException — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskscheduler.unobservedtaskexception)
- [AggregateException — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.aggregateexception)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: async-void-pitfalls.md](./async-void-pitfalls.md)
- [See: task-whenall-vs-whenany.md](./task-whenall-vs-whenany.md)
