# Task vs ValueTask

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `Task`, `ValueTask`, `allocation`, `async`, `performance`

## Question

> What is `ValueTask<T>` and when should you use it instead of `Task<T>`? What are the restrictions and pitfalls of `ValueTask`?

Also asked as:
- "Why was `ValueTask<T>` introduced if `Task<T>` already exists?"
- "Can I always replace `Task<T>` with `ValueTask<T>` for better performance?"

## Short Answer

`ValueTask<T>` is a struct-based awaitable that avoids a heap allocation when the operation completes synchronously (the hot path). `Task<T>` always allocates at least one object on the heap. For methods that frequently return a cached or synchronously-available result, `ValueTask<T>` can eliminate significant GC pressure. However, `ValueTask` has strict usage rules: it may be awaited **only once**, must not be awaited after it has already been awaited, and must not be accessed concurrently — violations cause undefined behavior, not a clean exception.

## Detailed Explanation

### Why `Task<T>` Always Allocates

`Task<T>` is a class. Every call to an `async Task<T>` method creates a new `Task<T>` object on the heap, even if the result is immediately available. The GC cost is small per call but adds up in high-throughput scenarios:

```csharp
// Even though the value is cached, this always allocates a Task<int>
public Task<int> GetCachedValueAsync() => Task.FromResult(_cachedValue);
```

`Task.FromResult` creates a new `Task<int>` wrapper each time (before .NET 6; .NET 6+ caches common values like `true/false`, `-1/0/1` internally).

### What `ValueTask<T>` Stores

`ValueTask<T>` is a discriminated union struct holding **either**:
- A `T` result directly (zero allocation if already complete), **or**
- A reference to a `Task<T>` (when the async path was taken), **or**
- A reference to an `IValueTaskSource<T>` (for reuse/pooling via `ManualResetValueTaskSourceCore<T>`).

```
struct ValueTask<T>
{
    object? _obj;      // null (synchronous), Task<T>, or IValueTaskSource<T>
    T _result;         // valid when _obj is null (synchronous completion)
    short _token;      // version check for IValueTaskSource
}
```

### When `ValueTask<T>` Wins

The allocation saving only materializes when the method **frequently completes synchronously**:

```csharp
private Dictionary<int, User> _cache = new();

// Hot path: cache hit → no Task allocation
public ValueTask<User?> GetUserAsync(int id)
{
    if (_cache.TryGetValue(id, out var user))
        return ValueTask.FromResult<User?>(user);          // zero allocation ✅

    return new ValueTask<User?>(FetchFromDbAsync(id));     // async path, allocates Task
}
```

If the method is **always async** (always truly awaits I/O), `ValueTask` provides no benefit and just adds complexity — use `Task<T>` instead.

### The Rules (Strict)

> These rules are enforced by convention, not the compiler. Violations produce **incorrect behavior**, not compile errors.

1. **Await only once.** Once a `ValueTask<T>` has been awaited, its result is consumed. Awaiting again is undefined.
2. **Do not await concurrently.** A `ValueTask<T>` is not thread-safe for concurrent `await`.
3. **Do not call `.Result` after awaiting.** The backing source may have been reset.
4. **Do not cache and reuse the `ValueTask` itself.** Only cache the *result*, not the task.
5. **Convert to `Task` if you need to share or await multiple times:** `var task = myValueTask.AsTask();`

### `IValueTaskSource<T>` — Advanced Pooling

Libraries like `System.IO.Pipelines` implement `IValueTaskSource<T>` so that the same object can be reused across many async operations (object pool). This achieves **zero allocation even on the async path**. This level of complexity is only justified in extremely high-performance infrastructure code (e.g., Kestrel's HTTP parser).

### `ValueTask` (non-generic) for `async void`-free Patterns

`ValueTask` (no type arg) is the non-generic form, equivalent to `Task` for void returns. Use it in `IAsyncDisposable.DisposeAsync()` and `IAsyncEnumerator<T>.MoveNextAsync()` (BCL interfaces use it for that reason).

### Decision Guide

| Scenario | Use |
|---|---|
| Method almost always completes synchronously (cache, in-memory) | `ValueTask<T>` |
| Method always does real async I/O | `Task<T>` |
| Public interface method shared across many callers | `Task<T>` (simpler contract) |
| High-throughput infrastructure (Kestrel, Pipelines) | `ValueTask<T>` + `IValueTaskSource<T>` |
| Method result may be awaited multiple times | `Task<T>` (or `.AsTask()`) |
| `IAsyncDisposable`, `IAsyncEnumerator` | `ValueTask` / `ValueTask<T>` (BCL convention) |

## Code Example

```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public class UserRepository
{
    private readonly Dictionary<int, string> _cache = new();

    // ✅ ValueTask: avoids Task allocation on cache-hit (hot path)
    public ValueTask<string?> GetNameAsync(int id)
    {
        if (_cache.TryGetValue(id, out string? name))
            return ValueTask.FromResult<string?>(name);    // no heap allocation

        return new ValueTask<string?>(LoadFromDbAsync(id)); // async path → Task
    }

    private async Task<string?> LoadFromDbAsync(int id)
    {
        await Task.Delay(10);   // simulate DB
        string name = $"User_{id}";
        _cache[id] = name;
        return name;
    }
}

// --- Correct usage ---
var repo = new UserRepository();

// First call: async (no cache)
string? name1 = await repo.GetNameAsync(1);
Console.WriteLine(name1);  // User_1

// Second call: synchronous cache hit — no Task allocated
string? name2 = await repo.GetNameAsync(1);
Console.WriteLine(name2);  // User_1

// --- WRONG: await twice (undefined behavior) ---
// ValueTask<string?> vt = repo.GetNameAsync(1);
// string? r1 = await vt;   // first await: OK
// string? r2 = await vt;   // ❌ UNDEFINED — don't do this

// --- Correct: convert to Task when you need to await multiple times ---
ValueTask<string?> vt = repo.GetNameAsync(2);
Task<string?> task = vt.AsTask();   // safe to await multiple times or share
string? a = await task;
string? b = await task;             // ✅ Task can be awaited multiple times

// --- IAsyncDisposable uses ValueTask by convention ---
public class ManagedResource : IAsyncDisposable
{
    public ValueTask DisposeAsync()
    {
        // Synchronous cleanup: ValueTask avoids allocation
        Cleanup();
        return ValueTask.CompletedTask;
    }

    private void Cleanup() => Console.WriteLine("Cleaned up");
}

await using var r = new ManagedResource();   // calls DisposeAsync at end of scope
```

## Common Follow-up Questions

- How does `ManualResetValueTaskSourceCore<T>` enable object pooling for `IValueTaskSource<T>`?
- What is `PoolingAsyncValueTaskMethodBuilder` introduced in .NET 6 — how does it change async method allocation?
- Why do BCL interfaces like `IAsyncEnumerator<T>` return `ValueTask<bool>` from `MoveNextAsync()`?
- How can you measure whether `ValueTask<T>` actually reduces allocations in your specific scenario (BenchmarkDotNet, allocation counters)?
- What is the risk of using `ValueTask<T>` across a public API boundary that you don't control?

## Common Mistakes / Pitfalls

- **Awaiting a `ValueTask<T>` more than once.** The second `await` may read garbage data or throw — there is no safe double-await. Always call `.AsTask()` if multiple awaits are needed.
- **Using `ValueTask<T>` when the method is never synchronous.** It adds struct overhead and complexity with no benefit. Profile before switching.
- **Accessing `.Result` on a `ValueTask<T>` without awaiting first.** Unlike `Task<T>.Result` (which blocks), `ValueTask<T>.Result` is only valid after the value task has completed synchronously. On the async path, it returns undefined data.
- **Storing a `ValueTask<T>` in a field for later use.** `ValueTask` is designed for immediate consumption. If you need to pass it around or store it, convert to `Task<T>` with `.AsTask()`.
- **Forgetting that `IValueTaskSource<T>` pooled tasks reset after completion.** Accessing any member after `SetResult` has been called and the source reused yields incorrect results.

## References

- [Understanding the Whys, Whats, and Whens of ValueTask — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/)
- [ValueTask<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.valuetask-1)
- [IValueTaskSource<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.sources.ivaluetasksource-1)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: task-vs-thread.md](./task-vs-thread.md)
