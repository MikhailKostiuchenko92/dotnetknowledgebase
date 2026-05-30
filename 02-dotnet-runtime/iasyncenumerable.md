# What Is `IAsyncEnumerable<T>`?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `iasyncenumerable`, `await-foreach`, `async-iterators`, `cancellation`, `channels`

## Question
> What is `IAsyncEnumerable<T>` and how is it different from `IEnumerable<T>`?

> How does `await foreach` work with asynchronous streams in C#?

> How do you cancel an async stream, and when would you use `Channel<T>` instead?

## Short Answer
`IAsyncEnumerable<T>` represents an asynchronous pull-based sequence: the consumer asks for the next item, but each move to the next item can itself be asynchronous. It is consumed with `await foreach`, and `async` iterators using `yield return` compile into an async iterator state machine. Cancellation is usually passed via `WithCancellation(token)` or an `[EnumeratorCancellation]` parameter. Compared with `IObservable<T>`, async streams are pull-based; compared with `Channel<T>`, they are a higher-level sequence abstraction rather than a buffering primitive.

## Detailed Explanation
### Async pull instead of synchronous pull
`IEnumerable<T>` is a synchronous pull model: the consumer calls `MoveNext()`, and the producer must have the next value ready immediately. That works well for in-memory collections but not for data that naturally arrives later, such as paged APIs, sockets, database cursors, or file/network chunking.

`IAsyncEnumerable<T>` keeps the pull model but makes moving to the next item asynchronous. The consumer still controls the pace, but each step can `await` I/O.

| Model | Consumer syntax | Delivery style | Good fit |
| --- | --- | --- | --- |
| `IEnumerable<T>` | `foreach` | Synchronous pull | In-memory or immediately available data |
| `IAsyncEnumerable<T>` | `await foreach` | Asynchronous pull | Streaming I/O, pages, chunks, cursors |
| `IObservable<T>` | subscription/callback | Asynchronous push | Event streams and reactive pipelines |

### Async iterators and the generated state machine
C# supports async iterators with methods like `async IAsyncEnumerable<T>`. Inside them, you can `await` and `yield return` in the same method. The compiler rewrites that into an async iterator state machine, similar in spirit to both iterator methods and `async` methods.

That is a big usability win: instead of buffering an entire result set into a `List<T>`, you can stream items one at a time as they become available. Consumers start processing earlier, memory pressure stays lower, and cancellation becomes more responsive.

### Cancellation is explicit
Because async streams can run for a long time, cancellation matters. Two common patterns are:

- `await foreach (var item in stream.WithCancellation(token))`
- declaring the iterator parameter with `[EnumeratorCancellation] CancellationToken cancellationToken = default`

The attribute tells the compiler which parameter should receive the consumer's enumeration token. Without it, developers often accidentally accept a token that is never applied to the actual enumeration flow.

> Warning: cancellation in async streams is cooperative. The producer still has to observe the token in awaited operations or explicitly call `ThrowIfCancellationRequested()`.

### `Channel<T>` and buffering
`IAsyncEnumerable<T>` describes a sequence. `Channel<T>` describes a producer/consumer queue with optional bounding and buffering. They are related but not interchangeable.

If one producer and one consumer run at different speeds, a bounded `Channel<T>` can absorb short bursts and apply backpressure. The reader side can then expose `ReadAllAsync()` as an `IAsyncEnumerable<T>`. That makes channels a common internal transport for async stream pipelines. See also [channel-t.md](./channel-t.md) and [async-streams.md](./async-streams.md).

### Re-enumeration behavior
Like ordinary iterators, an `IAsyncEnumerable<T>` can represent work that runs again on each enumeration. That is sometimes what you want and sometimes a surprise. If a stream talks to a remote system, enumerating twice may repeat the entire operation.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.IAsyncEnumerableDemo;

internal static class Program
{
    private static async Task Main()
    {
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));

        await foreach (int page in ReadPagesAsync(5, cts.Token).WithCancellation(cts.Token))
        {
            Console.WriteLine($"Received page {page}");
        }
    }

    private static async IAsyncEnumerable<int> ReadPagesAsync(
        int count,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        for (int page = 1; page <= count; page++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            // Simulate asynchronous I/O before each element becomes available.
            await Task.Delay(100, cancellationToken);
            yield return page;
        }
    }
}
```

## Common Follow-up Questions
- How is `IAsyncEnumerable<T>` different from `Task<List<T>>`?
- What does `[EnumeratorCancellation]` actually change?
- When should I use `Channel<T>` behind an async stream?
- How is `IAsyncEnumerable<T>` different from `IObservable<T>`?
- Does enumerating an async stream twice rerun the producer logic?

## Common Mistakes / Pitfalls
- Returning `Task<List<T>>` when the data could be streamed item by item.
- Forgetting to propagate cancellation into awaited operations inside the iterator.
- Assuming `IAsyncEnumerable<T>` is push-based like Rx.
- Re-enumerating a stream and accidentally repeating expensive I/O.
- Treating `Channel<T>` as identical to `IAsyncEnumerable<T>` instead of a lower-level coordination primitive.

## References
- https://learn.microsoft.com/dotnet/api/system.collections.generic.iasyncenumerable-1
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/generate-consume-asynchronous-stream
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.enumeratorcancellationattribute
- https://learn.microsoft.com/dotnet/core/extensions/channels
- https://learn.microsoft.com/dotnet/csharp/language-reference/statements/iteration-statements#await-foreach