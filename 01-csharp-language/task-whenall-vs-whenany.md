# Task.WhenAll vs Task.WhenAny

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `Task.WhenAll`, `Task.WhenAny`, `parallel-async`, `AggregateException`, `Task`

## Question

> What is the difference between `Task.WhenAll` and `Task.WhenAny`? How do exceptions aggregate in `WhenAll`, and what are common patterns for each?

Also asked as:
- "How do you run multiple async operations concurrently and wait for all of them?"
- "How do you implement a timeout on an async operation using `Task.WhenAny`?"

## Short Answer

`Task.WhenAll` returns a task that completes when **all** supplied tasks complete, collecting their results into an array. If any task faults, the returned task faults with an `AggregateException` containing all errors. `Task.WhenAny` returns a task that completes as soon as **any one** of the supplied tasks completes (successfully, faulted, or cancelled), returning that first-completing task as the result. Common uses: `WhenAll` for parallel fan-out, `WhenAny` for timeouts and racing.

## Detailed Explanation

### `Task.WhenAll` — All Must Complete

```csharp
Task<T>[] tasks = [ FetchUserAsync(1), FetchUserAsync(2), FetchUserAsync(3) ];
T[] results = await Task.WhenAll(tasks);
```

- All tasks start **concurrently** (they were already running before `WhenAll`).
- Returns `T[]` for `Task<T>` inputs, `Task` (void) for non-generic inputs.
- The result array preserves input order regardless of completion order.
- The returned task waits for **all** tasks, even if some fail.

### Exception Aggregation in `WhenAll`

When one or more tasks fault, `WhenAll` waits for **all** remaining tasks and then faults with an `AggregateException`. When you `await` the `WhenAll` task, C# unwraps the first exception only:

```csharp
try
{
    await Task.WhenAll(task1, task2, task3);   // task2 and task3 both threw
}
catch (Exception ex)
{
    // ex is only the FIRST exception from AggregateException
    Console.WriteLine(ex.Message);
}
```

To see **all** exceptions, inspect the `Task` directly before awaiting:

```csharp
var all = Task.WhenAll(task1, task2, task3);
try { await all; }
catch
{
    foreach (var ex in all.Exception!.InnerExceptions)
        Console.WriteLine(ex.Message);   // all errors
}
```

### `Task.WhenAny` — First One Wins

```csharp
Task<string> winner = await Task.WhenAny(task1, task2, task3);
```

- Returns the **`Task` object** that completed first, not its result.
- The other tasks continue running in the background (they are not cancelled).
- If the winning task faulted, `await winner` re-throws its exception.
- After `WhenAny`, you are responsible for the remaining tasks' lifetimes.

### Common Pattern 1: Timeout with `Task.WhenAny`

```csharp
static async Task<T> WithTimeoutAsync<T>(Task<T> operation, TimeSpan timeout)
{
    var delay = Task.Delay(timeout);
    Task completed = await Task.WhenAny(operation, delay);
    if (completed == delay)
        throw new TimeoutException();
    return await operation;   // re-await to propagate exception if it faulted
}
```

### Common Pattern 2: Process Results as They Arrive

```csharp
var tasks = new List<Task<string>> { FetchA(), FetchB(), FetchC() };
while (tasks.Count > 0)
{
    Task<string> finished = await Task.WhenAny(tasks);
    tasks.Remove(finished);
    try
    {
        string result = await finished;
        Console.WriteLine($"Got: {result}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Failed: {ex.Message}");
    }
}
```

> **Performance note:** `Task.WhenAny` in a tight loop over many tasks is O(n²) because each call re-registers continuations. For high-throughput streaming use `Channel<T>` or `IAsyncEnumerable<T>` instead.

### Common Pattern 3: Fan-Out with `WhenAll`

```csharp
// BAD — sequential, one at a time
foreach (var id in ids)
    results.Add(await FetchAsync(id));   // each waits for the previous

// GOOD — concurrent fan-out
var results = await Task.WhenAll(ids.Select(FetchAsync));
```

### Cancellation with `WhenAll` and `WhenAny`

`WhenAll` and `WhenAny` themselves don't accept `CancellationToken` — they just observe the tasks you pass in. Pass the token to each individual task:

```csharp
await Task.WhenAll(ids.Select(id => FetchAsync(id, ct)));
```

If you want to cancel the entire group when one fails, use `CancellationTokenSource` linked to each task.

### Comparison Table

| | `Task.WhenAll` | `Task.WhenAny` |
|---|---|---|
| Completes when | All tasks done | First task done |
| Result type | `T[]` (for `Task<T>`) | `Task<T>` (the winning task) |
| Faults when | Any task faults (after all finish) | Only if winning task faulted (and you await it) |
| Remaining tasks after completion | N/A — all done | Still running — you manage them |
| Typical use | Fan-out, parallel I/O | Timeout, racing, process-as-complete |

## Code Example

```csharp
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

static async Task<string> FetchAsync(string name, int delayMs, bool fail = false)
{
    await Task.Delay(delayMs);
    if (fail) throw new InvalidOperationException($"{name} failed");
    return $"Result from {name}";
}

// --- WhenAll: parallel fan-out ---
Console.WriteLine("=== WhenAll ===");
var t1 = FetchAsync("A", 100);
var t2 = FetchAsync("B", 200);
var t3 = FetchAsync("C", 150);

string[] results = await Task.WhenAll(t1, t2, t3);
foreach (var r in results) Console.WriteLine(r);
// Result from A, Result from C, Result from B  (but in input order: A, B, C)

// --- WhenAll: exception handling for all errors ---
Console.WriteLine("\n=== WhenAll with errors ===");
var bad1 = FetchAsync("X", 50,  fail: true);
var bad2 = FetchAsync("Y", 50,  fail: true);
var good = FetchAsync("Z", 100);

var allTask = Task.WhenAll(bad1, bad2, good);
try { await allTask; }
catch
{
    foreach (var ex in allTask.Exception!.InnerExceptions)
        Console.WriteLine($"  Error: {ex.Message}");
}

// --- WhenAny: timeout ---
Console.WriteLine("\n=== WhenAny: timeout ===");
var slowOp = FetchAsync("Slow", 2000);
var timeout = Task.Delay(300);

Task first = await Task.WhenAny(slowOp, timeout);
if (first == timeout)
    Console.WriteLine("Timed out!");
else
    Console.WriteLine(await slowOp);

// --- WhenAny: process as they complete ---
Console.WriteLine("\n=== Process as complete ===");
var pending = new List<Task<string>>
{
    FetchAsync("Fast",   50),
    FetchAsync("Medium", 150),
    FetchAsync("Slow",   300),
};

while (pending.Count > 0)
{
    var done = await Task.WhenAny(pending);
    pending.Remove(done);
    Console.WriteLine(await done);
}
```

## Common Follow-up Questions

- How do you cancel all remaining tasks in a `WhenAny` group when one completes successfully?
- How does `Task.WhenAll` compare to `Parallel.ForEachAsync` for CPU-bound fan-out?
- What is the performance implication of passing thousands of tasks to `Task.WhenAny` in a loop?
- How do you use `Task.WhenAll` with `IAsyncEnumerable<T>` — is it possible?
- When does `Task.WhenAll` return a faulted task vs a cancelled task?

## Common Mistakes / Pitfalls

- **Starting tasks inside `WhenAll(...)` instead of before it.** `await Task.WhenAll(FetchA(), FetchB())` is fine — both start immediately. But calling `await FetchA()` then `await FetchB()` is sequential, not parallel.
- **Not checking all exceptions from a faulted `WhenAll`.** `await` unwraps only the first; the others are silently dropped. Inspect `task.Exception.InnerExceptions` for the full list.
- **Forgetting that `WhenAny` doesn't cancel losers.** After `WhenAny`, the other tasks are still running, consuming resources. If you don't need their results, link them to a cancellation token and cancel.
- **Using `WhenAny` in a `while` loop over many tasks.** O(n²) continuation registration. Use `Channel<T>` or `IAsyncEnumerable<T>` for streaming patterns.
- **Passing an empty collection to `WhenAll`.** `await Task.WhenAll()` returns immediately with an empty array — usually harmless, but may indicate a logic bug.

## References

- [Task.WhenAll — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.whenall)
- [Task.WhenAny — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.whenany)
- [Implementing WhenAll and WhenAny Patterns — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/pfxteam/implementing-then-with-await/)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: cancellation-tokens.md](./cancellation-tokens.md)
- [See: parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md)
