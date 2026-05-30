# Async I/O and Throughput

**Category:** System Design / Performance
**Difficulty:** Middle
**Tags:** `async`, `io`, `kestrel`, `thread-pool`, `throughput`, `i/o-completion-ports`

## Question

> Why does async/await dramatically improve throughput for I/O-bound web servers? How does Kestrel use async I/O internally? What is the thread pool's role, and what happens when you block a thread inside an async call?

- What is the difference between I/O-bound and CPU-bound work in the context of web server scalability?
- What happens to throughput if you call `.Result` or `.Wait()` on a task inside an async endpoint?

## Short Answer

Async I/O allows a thread to initiate a network or disk read, then return to the thread pool to serve other requests while the OS waits for the I/O to complete. Without async, a thread blocks for the entire duration of the I/O (e.g., 10 ms for a DB query) — at 1000 req/s, you'd need 10,000 threads just for DB waits, exhausting memory and context-switch budget. Kestrel is fully async; it uses `SocketAsyncEventArgs` and the .NET I/O completion port mechanism to serve tens of thousands of concurrent connections with just a few threads. Blocking a thread with `.Result` inside an async context wastes this benefit and can deadlock under `SynchronizationContext`.

## Detailed Explanation

### I/O-Bound vs CPU-Bound Throughput

| | I/O-Bound | CPU-Bound |
|--|-----------|-----------|
| Bottleneck | Waiting for network/disk | Processor cycles |
| Scale with threads | No (threads idle waiting) | Yes (more threads = more parallel work) |
| Scale with async | Yes (threads freed during wait) | No benefit (CPU still needed) |
| Example | DB query, HTTP call, file read | Image processing, crypto, sorting |

For I/O-bound work, async I/O's benefit is not speed of the individual request — the I/O takes the same wall-clock time. The benefit is **throughput**: more concurrent requests served with the same number of threads.

### How Async I/O Works (Simplified)

```
Request arrives → Thread T1 picks it up
T1: parse request, validate → async DB call starts
     ↓
OS: queues I/O request to NIC/disk driver (non-blocking kernel call)
T1: returns to thread pool ← thread is FREE to serve another request!

10ms later: OS I/O completion port signals → thread pool assigns T2
T2: resumes after "await" — serialises response, sends it
```

Without async (`Thread.Sleep` / blocking `DbConnection`):
```
Request arrives → Thread T1 picks it up
T1: parse → DB call → T1 BLOCKS (sleeping, wasting memory & scheduler time)
                       ← cannot serve any other request
```

### Thread Pool and the Sync-Over-Async Deadlock

The .NET thread pool has a minimum thread count (default: number of processors) and grows slowly (one thread per second after saturation). Blocking threads with `.Result` or `.Wait()` can starve the pool:

```csharp
// ❌ DEADLOCK or starvation: blocking inside async context (e.g., ASP.NET with SynchronizationContext)
public IActionResult GetProduct(Guid id)
{
    var product = _repo.GetAsync(id).Result;  // blocks thread waiting for async result
    return Ok(product);
}

// ❌ STARVATION at scale: 1000 concurrent requests × 10ms each = 10,000 threads needed
// Thread pool cannot create them fast enough → queue depth grows → timeouts

// ✅ CORRECT: async all the way through
public async Task<IActionResult> GetProduct(Guid id)
{
    var product = await _repo.GetAsync(id);   // thread returned to pool during DB wait
    return Ok(product);
}
```

`SynchronizationContext` in older ASP.NET (System.Web) + `await` + `.Result` = classic deadlock: the `await` captures the sync context, but `.Result` blocks the context's thread, preventing the continuation from running.

ASP.NET Core has no `SynchronizationContext` (uses the thread pool directly), so deadlock is less likely — but starvation still occurs at high concurrency.

### Kestrel's Async Architecture

Kestrel uses:
1. **`SocketAsyncEventArgs`** — zero-allocation async socket reads/writes using OS completion ports (IOCP on Windows, epoll on Linux).
2. **Pipe-based I/O** (`System.IO.Pipelines`) — a lock-free ring buffer between network reads and HTTP parsing, avoiding buffer copies.
3. **Thread pool continuations** — resumed `await` continuations run on thread pool threads; no dedicated I/O threads.

Result: Kestrel serves ~7 million plain-text HTTP requests/s on modern hardware with tens of connections per thread.

### Async vs Parallel

| | Async (await) | Parallel (Task.WhenAll) |
|--|--------------|----------------------|
| Purpose | Don't waste threads on I/O wait | Do multiple I/O calls concurrently |
| Thread count | Same thread (or fewer) | Multiple threads |
| Best for | Sequential I/O calls | Independent I/O operations |

```csharp
// Sequential (unnecessary latency)
var product  = await _catalogue.GetAsync(productId);  // 10 ms
var reviews  = await _reviews.GetAsync(productId);    // 10 ms
// Total: 20 ms

// Concurrent (better)
var (product, reviews) = await (
    _catalogue.GetAsync(productId),
    _reviews.GetAsync(productId));  // Both start simultaneously
// Total: ~10 ms (max of the two)
```

See the C# async/await deep dives in `01-csharp-language/` for `ConfigureAwait`, `ValueTask`, and `SynchronizationContext` details.

### Kestrel Throughput Settings

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    // Increase min thread count to avoid slow thread pool scale-out
    ThreadPool.SetMinThreads(workerThreads: 200, completionPortThreads: 200);

    options.Limits.MaxConcurrentConnections = 10_000;
    // HTTP/2 settings for gRPC throughput
    options.Limits.Http2.MaxStreamsPerConnection = 100;
    options.Limits.Http2.InitialConnectionWindowSize  = 1 * 1024 * 1024; // 1MB
    options.Limits.Http2.InitialStreamWindowSize      = 96 * 1024;        // 96KB
});
```

## Code Example

```csharp
// Demonstrating async I/O throughput benefit with System.IO.Pipelines
using System.IO.Pipelines;
using System.Net.Sockets;

namespace ThroughputDemo;

// Minimal async TCP reader using Pipelines (no buffer copies)
public sealed class AsyncPipelineReader(Socket socket)
{
    public async Task ProcessAsync(CancellationToken ct)
    {
        var pipe = new Pipe();

        // Two concurrent loops: fill pipe from socket, drain pipe to parse
        var fill  = FillPipeAsync(pipe.Writer, ct);
        var drain = DrainPipeAsync(pipe.Reader, ct);

        await Task.WhenAll(fill, drain);
    }

    private async Task FillPipeAsync(PipeWriter writer, CancellationToken ct)
    {
        while (true)
        {
            // Get memory from the pipe — no buffer allocation
            var memory = writer.GetMemory(4096);
            var bytes  = await socket.ReceiveAsync(memory, SocketFlags.None, ct);

            if (bytes == 0) break; // connection closed

            writer.Advance(bytes);
            var result = await writer.FlushAsync(ct);
            if (result.IsCompleted) break;
        }
        writer.Complete();
    }

    private async Task DrainPipeAsync(PipeReader reader, CancellationToken ct)
    {
        while (true)
        {
            var result  = await reader.ReadAsync(ct);
            var buffer  = result.Buffer;

            // Parse without copying data — examine bytes in-place
            foreach (var segment in buffer)
            {
                // process segment.Span...
            }

            reader.AdvanceTo(buffer.End);
            if (result.IsCompleted) break;
        }
        reader.Complete();
    }
}

// Performance comparison (conceptual benchmark)
// Sync endpoint: 1000 req/s × 10ms = 10,000 blocked threads needed
// Async endpoint: 1000 req/s × 10ms = ~10 threads + I/O completions
// Memory: sync ~10,000 × 1MB stack = 10 GB; async ~10 × 1MB = 10 MB
```

## Common Follow-up Questions

- What is `ConfigureAwait(false)` and when do you need it in a library vs an application?
- What happens to throughput when mixing CPU-heavy work in an I/O-intensive pipeline?
- How does `ValueTask` reduce allocations compared to `Task` for hot paths?
- What is the thread pool injection delay and how does `ThreadPool.SetMinThreads` help?
- How does HTTP/2 multiplexing improve gRPC throughput compared to HTTP/1.1 connection pooling?

## Common Mistakes / Pitfalls

- **Blocking with `.Result` or `.GetAwaiter().GetResult()`**: wastes a thread for the entire I/O duration; can deadlock; should be async all the way.
- **`async void` handlers**: exceptions thrown in `async void` crash the process; use `async Task` everywhere except event handlers.
- **`Task.Run` for I/O**: offloading async I/O to `Task.Run` wastes two threads (one blocking, one waiting); I/O should be natively async.
- **Neglecting `CancellationToken`**: async I/O without cancellation leaves orphaned tasks consuming connections after the HTTP request times out.
- **CPU work on the thread pool without throttling**: a CPU-intensive `Task.Run` loop consumes all thread pool threads; use `SemaphoreSlim` or a dedicated `TaskScheduler` for CPU work.
- **Forgotten `await`**: `_analytics.TrackAsync(e)` without `await` discards the task; exceptions disappear silently.

## References

- [Async I/O in .NET — Stephen Toub (Microsoft)](https://devblogs.microsoft.com/dotnet/how-async-await-really-works/)
- [Kestrel web server implementation notes](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel)
- [System.IO.Pipelines — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/io/pipelines)
- [See: connection-pooling-at-scale.md](./connection-pooling-at-scale.md)
- [See: backpressure-patterns.md](./backpressure-patterns.md)
