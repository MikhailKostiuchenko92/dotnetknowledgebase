# CPU-Bound vs I/O-Bound Work in Async Code

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `async`, `await`, `Task.Run`, `thread-pool`, `io-bound`, `cpu-bound`

## Question
> What is the difference between CPU-bound and I/O-bound work in .NET, and how should that affect your use of `async`/`await` and `Task.Run`?

Also asked as:
- "When should I use `Task.Run`, and when should I just `await` the operation directly?"
- "Why is wrapping `HttpClient` or database calls in `Task.Run` usually the wrong choice?"

## Short Answer
CPU-bound work spends time actively using a core, so offloading it with `Task.Run` can keep a UI or request thread responsive. I/O-bound work spends most of its time waiting on the OS, network, disk, or database, so it should use naturally asynchronous APIs such as `ReadAsync`, `SendAsync`, or EF Core async methods. Wrapping I/O in `Task.Run` wastes a thread pool thread without making the I/O itself faster.

## Detailed Explanation

### What CPU-bound and I/O-bound really mean
CPU-bound code is limited by computation: parsing large files in memory, image resizing, compression, encryption, or calculating aggregates over millions of items. The thread is busy the whole time.

I/O-bound code is limited by waiting: HTTP calls, database queries, file reads, socket operations, timers, or waiting for another service. During most of that time, there is nothing useful for the CPU to do, so .NET can return the thread to the pool and resume later when the OS signals completion.

| Work type | Dominant cost | Best tool | Holds a thread while waiting? |
|---|---|---|---|
| CPU-bound | Computation on the CPU | `Task.Run`, `Parallel`, PLINQ | Yes |
| I/O-bound | Waiting for external resource | `async` APIs + `await` | No |

### When `Task.Run` is appropriate
`Task.Run` queues work to the thread pool. That is useful when you have synchronous CPU work and you want to avoid blocking the caller's thread:

- UI apps: keep the UI thread responsive.
- Server code: sometimes isolate a short burst of unavoidable CPU work from the request flow.
- Composition code: parallelize several independent CPU-heavy operations.

`Task.Run` does **not** make code magically asynchronous. It just says, "run this delegate on a thread pool thread." If the delegate blocks, that pool thread stays blocked.

> **Rule of thumb:** use `Task.Run` for CPU work you must move off the caller's thread, not as a generic fix for all slow operations.

### Why wrapping I/O in `Task.Run` is usually wrong
Suppose you already have `await httpClient.GetStringAsync(...)`. That call is naturally asynchronous. During the network wait, no thread is reserved just to wait.

If you instead do `await Task.Run(() => httpClient.GetStringAsync(...).GetAwaiter().GetResult())`, you make things worse:

1. You spend a thread pool thread to start the work.
2. You block that thread while I/O is pending.
3. You add extra scheduling overhead.
4. Under load, you increase thread pool pressure and risk starvation.

The network, database, or disk is still the bottleneck. `Task.Run` cannot speed up the external resource.

### Thread pool implications on servers
In ASP.NET Core there is no UI thread to protect, but thread pool health still matters. If many requests wrap blocking or I/O work inside `Task.Run`, you can consume pool threads faster than the runtime can add new ones. That leads to rising latency, queued continuations, and throughput collapse under load.

This is why the preferred server pattern is:

- async all the way for I/O
- direct synchronous execution for tiny CPU work
- explicit `Task.Run` only for meaningful CPU-bound sections

### Practical decision guide
- **HTTP, EF Core, file/network I/O available as async API:** use `await` directly.
- **Pure CPU calculation that takes noticeable time:** use `Task.Run` or data-parallel APIs.
- **Blocking legacy API with no async version:** `Task.Run` can be a pragmatic bridge, but document it as a workaround.

### Latency vs scalability
A useful interview distinction is **responsiveness** versus **throughput**. In a UI app, `Task.Run` can improve responsiveness by moving CPU work off the UI thread. In a server app, the main concern is usually scalability: how many requests can progress concurrently without exhausting worker threads.

Naturally async I/O improves scalability because waiting requests do not occupy a thread the whole time. `Task.Run` around I/O usually does the opposite: it hides the wait on a worker thread, which lowers effective throughput under load.

### Legacy synchronous APIs
Sometimes there is no async API at all, such as a third-party library that only exposes blocking calls. In that case, `Task.Run` can be a reasonable adapter, especially at app boundaries. But it should be treated as a compatibility shim, not as evidence that the operation became truly asynchronous. You still pay for one blocked thread per in-flight call.

> **Tip:** if you control the API and the work is inherently synchronous CPU work, do not create a fake `Async` method that only calls `Task.Run`. Expose a synchronous method and let the caller decide whether offloading is needed.

## Code Example
```csharp
using System;
using System.Net.Http;
using System.Threading.Tasks;

using var httpClient = new HttpClient();

// CPU-bound: offload heavy calculation so the caller is not blocked.
static Task<long> CountPrimesAsync(int max)
{
    return Task.Run(() =>
    {
        long count = 0;
        for (int number = 2; number <= max; number++)
        {
            bool isPrime = true;
            for (int divisor = 2; divisor * divisor <= number; divisor++)
            {
                if (number % divisor == 0)
                {
                    isPrime = false;
                    break;
                }
            }

            if (isPrime)
            {
                count++;
            }
        }

        return count;
    });
}

// I/O-bound: just await the naturally async API.
static async Task<string> DownloadPageAsync(HttpClient client, string url)
{
    // No thread is blocked while the network request is in flight.
    return await client.GetStringAsync(url);
}

long primeCount = await CountPrimesAsync(200_000);
Console.WriteLine($"Prime count: {primeCount}");

string html = await DownloadPageAsync(httpClient, "https://example.com");
Console.WriteLine($"Downloaded {html.Length} characters.");

// Bad pattern shown for contrast only.
static Task<string> WrongWrappedIoAsync(HttpClient client, string url)
{
    // This burns a thread pool thread for no benefit.
    return Task.Run(() => client.GetStringAsync(url).GetAwaiter().GetResult());
}
```

## Common Follow-up Questions
- How does `Task.Run` differ from `Parallel.ForEach` or `Parallel.ForEachAsync`?
- What is thread pool starvation, and how can blocking I/O contribute to it?
- Is `Task.Run` ever acceptable in ASP.NET Core request handlers?
- How should you deal with a legacy synchronous database or file API that has no async version?
- How does this topic relate to [parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md)?

## Common Mistakes / Pitfalls
- Wrapping naturally asynchronous I/O in `Task.Run` and assuming it improves scalability.
- Creating fake async APIs that only call `Task.Run`, which hides the real cost model from callers.
- Offloading tiny CPU work to the thread pool, where scheduling overhead may cost more than the work itself.
- Blocking on async I/O inside `Task.Run` with `.Result` or `.GetAwaiter().GetResult()`, which ties up a worker thread.
- Forgetting that `Task.Run` is not a substitute for proper cancellation and back-pressure design.

## References
- [Task.Run Method — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.run)
- [Asynchronous programming scenarios — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios)
- [The managed thread pool — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/the-managed-thread-pool)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md)
- [See: task-vs-thread.md](./task-vs-thread.md)
