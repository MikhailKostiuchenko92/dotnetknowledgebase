# ConfigureAwait(false)

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `ConfigureAwait`, `SynchronizationContext`, `deadlock`, `library`, `async`

## Question

> What does `ConfigureAwait(false)` do, and when should you use it? Has the advice changed with ASP.NET Core and .NET 6+?

Also asked as:
- "Why does a library need `ConfigureAwait(false)` but an ASP.NET Core app doesn't?"
- "How does `ConfigureAwait(false)` prevent deadlocks in ASP.NET (classic) or WPF?"

## Short Answer

`ConfigureAwait(false)` tells the awaiter not to capture the current `SynchronizationContext` when scheduling the continuation. In environments that have a single-threaded or thread-affine context (classic ASP.NET, WPF, WinForms), omitting it can cause deadlocks when code blocks synchronously on an async method. In **library code**, always use `ConfigureAwait(false)` to avoid burdening callers with context marshalling overhead and to prevent deadlocks they can't control. In **ASP.NET Core application code**, there is no `SynchronizationContext` by default, so `ConfigureAwait(false)` has no effect — but it still doesn't hurt.

## Detailed Explanation

### What Happens Without `ConfigureAwait(false)`

When a `SynchronizationContext` is active (e.g., WPF's dispatcher, or classic ASP.NET's `AspNetSynchronizationContext`), the default awaiter captures it at the `await` point. After the awaited operation completes, the continuation is **posted back** to that context before running.

```
Thread A (UI/request thread) → calls async method
  → suspends at await
  → operation completes on thread pool thread
  → continuation posted back to the original SynchronizationContext
  → resumes on Thread A
```

For UI code this is desirable (UI updates must run on the UI thread). For library code it's unnecessary overhead and a deadlock risk.

### The Classic Deadlock Pattern

1. `SynchronizationContext` allows only one piece of code at a time (single-threaded context).
2. Application code calls `asyncMethod().Result` (or `.Wait()`), blocking Thread A while holding the context.
3. Inside `asyncMethod`, an `await` suspends and later tries to resume — but the continuation needs to post back to the context.
4. Thread A holds the context and is blocked waiting for the task. The task's continuation is waiting for the context. **Deadlock.**

```csharp
// WPF button handler — deadlock!
private void Button_Click(object sender, RoutedEventArgs e)
{
    var result = GetDataAsync().Result;   // blocks UI thread while holding dispatcher context
}

private async Task<string> GetDataAsync()
{
    await Task.Delay(100);           // tries to resume on UI dispatcher — blocked by .Result
    return "data";
}
```

**Fix option 1:** `await GetDataAsync()` instead of `.Result`.
**Fix option 2 (library defense):** `await Task.Delay(100).ConfigureAwait(false)` — continuation runs on thread pool, never tries to re-enter the context, deadlock eliminated.

### What `ConfigureAwait(false)` Does Internally

It returns a `ConfiguredTaskAwaitable` whose `GetAwaiter()` sets `continueOnCapturedContext = false`. The awaiter's `OnCompleted` skips context capturing:

```
Normal await:
  continuation → SynchronizationContext.Post(continuation) OR TaskScheduler.Schedule(continuation)

ConfigureAwait(false):
  continuation → ThreadPool.QueueUserWorkItem(continuation)  (bypasses context)
```

### ASP.NET Core — No `SynchronizationContext`

ASP.NET Core deliberately **removes** `SynchronizationContext` (it's `null` on the request thread). Without a context, the default awaiter's "post back to context" step is a no-op — the continuation runs on whatever thread pool thread is available. `ConfigureAwait(false)` therefore:
- Has no deadlock-prevention effect (there is no context to deadlock on).
- Provides no performance benefit from skipping context capture (nothing to capture).
- **Does not break anything** — it's simply a no-op for `SynchronizationContext`.

> **Practical guidance (2024+):**
> - Library code: still use `ConfigureAwait(false)` everywhere. Consumers may host in WPF, WinForms, or classic ASP.NET where the context matters.
> - ASP.NET Core app code: you can omit it. Adding it is harmless but adds visual noise.
> - `HttpContext`, `ILogger`, and other scoped services do **not** require the original thread in ASP.NET Core — they use `AsyncLocal<T>` which flows correctly regardless of `ConfigureAwait`.

### `.NET 6+ Analyzer` — `CA2007`

The Roslyn analyzer `CA2007` ("Consider calling ConfigureAwait on the awaited task") fires in library projects. You can suppress it project-wide with:

```xml
<!-- in .csproj — appropriate for ASP.NET Core apps -->
<PropertyGroup>
  <CA2007_SuppressInApplicationCode>true</CA2007_SuppressInApplicationCode>
</PropertyGroup>
```

Or use the `ConfigureAwait` global analyzer setting in an `.editorconfig`.

### `ConfigureAwait(ConfigureAwaitOptions)` — .NET 8

.NET 8 adds an overload with a flags enum for finer control:

```csharp
await task.ConfigureAwait(ConfigureAwaitOptions.ContinueOnCapturedContext   // default
                        | ConfigureAwaitOptions.SuppressThrowing);          // swallow exceptions
```

`SuppressThrowing` is useful for fire-and-forget patterns where you want completion without exception propagation.

## Code Example

```csharp
using System;
using System.Net.Http;
using System.Threading.Tasks;

// --- Library code: always use ConfigureAwait(false) ---
public static class DataLoader
{
    private static readonly HttpClient _http = new();

    public static async Task<string> FetchAsync(string url)
    {
        // ConfigureAwait(false) on every await in library code:
        string html = await _http.GetStringAsync(url).ConfigureAwait(false);
        // Post-processing runs on thread pool — no context marshalling overhead
        return html.Length > 100 ? html[..100] : html;
    }
}

// --- Application code (ASP.NET Core): ConfigureAwait(false) optional ---
// app/Controllers/DataController.cs
// Both of these are equivalent in ASP.NET Core:

public async Task<string> WithConfigure()
{
    return await DataLoader.FetchAsync("https://example.com").ConfigureAwait(false);
}

public async Task<string> WithoutConfigure()
{
    return await DataLoader.FetchAsync("https://example.com");  // same behavior
}

// --- Demonstrating deadlock in single-threaded context (illustrative) ---
// Never do this in a SynchronizationContext-bearing environment:
public static void DeadlockDemo_DoNotRun()
{
    // In WPF/WinForms/classic ASP.NET, calling .Result here deadlocks
    // string result = DataLoader.FetchAsync("https://example.com").Result; // ❌ DEADLOCK

    // Safe alternative — always await:
    // string result = await DataLoader.FetchAsync("https://example.com"); // ✅
}

// --- .NET 8 ConfigureAwaitOptions ---
static async Task FireAndForget(Task work)
{
    // Suppress exception and don't resume on captured context:
    await work.ConfigureAwait(
        ConfigureAwaitOptions.SuppressThrowing);   // .NET 8+
}
```

## Common Follow-up Questions

- How does `AsyncLocal<T>` behave across `ConfigureAwait(false)` — does the value still flow?
- Is `ConfigureAwait(false)` needed inside `IAsyncEnumerable<T>` / `await foreach`?
- What is `TaskScheduler.Current` and how does it interact with `ConfigureAwait`?
- How do you retrofit `ConfigureAwait(false)` into a large existing codebase — is there a Roslyn refactoring?
- What is the `Nito.AsyncEx.SynchronizationContextRemover` pattern and when is it used?

## Common Mistakes / Pitfalls

- **Assuming `ConfigureAwait(false)` is unnecessary in modern code.** It's unnecessary in ASP.NET Core apps, but **library code** is consumed in any host — always use it in libraries.
- **Using `ConfigureAwait(false)` only on the outer `await` but not inner ones.** If any inner `await` in the library method doesn't use `ConfigureAwait(false)`, the continuation of that inner await re-captures the context. Each `await` point is independent.
- **Thinking `ConfigureAwait(false)` fixes a `.Result`/`.Wait()` deadlock.** The deadlock is caused by the *blocking call* (`Result`/`Wait`), not by which awaiter the async code uses. The real fix is to use `await` instead of blocking. `ConfigureAwait(false)` in the library prevents the deadlock as a *defense*, but the caller should not be blocking at all.
- **Forgetting that `HttpContext.Items` and `ClaimsPrincipal` flow via `AsyncLocal`, not `SynchronizationContext`.** They survive `ConfigureAwait(false)` correctly in ASP.NET Core — no need to avoid `ConfigureAwait(false)` to preserve them.
- **Using `ConfigureAwait(false)` in an async event handler that updates UI.** After `ConfigureAwait(false)`, you are on a thread pool thread. Accessing `TextBox.Text = ...` will throw a cross-thread exception.

## References

- [ConfigureAwait FAQ — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/configureawait-faq/)
- [ConfiguredTaskAwaitable — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.configuredtaskawaitable)
- [ConfigureAwaitOptions (.NET 8) — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.configureawaitoptions)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: synchronization-context.md](./synchronization-context.md)
- [See: deadlocks-with-result-and-wait.md](./deadlocks-with-result-and-wait.md)
