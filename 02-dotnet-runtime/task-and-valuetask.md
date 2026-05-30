# `Task<T>` vs `ValueTask<T>` in .NET

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Junior  
**Tags:** `task`, `valuetask`, `allocation`, `ivalueTaskSource`, `performance`

## Question
> What is the difference between `Task<T>` and `ValueTask<T>` in .NET?

> When should you return `ValueTask<T>` instead of `Task<T>` from an async API?

> Why can `ValueTask<T>` reduce allocations, and what trade-offs come with it?

## Short Answer
`Task<T>` is the standard async result type in .NET: it is easy to compose, await multiple times, and store, but it usually involves a heap object per asynchronous operation. `ValueTask<T>` is a struct that can avoid an allocation when the result is already available synchronously or when a reusable backing source is used. That makes `ValueTask<T>` useful on hot paths such as caches, buffers, or sockets where synchronous completion is common. Outside those measured scenarios, `Task<T>` is usually the better default because it is simpler and less error-prone.

## Detailed Explanation
### Why `Task<T>` is still the default
`Task<T>` is the baseline type for TAP because it is straightforward and highly composable. A `Task<T>` instance can be awaited many times, stored in fields, passed around freely, combined with `Task.WhenAll`, and exposed from public APIs without surprising consumers.

It is also optimized more than many candidates realize. The runtime caches several common task results, such as `Task.CompletedTask` and some `Task.FromResult(...)` cases like `true`, `false`, and a small set of other frequently used values. Even so, a genuinely asynchronous operation typically still needs an object representing its eventual completion.

### What `ValueTask<T>` optimizes
`ValueTask<T>` was introduced so that APIs with frequent synchronous completion do not need to allocate a fresh `Task<T>` every time. It is a struct that can wrap either:

- a direct result value `T`
- an existing `Task<T>`
- an `IValueTaskSource<T>` implementation for reusable pooled completion sources

That means an API can return immediately with zero extra allocation when data is already available, but still fall back to asynchronous completion when needed.

| Aspect | `Task<T>` | `ValueTask<T>` |
| --- | --- | --- |
| Type | Reference type | Struct |
| Typical allocation | Usually one heap object for async work | Can be allocation-free on synchronous completion |
| Multiple awaits | Safe | Usually not safe/expected |
| Storage/composition | Easy | More awkward |
| Best use | General-purpose async APIs | Measured hot paths with common sync completion |

### When `ValueTask<T>` helps
`ValueTask<T>` shines when all of the following are true:

1. the API is called very frequently
2. synchronous completion is common
3. allocations are measurable in profiles or benchmarks
4. consumers will typically await once and immediately

Classic examples are memory buffers, parsers, object pools, channels, socket I/O, and cache lookups. In those paths, shaving one allocation per call can matter.

### When not to use it
`ValueTask<T>` is not a free upgrade. Because it is a struct with more than one possible backing representation, the caller rules are stricter. A consumer should normally await it once and move on.

> Warning: if a result may be awaited multiple times, stored for later, or shared with multiple callers, prefer `Task<T>`. `ValueTask<T>` is an optimization tool, not a default API design choice.

If you need to cache, combine, or repeatedly await the result, call `.AsTask()` or just expose `Task<T>` in the first place.

### `IValueTaskSource<T>` and pooling
For advanced runtime components, `ValueTask<T>` can be backed by `IValueTaskSource<T>`, which lets a reusable object act as the completion source. That is how high-performance internals such as sockets and pipelines reduce allocations even when operations complete asynchronously.

This is powerful but complex: implementers must track tokens, status, continuation registration, and reuse safety correctly. Most application code should consume `ValueTask<T>`, not implement `IValueTaskSource<T>` directly. Related mechanics are easier to understand after reading [async-await-overview.md](./async-await-overview.md) and [async-state-machine.md](./async-state-machine.md).

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace RuntimeSamples.TaskAndValueTask;

internal static class Program
{
    private static async Task Main()
    {
        var cache = new ProductCache();

        string first = await cache.GetNameAsync(1); // Falls back to real async work.
        string second = await cache.GetNameAsync(1); // Completes synchronously from cache.

        Console.WriteLine(first);
        Console.WriteLine(second);
    }
}

internal sealed class ProductCache
{
    private readonly Dictionary<int, string> _items = new();

    public ValueTask<string> GetNameAsync(int id)
    {
        if (_items.TryGetValue(id, out string? cached))
        {
            // Zero extra allocation when the result is already available.
            return ValueTask.FromResult(cached);
        }

        return LoadAndCacheAsync(id);
    }

    private async ValueTask<string> LoadAndCacheAsync(int id)
    {
        // Simulate a truly asynchronous path.
        await Task.Delay(100);

        string value = $"product-{id}";
        _items[id] = value;
        return value;
    }
}
```

## Common Follow-up Questions
- Why is `Task<T>` usually the right default for public APIs?
- What happens if a `ValueTask<T>` is awaited more than once?
- When should a caller convert a `ValueTask<T>` to `Task<T>` with `.AsTask()`?
- What kinds of framework code use `IValueTaskSource<T>`?
- Does `ValueTask<T>` always eliminate allocations?

## Common Mistakes / Pitfalls
- Returning `ValueTask<T>` everywhere without benchmark evidence.
- Storing a `ValueTask<T>` in a field and awaiting it later from multiple places.
- Assuming `ValueTask<T>` is always faster than `Task<T>`.
- Implementing `IValueTaskSource<T>` in application code without understanding token/reuse rules.
- Forgetting that wrapping a real `Task<T>` inside `ValueTask<T>` removes most of the benefit.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.task-1
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.valuetask-1
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.sources.ivaluetasksource-1
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types
- https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/