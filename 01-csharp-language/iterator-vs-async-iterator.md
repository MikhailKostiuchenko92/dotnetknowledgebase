# Iterator vs Async Iterator

**Category:** C# / Async
**Difficulty:** Senior
**Tags:** `iterators`, `async-streams`, `iasyncenumerable`, `yield`

## Question
> What is the difference between a synchronous iterator (`IEnumerable<T>`) and an async iterator (`IAsyncEnumerable<T>`) in C#?
>
> How do `yield return` and `await foreach` relate, and what compiler-generated machinery differs between the two models?
>
> When should I choose an iterator over an async iterator, and how is this different from channels?

## Short Answer
A synchronous iterator produces values on demand through `IEnumerable<T>` and `IEnumerator<T>`, while an async iterator produces values on demand through `IAsyncEnumerable<T>` and `IAsyncEnumerator<T>` with asynchronous waits between items. Both use compiler-generated state machines, but async iterators also coordinate `await`, cancellation, and asynchronous disposal.

## Detailed Explanation
### Same pull model, different waiting model
Both iterators are pull-based: the consumer asks for the next item.

| Aspect | Iterator | Async iterator |
| --- | --- | --- |
| Main abstraction | `IEnumerable<T>` | `IAsyncEnumerable<T>` |
| Consumer syntax | `foreach` | `await foreach` |
| Move-next operation | `bool MoveNext()` | `ValueTask<bool> MoveNextAsync()` |
| Waiting between items | Not built in | Natural with `await` |
| Disposal | `Dispose()` | `DisposeAsync()` |

That means an async iterator is not “push.” It is still demand-driven, just able to pause asynchronously while producing the next element.

> Tip: if data arrives over time from I/O, network, or database pages, `IAsyncEnumerable<T>` is usually the right abstraction. If the data is already in memory or CPU-only, `IEnumerable<T>` is simpler.

See [Async Streams vs Channels](./async-streams-vs-channels.md), [Yield Return Explained](./yield-return-explained.md), and [IAsyncEnumerable](./iasyncenumerable.md).

### Compiler differences
A normal iterator creates a state machine for `yield return`. An async iterator creates a more complex state machine that handles both `yield return` and `await`.

Important differences:
- Async iterators can suspend for asynchronous work between elements
- Cancellation is commonly passed with `await foreach (...).WithCancellation(token)` or `[EnumeratorCancellation]`
- Cleanup may require `await using`-style async disposal under the covers
- Backpressure is still consumer-driven because the next item is requested explicitly

### Iterator vs async iterator vs channel
Async iterators and channels are related but not interchangeable.

| Need | Best fit |
| --- | --- |
| Sequential, pull-based streaming from a producer | `IAsyncEnumerable<T>` |
| Multiple producers/consumers, buffering, coordination | `Channel<T>` |
| Pure in-memory lazy sequence | `IEnumerable<T>` |

> Warning: do not use `IAsyncEnumerable<T>` just because an API is modern. If every element is already available synchronously, the async overhead adds complexity without value.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

await foreach (var number in CountWithDelayAsync())
{
    Console.WriteLine(number);
}

foreach (var number in CountSync())
{
    Console.WriteLine(number);
}

static IEnumerable<int> CountSync()
{
    for (var i = 1; i <= 3; i++)
    {
        yield return i; // Pure synchronous pull-based iteration.
    }
}

static async IAsyncEnumerable<int> CountWithDelayAsync()
{
    for (var i = 1; i <= 3; i++)
    {
        await Task.Delay(50); // Simulates asynchronous arrival of data.
        yield return i;
    }
}
```

## Common Follow-up Questions
- Why is `IAsyncEnumerable<T>` still considered pull-based rather than push-based?
- When should I choose a channel instead of an async iterator?
- What extra state does the compiler generate for async iterators?
- How does cancellation flow into `await foreach`?
- Why can async iterators be a poor fit for already materialized data?

## Common Mistakes / Pitfalls
- Assuming `IAsyncEnumerable<T>` automatically means parallel or push-based processing.
- Returning `IAsyncEnumerable<T>` for data that is already fully in memory.
- Forgetting about asynchronous disposal and cancellation in longer-running streams.
- Using channels and async iterators interchangeably even though their coordination models differ.
- Treating async iterators as faster by default instead of matching the abstraction to the workload.

## References
- [Microsoft Docs: Generate and consume async streams](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/generate-consume-asynchronous-stream)
- [Microsoft Docs: IAsyncEnumerable<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.iasyncenumerable-1)
- [Microsoft Docs: The `yield` statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/yield)
- [See: Async Streams vs Channels](./async-streams-vs-channels.md)
- [See: `yield return` Explained](./yield-return-explained.md)
- [See: IAsyncEnumerable](./iasyncenumerable.md)
