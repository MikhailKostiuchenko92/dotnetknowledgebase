# Parallel.ForEach vs Task.WhenAll

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `Parallel.ForEach`, `Task.WhenAll`, `CPU-bound`, `IO-bound`, `async`, `parallelism`

## Question

> When should you use `Parallel.ForEach` / `Parallel.ForEachAsync` versus `Task.WhenAll` for parallel work? What is the key distinction between CPU-bound and I/O-bound workloads?

Also asked as:
- "Why is `Parallel.ForEach` wrong for async I/O operations?"
- "What is `Parallel.ForEachAsync` and how is it different from `Parallel.ForEach`?"

## Short Answer

Use `Parallel.ForEach` for **CPU-bound** work that benefits from multiple cores executing simultaneously. Use `Task.WhenAll` (or `Parallel.ForEachAsync`) for **I/O-bound** work where you want to issue many concurrent requests without wasting threads. `Parallel.ForEach` with async lambdas is a common anti-pattern: it ignores the returned `Task`, executing callbacks fire-and-forget while the loop finishes immediately.

## Detailed Explanation

### CPU-Bound vs I/O-Bound

| | CPU-bound | I/O-bound |
|---|---|---|
| Bottleneck | Processor cycles | Network / disk latency |
| Benefit from threads | ✅ (more cores = faster) | ❌ (threads mostly sleeping) |
| Ideal tool | `Parallel.ForEach`, `PLINQ` | `async/await`, `Task.WhenAll` |
| Thread count needed | `≈ CPU core count` | Far fewer (threads not busy) |

### `Parallel.ForEach` — CPU-Bound Workhorse

`Parallel.ForEach` uses the thread pool to process items in parallel across CPU cores. It respects `MaxDegreeOfParallelism` and provides fine-grained partitioning:

```csharp
// Good: CPU-heavy transform
Parallel.ForEach(images, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount },
    img => img.Resize(800, 600));
```

It is **synchronous** — it blocks the calling thread until all iterations are done.

### The `Parallel.ForEach` + `async` Anti-Pattern

`Parallel.ForEach` accepts `Action<T>`, not `Func<T, Task>`. Passing an `async` lambda creates an `async void` delegate:

```csharp
// ❌ WRONG — async lambda becomes async void; tasks are ignored
Parallel.ForEach(urls, async url =>
{
    await DownloadAsync(url);   // this Task is discarded! Loop exits immediately
});
// Loop body "completes" as soon as each async void method suspends — not when downloads finish
```

This is functionally equivalent to fire-and-forget on every item, with no result collection and no exception propagation.

### `Parallel.ForEachAsync` — .NET 6+ Correct Async Parallel

.NET 6 introduced `Parallel.ForEachAsync` which accepts `Func<T, CancellationToken, ValueTask>`:

```csharp
// ✅ CORRECT for throttled async I/O (e.g., limited concurrency HTTP fan-out)
await Parallel.ForEachAsync(urls,
    new ParallelOptions
    {
        MaxDegreeOfParallelism = 4,   // at most 4 concurrent downloads
        CancellationToken = ct
    },
    async (url, token) =>
    {
        string html = await DownloadAsync(url, token);
        Process(html);
    });
```

This correctly `awaits` each `ValueTask`, propagates exceptions, respects cancellation, and limits concurrency — ideal for throttled I/O fan-out.

### `Task.WhenAll` — Unbounded Async Fan-Out

```csharp
// ✅ All downloads run concurrently (no throttle)
string[] results = await Task.WhenAll(urls.Select(u => DownloadAsync(u, ct)));
```

`Task.WhenAll` issues all tasks immediately with no concurrency limit. Fine for small collections or when the downstream service handles the load. For large collections or rate-limited APIs, add a `SemaphoreSlim` throttle or use `Parallel.ForEachAsync` with `MaxDegreeOfParallelism`.

### Throttled `WhenAll` with `SemaphoreSlim`

```csharp
var semaphore = new SemaphoreSlim(initialCount: 4);

async Task<string> ThrottledDownloadAsync(string url, CancellationToken ct)
{
    await semaphore.WaitAsync(ct);
    try   { return await DownloadAsync(url, ct); }
    finally { semaphore.Release(); }
}

string[] results = await Task.WhenAll(urls.Select(u => ThrottledDownloadAsync(u, ct)));
```

### Decision Guide

| Need | Tool |
|---|---|
| CPU-bound, synchronous items | `Parallel.ForEach` |
| CPU-bound, need result | `PLINQ (.AsParallel().Select(...))` |
| I/O-bound, fire all at once | `Task.WhenAll` |
| I/O-bound, limit concurrency | `Parallel.ForEachAsync` (.NET 6+) or `SemaphoreSlim` + `WhenAll` |
| Streaming async items | `IAsyncEnumerable<T>` + `await foreach` |
| Long-running producers/consumers | `Channel<T>` |

> **Rule of thumb:** If the lambda body contains `await`, you want an async-aware tool — not `Parallel.ForEach`.

## Code Example

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

static async Task<string> DownloadAsync(string url, CancellationToken ct = default)
{
    await Task.Delay(100, ct);   // simulate HTTP
    return $"Content of {url}";
}

static int Compress(byte[] data) { Thread.SpinWait(1_000_000); return data.Length; } // CPU work

var urls = Enumerable.Range(1, 10).Select(i => $"https://example.com/{i}").ToArray();
var blobs = Enumerable.Range(1, 100).Select(i => new byte[1024]).ToArray();

// ✅ CPU-bound: Parallel.ForEach
var sizes = new int[blobs.Length];
Parallel.ForEach(blobs, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount },
    (blob, _, i) => sizes[i] = Compress(blob));
Console.WriteLine($"Compressed {sizes.Length} blobs");

// ❌ WRONG: Parallel.ForEach with async lambda
// Parallel.ForEach(urls, async url => await DownloadAsync(url));  // tasks ignored!

// ✅ I/O-bound, unbounded: Task.WhenAll
string[] results = await Task.WhenAll(urls.Select(u => DownloadAsync(u)));
Console.WriteLine($"Downloaded {results.Length} pages");

// ✅ I/O-bound, throttled: Parallel.ForEachAsync (.NET 6+)
var processed = new System.Collections.Concurrent.ConcurrentBag<string>();
await Parallel.ForEachAsync(urls,
    new ParallelOptions { MaxDegreeOfParallelism = 3 },
    async (url, ct) =>
    {
        string content = await DownloadAsync(url, ct);
        processed.Add(content);
    });
Console.WriteLine($"Throttled: {processed.Count} pages");

// ✅ I/O-bound, throttled: WhenAll + SemaphoreSlim (pre-.NET 6 compatible)
var sem = new SemaphoreSlim(3);
async Task<string> Throttled(string url)
{
    await sem.WaitAsync();
    try { return await DownloadAsync(url); }
    finally { sem.Release(); }
}
string[] throttled = await Task.WhenAll(urls.Select(Throttled));
Console.WriteLine($"Semaphore-throttled: {throttled.Length} pages");
```

## Common Follow-up Questions

- How does `Parallel.ForEachAsync` decide which thread pool threads to use — is it different from `Task.WhenAll`?
- What is PLINQ and when would you choose it over `Parallel.ForEach`?
- How do you handle partial failures in `Parallel.ForEachAsync` — can you continue after one item fails?
- What is the performance overhead of `SemaphoreSlim` for throttling — when does it become a bottleneck?
- How does `Channel<T>` differ from both of these for producer-consumer scenarios?

## Common Mistakes / Pitfalls

- **`Parallel.ForEach` with `async` lambda.** The most common mistake. The lambda becomes `async void`, the tasks are abandoned, and the loop exits before any download completes.
- **Unbounded `Task.WhenAll` on large collections.** Firing 10,000 HTTP requests simultaneously can overwhelm the server, exhaust sockets, or trigger rate-limiting. Always throttle for external I/O.
- **Using `Parallel.ForEachAsync` for CPU-bound work hoping for better performance.** `ForEachAsync` uses thread pool threads but is designed for async I/O patterns; `Parallel.ForEach` has better partitioning and work-stealing for CPU-bound loops.
- **Forgetting that `Parallel.ForEach` blocks the calling thread.** If called from inside an `async` method, it blocks a thread pool thread. Use `await Task.Run(() => Parallel.ForEach(...))` to keep the call site non-blocking.
- **Not passing `CancellationToken` to `Parallel.ForEachAsync`.** Without it, cancellation can't interrupt the loop; in-progress items finish even after the token fires.

## References

- [Parallel.ForEachAsync — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.parallel.foreachasync)
- [Parallel.ForEach — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.parallel.foreach)
- [Async in Parallel — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/pfxteam/implementing-a-simple-foreachasync/)
- [See: task-whenall-vs-whenany.md](./task-whenall-vs-whenany.md)
- [See: cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
