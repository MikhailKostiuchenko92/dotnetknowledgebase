# Async Streams vs Channels

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `IAsyncEnumerable`, `Channel<T>`, `producer-consumer`, `async-streams`, `backpressure`

## Question

> What is the difference between `IAsyncEnumerable<T>` and `System.Threading.Channels.Channel<T>`? When should you use each for producer-consumer scenarios?

Also asked as:
- "Why would I use `Channel<T>` instead of just `yield return` in an async method?"
- "Can multiple consumers read from an `IAsyncEnumerable<T>` simultaneously?"

## Short Answer

`IAsyncEnumerable<T>` is a **pull-based** single-consumer stream where the consumer drives pace via `await foreach`. `Channel<T>` is a **push-based** concurrent queue that decouples producers from consumers: producers write independently of consumers, supports multiple concurrent producers and consumers, provides bounded back-pressure, and supports cancelling the entire pipeline independently. Use `IAsyncEnumerable<T>` for simple sequential streaming; use `Channel<T>` when you need buffering, multiple producers/consumers, or producer-consumer decoupling.

## Detailed Explanation

### Pull vs Push

| | `IAsyncEnumerable<T>` | `Channel<T>` |
|---|---|---|
| Paradigm | Pull (consumer calls `MoveNextAsync`) | Push (producer calls `WriteAsync`) |
| Multiple concurrent consumers | ❌ single consumer only | ✅ `ChannelReader` shared across readers |
| Multiple concurrent producers | ❌ (one method, sequential) | ✅ multiple writers to the same `ChannelWriter` |
| Built-in buffering / back-pressure | ❌ | ✅ bounded vs unbounded |
| Producer/consumer run at different speeds | Tightly coupled (consumer blocks producer) | Decoupled (buffer absorbs difference) |
| Cancellation | Per-iteration via `WithCancellation` | `ChannelWriter.Complete()`; reader drains naturally |
| LINQ operators | ✅ via `System.Linq.Async` | ❌ requires wrapping |
| Memory overhead | Minimal | Buffer size × item size |

### `IAsyncEnumerable<T>` — Sequential Streaming

The producer and consumer are tightly coupled: the consumer calls `MoveNextAsync()`, which resumes the producer's iterator at the next `yield return`. There is no buffer — the consumer must request each item:

```
Consumer: MoveNextAsync() → Producer: runs until yield return → Consumer: gets item → repeat
```

This is perfect for:
- Database row streaming (EF Core, Dapper `QueryAsync` with streaming).
- File/network read-one-line-at-a-time patterns.
- Lazy transformation pipelines where the consumer controls pace.

### `Channel<T>` — Decoupled Concurrent Queue

A `Channel<T>` has a `ChannelWriter<T>` (producer side) and a `ChannelReader<T>` (consumer side):

```csharp
Channel<int> ch = Channel.CreateBounded<int>(capacity: 100);  // or CreateUnbounded
ChannelWriter<int>  writer = ch.Writer;
ChannelReader<int>  reader = ch.Reader;
```

Producer and consumer run independently. The channel buffers items between them.

**Bounded channel** (`Channel.CreateBounded<int>(n)`): when full, `WriteAsync` suspends the producer until there is space — natural back-pressure.

**Unbounded channel** (`Channel.CreateUnbounded<int>()`): never blocks the writer; memory grows unboundedly if the consumer is slower. Use only when you're certain the producer is bounded.

### When to Use `Channel<T>`

1. **Multiple producers and/or consumers** — `ChannelWriter` is thread-safe; multiple tasks can call `WriteAsync` concurrently. `ChannelReader` supports multiple concurrent `ReadAsync` calls (items are distributed among readers).
2. **Bounded buffer / back-pressure** — control memory consumption by limiting the channel capacity.
3. **Pipeline with independent stages** — Stage A produces at its own rate → channel → Stage B consumes at its own rate.
4. **Fan-out** — one producer, multiple consumers each processing a subset of items.
5. **Fan-in** — multiple producers writing to one channel, one consumer reading.

### Exposing a `Channel` as `IAsyncEnumerable<T>`

`ChannelReader<T>` implements `IAsyncEnumerable<T>` directly:

```csharp
await foreach (int item in channel.Reader.ReadAllAsync(ct))
{
    Process(item);
}
```

This lets you combine the concurrency model of `Channel<T>` with the ergonomics of `await foreach`.

### Back-Pressure Model

```csharp
// BoundedChannelOptions control what happens when the channel is full:
var options = new BoundedChannelOptions(capacity: 10)
{
    FullMode = BoundedChannelFullMode.Wait,          // producer waits (back-pressure) — default
    // FullMode = BoundedChannelFullMode.DropWrite,   // silently drop newest
    // FullMode = BoundedChannelFullMode.DropOldest,  // drop oldest buffered item
    // FullMode = BoundedChannelFullMode.DropNewest,  // drop item being written
    SingleWriter = true,    // optimization hint: only one producer
    SingleReader = false,   // multiple consumers
};
var ch = Channel.CreateBounded<Work>(options);
```

### Completing a `Channel`

```csharp
writer.Complete();           // signals no more items; reader drains then completes
writer.Complete(exception);  // signals a fault; ReadAllAsync throws on the reader side
```

`ChannelWriter.Complete()` is the graceful shutdown mechanism — equivalent to closing the producer side of a pipe.

## Code Example

```csharp
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Threading.Channels;

// --- IAsyncEnumerable<T>: simple sequential streaming ---
static async IAsyncEnumerable<int> GenerateAsync(int count,
    [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
{
    for (int i = 0; i < count; i++)
    {
        await Task.Delay(5, ct);
        yield return i;
    }
}

Console.WriteLine("=== IAsyncEnumerable ===");
await foreach (int v in GenerateAsync(5))
    Console.Write($"{v} ");
Console.WriteLine();

// --- Channel<T>: multi-producer → single consumer pipeline ---
Console.WriteLine("\n=== Channel<T> pipeline ===");
var channel = Channel.CreateBounded<int>(capacity: 10);

// Two concurrent producers
async Task ProduceAsync(int start, int count, CancellationToken ct)
{
    for (int i = start; i < start + count; i++)
    {
        await channel.Writer.WriteAsync(i, ct);
        await Task.Delay(5, ct);
    }
}

using var cts = new CancellationTokenSource();
var p1 = ProduceAsync(0, 5, cts.Token);
var p2 = ProduceAsync(100, 5, cts.Token);

// Signal completion after both producers finish
_ = Task.WhenAll(p1, p2).ContinueWith(_ => channel.Writer.Complete());

// Single consumer via ReadAllAsync (ChannelReader implements IAsyncEnumerable<T>)
await foreach (int item in channel.Reader.ReadAllAsync(cts.Token))
    Console.Write($"{item} ");
Console.WriteLine();

// --- Channel<T>: fan-out (1 producer, N consumers) ---
Console.WriteLine("\n=== Fan-out ===");
var fanOut = Channel.CreateUnbounded<int>();

_ = Task.Run(async () =>
{
    for (int i = 0; i < 12; i++) await fanOut.Writer.WriteAsync(i);
    fanOut.Writer.Complete();
});

// Three concurrent consumers
var consumers = Enumerable.Range(0, 3).Select(id => Task.Run(async () =>
{
    await foreach (int item in fanOut.Reader.ReadAllAsync())
        Console.Write($"[C{id}:{item}] ");
})).ToArray();

await Task.WhenAll(consumers);
Console.WriteLine();
```

## Common Follow-up Questions

- How does `Channel<T>` compare to `BlockingCollection<T>` from the older concurrency library?
- When would you choose `IObservable<T>` (Rx) over `Channel<T>` for event-driven pipelines?
- How do you implement a worker pool (N consumers) reading from one `Channel<T>`?
- What is the `SingleReader`/`SingleWriter` optimization in `BoundedChannelOptions` — how much does it matter?
- How do you propagate exceptions from a producer in a `Channel<T>` pipeline to the consumer?

## Common Mistakes / Pitfalls

- **Not calling `ChannelWriter.Complete()`** after the producer is done. The consumer will wait forever in `ReadAllAsync` because the channel never signals end-of-stream.
- **Using `Channel.CreateUnbounded` when the producer is faster than the consumer.** Without a capacity limit, the buffer grows indefinitely — eventually causing `OutOfMemoryException`.
- **Attempting multiple concurrent `await foreach` loops on the same `IAsyncEnumerable<T>`.** Each `GetAsyncEnumerator()` call starts an independent cursor. Shared iteration requires `Channel<T>` or explicit partitioning.
- **Ignoring `BoundedChannelFullMode`** and assuming `Wait` is the default. Explicitly set `FullMode` to make back-pressure intent clear.
- **Writing to a completed `ChannelWriter`.** After `Complete()`, any `WriteAsync` or `TryWrite` throws or returns `false` — check `TryWrite` return value or handle `ChannelClosedException`.

## References

- [System.Threading.Channels — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/channels)
- [An Introduction to System.Threading.Channels — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/an-introduction-to-system-threading-channels/)
- [IAsyncEnumerable — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.collections.generic.iasyncenumerable-1)
- [See: iasyncenumerable.md](./iasyncenumerable.md)
- [See: concurrent-collections.md](./concurrent-collections.md)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
