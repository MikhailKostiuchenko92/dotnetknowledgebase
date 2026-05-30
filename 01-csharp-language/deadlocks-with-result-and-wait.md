# Deadlocks with .Result and .Wait()

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `deadlock`, `.Result`, `.Wait()`, `SynchronizationContext`, `async`, `blocking`

## Question

> How can calling `.Result` or `.Wait()` on a `Task` inside an async call chain cause a deadlock? How do you diagnose and fix it?

Also asked as:
- "Walk me through exactly why `asyncMethod().Result` deadlocks in ASP.NET (classic) or WPF."
- "Is it ever safe to call `.Result` on a Task, and if so, when?"

## Short Answer

The classic deadlock occurs when a single-threaded `SynchronizationContext` (WPF's dispatcher, classic ASP.NET's request context) is active: the calling thread blocks via `.Result`/`.Wait()` while holding the context, and the `async` method's continuation tries to resume by posting back to that same context — which is blocked. Both sides wait on each other forever. The root fix is always to `await` instead of blocking. If blocking is unavoidable (e.g., in a synchronous method you cannot change), run the async work outside the context using `Task.Run`.

## Detailed Explanation

### Step-by-Step Deadlock Anatomy

```
1. UI/request thread enters GetData()
2. GetData() calls asyncMethod().Result → blocks the thread, holding the SynchronizationContext
3. asyncMethod() hits its first await → suspends; marks continuation to resume on the captured SC
4. awaited I/O completes on a thread pool thread
5. Continuation is posted to SC: SC.Post(continuation)
6. SC cannot run the continuation — it requires the UI/request thread which is blocked at step 2
7. DEADLOCK: thread waits for task, task waits for thread
```

```csharp
// WPF button handler — DEADLOCK
private void Button_Click(object sender, RoutedEventArgs e)
{
    var data = LoadDataAsync().Result;   // ← blocks UI thread while holding DispatcherSC
    Label.Content = data;
}

private async Task<string> LoadDataAsync()
{
    await Task.Delay(500);              // ← tries to resume on DispatcherSC — blocked
    return "done";
}
```

### Why ASP.NET Core Does Not Deadlock This Way

ASP.NET Core installs **no `SynchronizationContext`** (it's `null`). Without a context, continuations run on any available thread pool thread — there is no single-threaded gate to dead-lock against. However, blocking with `.Result` **still harms throughput** by wasting a thread pool thread that could be serving other requests.

> **Important:** `.Result` being "safe" in ASP.NET Core is not a reason to use it. Thread pool starvation under load is a real concern — always `await` properly.

### When Is `.Result` Actually Safe?

| Scenario | Safe? | Reason |
|---|---|---|
| Task is already completed (`IsCompleted == true`) | ✅ | No suspension, no context needed |
| Inside `Task.Run` lambda | ✅ | `Task.Run` clears SC; continuation uses thread pool |
| In a console app with no SC | ✅ | No context to deadlock on |
| In a synchronous test helper with no SC | ✅ | Same as console |
| In the main thread of an ASP.NET Core app | ⚠️ | Safe from deadlock; risky for starvation |
| WPF / WinForms UI thread | ❌ | `DispatcherSC` → deadlock |
| Classic ASP.NET request thread | ❌ | `AspNetSynchronizationContext` → deadlock |

### Fix 1: Await All the Way (Preferred)

The only correct general fix: `async` should propagate from the innermost method to the outermost caller. If the signature cannot change, that is an architectural problem to address.

```csharp
// Fixed WPF button handler:
private async void Button_Click(object sender, RoutedEventArgs e)
{
    var data = await LoadDataAsync();   // ✅ UI thread freed while awaiting
    Label.Content = data;
}
```

### Fix 2: `Task.Run` Wrapper (Bridge Pattern)

Use when you cannot make the calling method `async` (e.g., a constructor, `Main` before top-level statements, a legacy sync interface):

```csharp
// Runs the async method on the thread pool (no SC), then blocks the calling thread
string result = Task.Run(() => LoadDataAsync()).Result;
```

`Task.Run` clears `SynchronizationContext.Current` inside its body, so `LoadDataAsync` continuations resume on the thread pool — no context to deadlock on.

> **Warning:** The `Task.Run` bridge is a code smell in application logic. It burns a thread pool thread and a calling thread simultaneously. Use it sparingly and document why.

### Fix 3: `ConfigureAwait(false)` in Library Code (Defense)

If the async method is in a **library** and uses `ConfigureAwait(false)` on every `await`, its continuations never try to re-enter the caller's `SynchronizationContext`, so the blocking caller's `.Result` can't deadlock:

```csharp
private async Task<string> LoadDataAsync()
{
    await Task.Delay(500).ConfigureAwait(false);   // continuation on pool, not SC
    return "done";
}
// Now LoadDataAsync().Result in WPF no longer deadlocks — but it's still bad practice
```

This is why library code should always use `ConfigureAwait(false)`. It's defensive; it doesn't mean callers should block.

### Diagnosing a Deadlock

Symptoms: application hangs, response timeout, UI freezes. Diagnosis steps:

1. **Attach a debugger** → Threads window → look for threads blocked in `Task.Wait` or `Task.Result`.
2. **`dotnet-dump` / WinDbg** → `!dumpasync` → shows the async call chain and where tasks are waiting.
3. **ThreadPool starvation indicator:** `ThreadPool.GetAvailableThreads()` returning 0 — all pool threads blocked.

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

// Simulate a single-threaded SynchronizationContext
public class SingleThreadedContext : SynchronizationContext
{
    public override void Post(SendOrPostCallback d, object? state)
    {
        // In real WPF/classic ASP.NET this posts to the UI/request thread.
        // Here we simulate it by running synchronously on the current thread.
        Send(d, state);
    }
}

// --- DEADLOCK demonstration (do not run outside educational context) ---
static void DeadlockDemo()
{
    var ctx = new SingleThreadedContext();
    SynchronizationContext.SetSynchronizationContext(ctx);

    try
    {
        // This deadlocks: blocks the thread that holds the context;
        // the continuation tries to Post back to the same context.
        // string result = SlowAsync().Result;  // ← DEADLOCK

        Console.WriteLine("(deadlock skipped for safety)");
    }
    finally
    {
        SynchronizationContext.SetSynchronizationContext(null);
    }
}

static async Task<string> SlowAsync()
{
    await Task.Delay(100);   // captures the SingleThreadedContext
    return "done";
}

// --- FIX 1: Always await ---
static async Task FixWithAwaitAsync()
{
    string result = await SlowAsync();   // ✅ no deadlock
    Console.WriteLine(result);
}

// --- FIX 2: Task.Run bridge (when async propagation is impossible) ---
static void FixWithTaskRun()
{
    // Task.Run clears SynchronizationContext inside its body
    string result = Task.Run(() => SlowAsync()).GetAwaiter().GetResult();
    Console.WriteLine(result);   // ✅ no deadlock
}

// --- When .Result IS safe: already-completed task ---
static void SafeResult()
{
    Task<int> completed = Task.FromResult(42);
    Console.WriteLine(completed.Result);   // ✅ IsCompleted = true, no suspension
}

await FixWithAwaitAsync();
FixWithTaskRun();
SafeResult();
```

## Common Follow-up Questions

- What is the difference between `.Result`, `.GetAwaiter().GetResult()`, and `.Wait()` — do they behave differently?
- How does thread pool starvation differ from a context deadlock, and can you have both at once?
- How do you identify a deadlock in a production application using `dotnet-dump` or Visual Studio?
- Why does `Task.Run(() => asyncMethod()).Result` avoid the context deadlock but still risk starvation?
- How does the `Nito.AsyncEx.AsyncContext` allow synchronously waiting on async code without deadlock?

## Common Mistakes / Pitfalls

- **Using `.Result` in a constructor to "initialize" asynchronously.** Constructors cannot be `async`. The fix is a static async factory method or lazy initialization with `Lazy<Task<T>>`.
- **Assuming `.GetAwaiter().GetResult()` is safer than `.Result`.** They are behaviorally identical for deadlock purposes. The only difference: `.GetAwaiter().GetResult()` unwraps `AggregateException` and throws the inner exception directly, which is marginally more convenient.
- **Adding `Task.Run` wrappers in hot paths.** The bridge pattern wastes two threads simultaneously. Refactor the call site to be properly async instead.
- **Thinking the deadlock is caused by `async`/`await` itself.** The cause is the single-threaded context combined with blocking. `async`/`await` is the victim, not the culprit.
- **Believing `ConfigureAwait(false)` throughout the async method makes `.Result` safe.** It prevents the specific SC deadlock, but only as long as the library is consistent. One missed `ConfigureAwait(false)` anywhere in the chain reintroduces the risk.

## References

- [Don't Block on Async Code — Stephen Cleary (blog)](https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html)
- [Async/Await Best Practices — Stephen Cleary (MSDN)](https://learn.microsoft.com/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [ConfigureAwait FAQ — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/configureawait-faq/)
- [See: synchronization-context.md](./synchronization-context.md)
- [See: configure-await-false.md](./configure-await-false.md)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
