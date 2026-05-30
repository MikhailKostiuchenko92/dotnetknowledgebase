# IAsyncEnumerable

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `IAsyncEnumerable`, `await foreach`, `async-streams`, `yield`, `ConfigureAwait`

## Question

> What is `IAsyncEnumerable<T>` and how does it differ from `IEnumerable<T>` and returning `Task<IEnumerable<T>>`? How do you produce and consume async streams, and how do you apply `ConfigureAwait` on `await foreach`?

Also asked as:
- "When would you use `yield return` in an `async` method?"
- "How do you cancel an `await foreach` loop?"

## Short Answer

`IAsyncEnumerable<T>` is a streaming pull interface for asynchronous sequences — each element is awaited individually as it becomes available, rather than all at once. Unlike `Task<IEnumerable<T>>` (which buffers everything before returning), an async stream starts delivering items immediately and uses constant memory regardless of total count. The producer uses `async` + `yield return` in an iterator method; the consumer uses `await foreach`. Cancellation is supported via `WithCancellation`, and context control via `ConfigureAwait`.

## Detailed Explanation

### The Three Patterns Compared

```csharp
// 1. Synchronous — blocks, buffers all data
IEnumerable<Row> GetRows() { /* ... */ yield return row; }

// 2. Task<IEnumerable<T>> — async, but buffers EVERYTHING before returning
async Task<IEnumerable<Row>> GetRowsAsync()
{
    var list = new List<Row>();
    await foreach (var row in db.StreamAsync()) list.Add(row);
    return list;   // full result in memory
}

// 3. IAsyncEnumerable<T> — async AND streaming; first item delivered before last is fetched
async IAsyncEnumerable<Row> StreamRowsAsync()
{
    await foreach (var row in db.StreamAsync())
        yield return row;   // delivered one at a time
}
```

| | `IEnumerable<T>` | `Task<IEnumerable<T>>` | `IAsyncEnumerable<T>` |
|---|---|---|---|
| Async I/O between items | ❌ | ✅ (only before first item) | ✅ |
| Streaming (constant memory) | ✅ | ❌ (buffers all) | ✅ |
| First item latency | Low | High (waits for all) | Low |
| `await` inside iterator | ❌ | N/A | ✅ |

### Producing an Async Stream

An `async IAsyncEnumerable<T>` method is just a regular `async` method that uses `yield return`:

```csharp
public async IAsyncEnumerable<int> CountWithDelayAsync(
    int count,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    for (int i = 0; i < count; i++)
    {
        ct.ThrowIfCancellationRequested();
        await Task.Delay(50, ct);
        yield return i;
    }
}
```

The `[EnumeratorCancellation]` attribute is **required** for the `CancellationToken` to be passed through when the consumer calls `.WithCancellation(ct)`.

### Consuming with `await foreach`

```csharp
await foreach (int value in CountWithDelayAsync(10))
{
    Console.WriteLine(value);   // processes each item as it arrives
}
```

### Cancellation

Two ways to cancel:

**Option A** — pass the token directly to the producing method:

```csharp
await foreach (var item in StreamAsync(ct)) { }
```

**Option B** — `.WithCancellation(ct)` on the `IAsyncEnumerable` (works with `[EnumeratorCancellation]`):

```csharp
await foreach (var item in stream.WithCancellation(ct)) { }
```

Both approaches are equivalent when the producer uses `[EnumeratorCancellation]`. Option B is useful when you receive an `IAsyncEnumerable<T>` from an API that you didn't write.

### `ConfigureAwait` on Async Streams

```csharp
// Suppress SynchronizationContext re-entry on each MoveNextAsync():
await foreach (var item in stream.ConfigureAwait(false))
{
    Process(item);   // runs on thread pool; do not access UI elements here
}
```

Chaining both:

```csharp
await foreach (var item in stream
    .WithCancellation(ct)
    .ConfigureAwait(false))
{ }
```

### How the Compiler Implements `IAsyncEnumerable<T>`

The compiler generates a state machine implementing `IAsyncEnumerable<T>` and `IAsyncEnumerator<T>`. The `MoveNextAsync()` method returns `ValueTask<bool>` — it completes synchronously if an item is already available, avoiding allocation for the common cached-result case.

The iterator method's state machine tracks `yield return` points identically to a synchronous iterator, but each `await` inside the loop body suspends asynchronously.

### Buffering and Back-Pressure

`IAsyncEnumerable<T>` has no built-in buffering or back-pressure. The consumer controls the pace — `MoveNextAsync()` is not called until the consumer requests the next item. If you need producer-side buffering or multi-consumer fan-out, use `Channel<T>` and expose it as `IAsyncEnumerable<T>` via a reader.

### EF Core Integration

EF Core 3+ supports async streaming:

```csharp
await foreach (var order in dbContext.Orders
    .Where(o => o.Status == "Pending")
    .AsAsyncEnumerable()                 // ← streams from DB row-by-row
    .WithCancellation(ct))
{
    await ProcessOrderAsync(order, ct);
}
```

This processes rows one at a time from the database cursor without loading all into memory.

## Code Example

```csharp
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;

// --- Producer ---
static async IAsyncEnumerable<int> RangeAsync(
    int start,
    int count,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    for (int i = start; i < start + count; i++)
    {
        await Task.Delay(20, ct);   // simulate async data fetch per item
        yield return i;
    }
}

// --- Consumer ---
static async Task ConsumeAsync(CancellationToken ct)
{
    await foreach (int value in RangeAsync(1, 5).WithCancellation(ct).ConfigureAwait(false))
    {
        Console.Write($"{value} ");
    }
    Console.WriteLine();
}

// --- Transform stream (LINQ-like extension method) ---
static async IAsyncEnumerable<TResult> SelectAsync<T, TResult>(
    this IAsyncEnumerable<T> source,
    Func<T, TResult> selector,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    await foreach (T item in source.WithCancellation(ct).ConfigureAwait(false))
        yield return selector(item);
}

// --- Batching an async stream ---
static async IAsyncEnumerable<T[]> BatchAsync<T>(
    IAsyncEnumerable<T> source,
    int size,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    var batch = new List<T>(size);
    await foreach (T item in source.WithCancellation(ct).ConfigureAwait(false))
    {
        batch.Add(item);
        if (batch.Count == size)
        {
            yield return batch.ToArray();
            batch.Clear();
        }
    }
    if (batch.Count > 0)
        yield return batch.ToArray();
}

// --- Entry point ---
using var cts = new CancellationTokenSource();

await ConsumeAsync(cts.Token);   // 1 2 3 4 5

var doubled = RangeAsync(1, 5).SelectAsync(x => x * 2);
await foreach (int v in doubled)
    Console.Write($"{v} ");      // 2 4 6 8 10
Console.WriteLine();

await foreach (int[] batch in BatchAsync(RangeAsync(1, 10), 3))
    Console.WriteLine($"Batch: [{string.Join(", ", batch)}]");
```

## Common Follow-up Questions

- How does `System.Linq.Async` (`IAsyncEnumerable<T>` LINQ extensions) compare to writing your own operators?
- How do you convert a `Channel<T>` reader to `IAsyncEnumerable<T>`?
- What is the difference between `IAsyncEnumerable<T>` and `IObservable<T>` (Rx) — when do you choose each?
- How does back-pressure work with `IAsyncEnumerable<T>` — can the producer run ahead?
- How does gRPC streaming use `IAsyncEnumerable<T>` in the .NET client library?

## Common Mistakes / Pitfalls

- **Omitting `[EnumeratorCancellation]` on the `CancellationToken` parameter.** Without it, `.WithCancellation(ct)` passes the token via the enumerator but the producer never sees it — cancellation has no effect.
- **Calling `.ToListAsync()` or `.ToArrayAsync()` on a large stream.** This defeats the constant-memory benefit; use processing within the `await foreach` loop instead.
- **Nesting `await foreach` without forwarding cancellation.** If the inner loop doesn't propagate the token, the outer cancellation cannot interrupt it.
- **Using `IAsyncEnumerable<T>` as a replacement for `Channel<T>` when multi-consumer fan-out is needed.** `IAsyncEnumerable<T>` is single-consumer; each `GetAsyncEnumerator()` call produces an independent cursor, not a shared stream.
- **Mixing `yield return` with `return` in the same async stream method.** You cannot have both; an `async IAsyncEnumerable<T>` method must use only `yield return` (never a plain `return value`).

## References

- [Async Streams — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/generate-consume-asynchronous-stream)
- [IAsyncEnumerable<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.collections.generic.iasyncenumerable-1)
- [Iterating with Async Enumerables in C# 8 — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/iterating-with-async-enumerables-in-csharp-8/)
- [EnumeratorCancellation attribute — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.enumeratorcancellationattribute)
- [See: async-streams-vs-channels.md](./async-streams-vs-channels.md)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
