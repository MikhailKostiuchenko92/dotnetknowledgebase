# When Should You Use Channel<T> in .NET?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Middle  
**Tags:** `channels`, `producer-consumer`, `iasyncenumerable`, `async`, `backpressure`

## Question
> What problem does `System.Threading.Channels` solve, and how is it different from `BlockingCollection<T>`?
>
> When should you choose a bounded channel versus an unbounded channel?
>
> How do `ChannelWriter<T>` and `ChannelReader<T>` support async producer-consumer pipelines?

## Short Answer
`Channel<T>` is the modern async-friendly producer-consumer primitive in .NET. A writer can push items with `WriteAsync` or `TryWrite`, and a reader can consume them with `ReadAsync` or `ReadAllAsync`, all without blocking threads while waiting. Bounded channels add backpressure and configurable overflow behavior, while unbounded channels maximize throughput but can grow memory usage if producers outrun consumers.

## Detailed Explanation
### What a channel is
A channel is an in-process queue designed for asynchronous producer-consumer workflows. The API deliberately splits responsibilities into `ChannelWriter<T>` and `ChannelReader<T>`, which makes intent clear and allows the runtime to optimize for common cases such as a single reader or a single writer.

The library lives in `System.Threading.Channels` and has been available since .NET Core 3+. It is especially useful for background pipelines, batching, buffering, and handoff between async components.

### Bounded versus unbounded
You typically create a channel in one of two ways:

- `Channel.CreateUnbounded<T>()` for simple, high-throughput pipelines where memory growth is acceptable or externally constrained.
- `Channel.CreateBounded<T>(capacity)` when you need backpressure and want to cap memory usage.

A bounded channel is often the better production default because it forces you to decide what happens when the buffer is full.

### Full modes and backpressure
Bounded channels support `BoundedChannelFullMode`:

| Mode | Behavior when full | Best for |
| --- | --- | --- |
| `Wait` | Writer waits asynchronously for space | Lossless pipelines |
| `DropWrite` | Reject/discard the current write | Fire-and-forget telemetry |
| `DropNewest` | Remove the newest buffered item | Keep older queued work |
| `DropOldest` | Remove the oldest buffered item | Keep the freshest data |

This is a powerful distinction from `BlockingCollection<T>`, which can bound capacity but relies on blocking semantics. Channels let the producer suspend asynchronously instead of parking a thread.

> If you need a scalable library or server pipeline, “not blocking a thread” is usually the key reason to prefer `Channel<T>` over older coordination primitives.

### Reading and writing APIs
Writers can call `TryWrite` for a fast, non-blocking attempt or `WriteAsync` to asynchronously wait for space. Readers can call `TryRead` for a fast path, `ReadAsync` to await the next item, or `ReadAllAsync` to consume a channel as an `IAsyncEnumerable<T>`.

That `ReadAllAsync` integration is particularly elegant because the consumer loop becomes ordinary async iteration:

```csharp
await foreach (var item in channel.Reader.ReadAllAsync(ct))
{
    // Process item
}
```

### Why channels fit producer-consumer so well
Channels encode several important behaviors cleanly:

- Completion: writers call `Complete()` when no more items will arrive.
- Cancellation: reads and writes accept cancellation tokens.
- Backpressure: bounded channels can slow or reject writers.
- Async consumption: readers naturally integrate with `await` and `IAsyncEnumerable<T>`.

That combination makes channels a better foundation for modern background queues than ad-hoc combinations of `ConcurrentQueue<T>` plus `SemaphoreSlim`, unless you specifically need custom behavior.

### Compared with other options

| Primitive | Async-friendly | Bounded | Typical use |
| --- | --- | --- | --- |
| `Channel<T>` | Yes | Yes | Modern async pipelines |
| `BlockingCollection<T>` | No | Yes | Dedicated worker threads |
| `ConcurrentQueue<T>` | No built-in waiting | No | Shared FIFO data structure |

For related topics, see [Concurrent Collections](./concurrent-collections.md) and [IAsyncEnumerable](./iasyncenumerable.md).

## Code Example
```csharp
using System.Threading.Channels;

namespace RuntimeSamples.Channels;

internal static class Program
{
    public static async Task Main()
    {
        var channel = Channel.CreateBounded<int>(new BoundedChannelOptions(capacity: 3)
        {
            FullMode = BoundedChannelFullMode.Wait, // Producers wait asynchronously when the buffer is full.
            SingleReader = true,
            SingleWriter = false
        });

        var producer = Task.Run(async () =>
        {
            for (var i = 1; i <= 6; i++)
            {
                await channel.Writer.WriteAsync(i); // No thread is blocked while waiting for space.
                Console.WriteLine($"Wrote {i}");
            }

            channel.Writer.Complete(); // Signal end-of-stream.
        });

        var consumer = Task.Run(async () =>
        {
            await foreach (var item in channel.Reader.ReadAllAsync())
            {
                Console.WriteLine($"Read {item} on thread {Environment.CurrentManagedThreadId}");
                await Task.Delay(100); // Simulate async processing.
            }
        });

        await Task.WhenAll(producer, consumer);
    }
}
```

## Common Follow-up Questions
- When should a bounded channel use `Wait` versus a dropping mode?
- Why is `ReadAllAsync` often nicer than manual `while` loops around `ReadAsync`?
- How does `Channel<T>` differ from `ConcurrentQueue<T>` plus polling?
- What happens to awaiting readers after `Writer.Complete()` is called?
- When is an unbounded channel acceptable in production code?

## Common Mistakes / Pitfalls
- Choosing an unbounded channel for data that can spike without limit.
- Forgetting to complete the writer, leaving readers waiting forever.
- Using channels for CPU-only tight loops where a simpler data structure would do.
- Assuming dropping modes preserve every item.
- Replacing proper backpressure decisions with “just make it unbounded.”

## References
- https://learn.microsoft.com/dotnet/core/extensions/channels
- https://learn.microsoft.com/dotnet/api/system.threading.channels.channel
- https://learn.microsoft.com/dotnet/api/system.threading.channels.channelreader-1
- https://learn.microsoft.com/dotnet/api/system.threading.channels.channelwriter-1
- https://learn.microsoft.com/dotnet/api/system.threading.channels.boundedchannelfullmode
