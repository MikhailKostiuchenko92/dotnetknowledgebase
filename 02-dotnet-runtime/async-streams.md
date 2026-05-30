# How Do Async Streams Work in .NET?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `async-streams`, `iasyncenumerable`, `channels`, `backpressure`, `iasyncdisposable`

## Question
> What are async streams in C#, and how do they relate to `IAsyncEnumerable<T>`?

> How do async iterators handle backpressure and cancellation?

> When would you combine async streams with `Channel<T>` or `IAsyncDisposable`?

## Short Answer
Async streams are the C# feature that lets you produce and consume `IAsyncEnumerable<T>` values with `async` iterators and `await foreach`. They are pull-based: the consumer asks for the next element, and the producer can asynchronously wait before yielding it. That naturally supports backpressure because the producer only advances when the consumer requests more, though internal buffering can still exist. For decoupled producer/consumer pipelines, `Channel<T>` is often used underneath, and `IAsyncDisposable` is important when the stream owns async-cleanup resources.

## Detailed Explanation
### Async iterators on the producer side
An async stream producer is typically written as `async IAsyncEnumerable<T>`, mixing `await` and `yield return` in one method. This is ideal for chunked file reads, paged HTTP results, database cursors, telemetry batching, or any source where items arrive over time.

Compared with returning `Task<List<T>>`, async streams reduce latency and memory usage because the first item can be processed before the entire operation finishes.

### Pull-based flow and practical backpressure
Async streams are pull-based: the consumer drives the pace by repeatedly asking for the next item through `await foreach`. That naturally limits how fast the producer advances.

| Approach | Delivery model | Buffering story | Best fit |
| --- | --- | --- | --- |
| Plain async iterator | Pull | Usually minimal unless producer buffers manually | Direct sequential streaming |
| `Channel<T>` + `ReadAllAsync()` | Pull over queued buffer | Explicit bounded/unbounded buffering | Decoupled producer/consumer |
| Reactive Extensions (`IObservable<T>`) | Push | Subscriber/backpressure handled separately | Event-style pipelines |

This is why async streams are often described as having “natural backpressure.” The consumer does not request more until it finishes with the current element. But if the producer internally reads ahead or writes into an unbounded channel, memory can still grow.

> Warning: `await foreach` does not guarantee zero buffering. Backpressure depends on how the producer is implemented, not just on the syntax the consumer uses.

### Channel-backed streaming
Sometimes the producer and consumer should be decoupled. Maybe a background worker fetches items in bursts while another component processes them more slowly. `Channel<T>` fits that scenario well:

- the writer pushes items into a channel
- the reader exposes `ReadAllAsync()` as an `IAsyncEnumerable<T>`
- a bounded channel can block the writer when the buffer is full

That gives you explicit, configurable buffering instead of relying only on the implicit pace of a direct async iterator. See [channel-t.md](./channel-t.md) and [iasyncenumerable.md](./iasyncenumerable.md).

### Cleanup with `IAsyncDisposable`
Some async streams own resources that also need asynchronous cleanup: network connections, database cursors, pipes, or background pumps. In those cases, `IAsyncDisposable` lets you release them without blocking a thread.

That is especially useful when a stream is backed by a long-running producer task. You want disposal to stop the producer cleanly and await shutdown.

### Compared with Rx
Reactive Extensions (`IObservable<T>`) is push-based: the producer decides when items arrive. Async streams are pull-based: the consumer decides when it is ready for the next item. Both models are useful, but they solve different coordination problems.

A good rule of thumb is this: if the consumer wants to iterate over results at its own pace, async streams feel natural. If the producer is broadcasting events whenever they occur, Rx is often the better conceptual match. In many real systems you will even see both, with a channel or observable source feeding an async stream adapter for downstream processing.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Threading.Channels;
using System.Threading.Tasks;

namespace RuntimeSamples.AsyncStreams;

internal static class Program
{
    private static async Task Main()
    {
        await using var producer = new NumberProducer();

        await foreach (int value in producer.StreamAsync())
        {
            Console.WriteLine($"Consumed {value}");
            await Task.Delay(80); // Slow consumer to demonstrate bounded buffering.
        }
    }
}

internal sealed class NumberProducer : IAsyncDisposable
{
    private readonly Channel<int> _channel = Channel.CreateBounded<int>(capacity: 2);
    private readonly Task _pump;

    public NumberProducer()
    {
        _pump = PumpAsync();
    }

    public IAsyncEnumerable<int> StreamAsync() => _channel.Reader.ReadAllAsync();

    private async Task PumpAsync()
    {
        for (int i = 1; i <= 5; i++)
        {
            await _channel.Writer.WriteAsync(i); // Waits when the bounded buffer is full.
            await Task.Delay(25);
        }

        _channel.Writer.TryComplete();
    }

    public async ValueTask DisposeAsync()
    {
        _channel.Writer.TryComplete();
        await _pump; // Async cleanup of the producer loop.
    }
}
```

## Common Follow-up Questions
- Why are async streams considered pull-based rather than push-based?
- When should I prefer `Task<List<T>>` over `IAsyncEnumerable<T>`?
- What role does `Channel<T>` play in async-stream pipelines?
- Why might an async stream also implement `IAsyncDisposable`?
- How do async streams differ from Rx observables?

## Common Mistakes / Pitfalls
- Assuming `await foreach` automatically means “no buffering anywhere.”
- Returning a fully materialized list when streaming would reduce latency or memory.
- Using an unbounded `Channel<T>` without thinking about producer/consumer imbalance.
- Forgetting to dispose stream owners that manage background tasks or connections.
- Confusing pull-based async streams with push-based observables.

## References
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/generate-consume-asynchronous-stream
- https://learn.microsoft.com/dotnet/api/system.collections.generic.iasyncenumerable-1
- https://learn.microsoft.com/dotnet/core/extensions/channels
- https://learn.microsoft.com/dotnet/api/system.iasyncdisposable
- https://learn.microsoft.com/dotnet/api/system.threading.channels.channelreader-1.readallasync