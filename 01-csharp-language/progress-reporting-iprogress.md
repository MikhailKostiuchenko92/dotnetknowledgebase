# Progress Reporting with IProgress<T>

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `IProgress<T>`, `Progress<T>`, `async`, `UI-thread`, `reporting`

## Question

> How do you report progress from an async background operation back to the UI or calling code? What is `IProgress<T>` and how does `Progress<T>` ensure updates run on the correct thread?

Also asked as:
- "Why should you use `IProgress<T>` instead of directly raising an event or calling a callback from a background task?"
- "What threading guarantee does `Progress<T>` provide?"

## Short Answer

`IProgress<T>` is a single-method interface (`void Report(T value)`) that decouples the worker from how progress is displayed. The concrete `Progress<T>` implementation captures the `SynchronizationContext` (or `TaskScheduler`) at construction time and marshals each `Report` call back to that context — typically the UI thread. The worker code sees only the `IProgress<T>` abstraction and never needs to know about threading. Pass `null` for `IProgress<T>` when the caller doesn't need progress.

## Detailed Explanation

### The Problem Without `IProgress<T>`

A naive approach — calling a UI-updating callback directly from a background thread:

```csharp
// Worker uses a raw Action:
async Task ProcessAsync(Action<int> onProgress)
{
    for (int i = 0; i < 100; i++)
    {
        await Task.Delay(10);
        onProgress(i);   // ❌ called on thread pool thread — UI access crashes in WPF/WinForms
    }
}
```

The callback runs on a thread pool thread. Any `TextBox.Text = ...` or `ProgressBar.Value = ...` call inside it throws `InvalidOperationException` in WPF/WinForms because UI elements are not thread-safe.

### `IProgress<T>` Interface

```csharp
public interface IProgress<in T>
{
    void Report(T value);
}
```

Minimal, contravariant (`in T`). The worker only calls `Report`; it never knows what the implementation does.

### `Progress<T>` — The Standard Implementation

`Progress<T>` captures `SynchronizationContext.Current` (or `TaskScheduler.Current` if no SC) at **construction time** and uses it to dispatch each `Report` call:

```csharp
// Created on the UI thread → captures the UI SynchronizationContext
var progress = new Progress<int>(percent =>
{
    progressBar.Value = percent;   // ✅ always runs on UI thread
});

await ProcessAsync(progress);   // pass to background work
```

Even if `Report(value)` is called from a thread pool thread inside the background operation, `Progress<T>` posts the callback to the captured SC — safe to update UI.

### Threading Guarantee Details

- If `SynchronizationContext.Current` is **non-null** at construction: `Report` posts via `SC.Post`.
- If `SynchronizationContext.Current` is **null** (e.g., constructed on a thread pool thread): `Report` queues to `ThreadPool.QueueUserWorkItem` — no context marshalling.
- **Implication:** Always construct `Progress<T>` on the thread that should receive progress (usually the UI thread or the request thread).

### Using `IProgress<T>` in Method Signatures

Make the parameter optional with a `null` default — workers check before calling:

```csharp
public async Task ImportDataAsync(
    Stream source,
    IProgress<ImportProgress>? progress = null,
    CancellationToken ct = default)
{
    int total = EstimateCount(source);
    int done = 0;

    await foreach (var record in ReadRecordsAsync(source, ct))
    {
        await SaveAsync(record, ct);
        done++;
        progress?.Report(new ImportProgress(done, total, record.Id));
    }
}
```

Callers that don't need progress simply omit the argument. Callers that do provide a `Progress<T>` instance.

### `ProgressChangedEventArgs` Pattern (Legacy)

`BackgroundWorker` and the APM pattern used `ProgressChanged` events. `IProgress<T>` is the modern equivalent — cleaner, strongly-typed, and with no event subscription/unsubscription lifecycle.

### `IProgress<T>` in Console Apps (No SynchronizationContext)

In console apps, `Progress<T>` constructed on the main thread has `SynchronizationContext.Current == null`, so `Report` runs on the thread pool. For console apps this is usually fine since there is no UI thread requirement; all output is thread-safe.

### Custom `IProgress<T>` Implementations

You're not limited to `Progress<T>`. Implement the interface for:
- Accumulating progress into a list for testing.
- Throttling reports (only report every N items).
- Relaying to multiple subscribers.

```csharp
public class ThrottledProgress<T>(IProgress<T> inner, int every) : IProgress<T>
{
    private int _count;
    public void Report(T value)
    {
        if (Interlocked.Increment(ref _count) % every == 0)
            inner.Report(value);
    }
}
```

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

public record DownloadProgress(int FilesDone, int FilesTotal, string CurrentFile);

// --- Worker: accepts IProgress<T>, never touches threading directly ---
static async Task DownloadFilesAsync(
    string[] urls,
    IProgress<DownloadProgress>? progress = null,
    CancellationToken ct = default)
{
    for (int i = 0; i < urls.Length; i++)
    {
        ct.ThrowIfCancellationRequested();
        await Task.Delay(30, ct);   // simulate download

        // Report AFTER each download — null-safe
        progress?.Report(new DownloadProgress(i + 1, urls.Length, urls[i]));
    }
}

// --- Console usage (no SynchronizationContext) ---
var consoleProgress = new Progress<DownloadProgress>(p =>
    Console.WriteLine($"[{p.FilesDone}/{p.FilesTotal}] {p.CurrentFile}"));

var urls = new[] { "a.zip", "b.zip", "c.zip", "d.zip" };
await DownloadFilesAsync(urls, consoleProgress);

// Output (runs on thread pool in console, but Progress<T> still invokes the callback):
// [1/4] a.zip
// [2/4] b.zip
// [3/4] c.zip
// [4/4] d.zip

// --- No-progress caller: simply omit the argument ---
await DownloadFilesAsync(urls);   // progress = null, no reporting overhead

// --- Throttled progress: report every 2 items ---
public class EveryNProgress<T>(IProgress<T> inner, int n) : IProgress<T>
{
    private int _count;
    public void Report(T value)
    {
        if (Interlocked.Increment(ref _count) % n == 0)
            inner.Report(value);
    }
}

var throttled = new EveryNProgress<DownloadProgress>(consoleProgress, 2);
await DownloadFilesAsync(urls, throttled);
// Reports only for items 2 and 4

// --- Testing: capture reported values without side effects ---
var captured = new System.Collections.Generic.List<DownloadProgress>();
var testProgress = new Progress<DownloadProgress>(p => captured.Add(p));
await DownloadFilesAsync(urls, testProgress);
// Wait briefly for Progress<T> to dispatch callbacks (it's async internally)
await Task.Delay(50);
Console.WriteLine($"Captured {captured.Count} progress reports");
```

## Common Follow-up Questions

- Why does `Progress<T>` use `Post` (asynchronous dispatch) rather than `Send` (synchronous) for marshalling?
- How do you unit-test a method that takes `IProgress<T>` — how do you verify reported values?
- How does `IProgress<T>` interact with `CancellationToken` — should you stop reporting after cancellation?
- When would you implement a custom `IProgress<T>` to aggregate or filter progress reports?
- How is progress reporting different in Blazor WebAssembly where there is no traditional `SynchronizationContext`?

## Common Mistakes / Pitfalls

- **Constructing `Progress<T>` on a thread pool thread.** If created outside the UI thread (e.g., inside `Task.Run`), `SynchronizationContext.Current` is `null` and the callback runs on the thread pool — potentially crashing on UI access. Always construct `Progress<T>` on the UI thread before starting background work.
- **Using a raw `Action<T>` callback instead of `IProgress<T>`.** The raw action runs on whatever thread calls it. `IProgress<T>` explicitly communicates that marshalling is handled; `Action<T>` has no such contract.
- **Reporting inside a `try/catch` after cancellation.** After catching `OperationCanceledException`, the operation is done — reporting additional progress is meaningless and potentially confusing. Stop reporting when cancelled.
- **Expecting progress reports to arrive synchronously.** `Progress<T>.Report` is fire-and-forget (`Post`, not `Send`). Reports may arrive slightly after the corresponding work completes, especially under load.
- **Not null-checking `IProgress<T>` before calling `Report`.** Callers that don't care about progress pass `null`. Always use the null-conditional: `progress?.Report(value)`.

## References

- [IProgress<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.iprogress-1)
- [Progress<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.progress-1)
- [Async in 4.5: Enabling Progress and Cancellation in Async APIs — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/async-in-4-5-enabling-progress-and-cancellation-in-async-apis/)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: cancellation-tokens.md](./cancellation-tokens.md)
- [See: synchronization-context.md](./synchronization-context.md)
