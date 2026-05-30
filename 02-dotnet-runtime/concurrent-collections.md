# What Are the Main Concurrent Collections in .NET?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Middle  
**Tags:** `concurrentdictionary`, `concurrentqueue`, `concurrentstack`, `concurrentbag`, `blockingcollection`

## Question
> Which concurrent collections does .NET provide, and when should you use each one?
>
> How is `ConcurrentDictionary<TKey,TValue>` different from `ImmutableDictionary<TKey,TValue>`?
>
> What are the atomicity guarantees and caveats of methods like `GetOrAdd` and `AddOrUpdate`?

## Short Answer
.NET provides specialized collections for common concurrent access patterns: `ConcurrentDictionary<TKey,TValue>` for shared key/value state, `ConcurrentQueue<T>` and `ConcurrentStack<T>` for FIFO/LIFO producer-consumer patterns, `ConcurrentBag<T>` for mostly same-thread work-stealing scenarios, and `BlockingCollection<T>` as a higher-level wrapper that can add bounding and blocking consumption. They are safer and usually faster than wrapping `List<T>` or `Dictionary<TKey,TValue>` with a single lock because their internal algorithms are tailored to the data structure. For snapshot-style sharing, `ImmutableDictionary<TKey,TValue>` is a different trade-off: updates create a new structure instead of mutating one shared instance.

## Detailed Explanation
### Why concurrent collections exist
A plain `Dictionary<TKey,TValue>` is not safe for concurrent reads and writes. You can protect it with `lock`, but one coarse lock often becomes a bottleneck and makes the code harder to reason about. The concurrent collections in `System.Collections.Concurrent` package common access patterns into well-tested implementations with finer-grained coordination or lock-free algorithms.

### `ConcurrentDictionary<TKey,TValue>`
`ConcurrentDictionary<TKey,TValue>` is the workhorse for shared mutable key/value state. The common interview explanation is “striped locking”: instead of one global lock, updates coordinate through multiple internal lock regions, historically defaulting to roughly 4× CPU count in the classic implementation. Exact internals have evolved across runtime versions, but the important idea remains that unrelated keys can often proceed with less contention than a single global lock.

It also exposes atomic compound operations such as `TryAdd`, `TryUpdate`, `GetOrAdd`, and `AddOrUpdate`.

> The dictionary update is atomic, but the delegate you pass to `GetOrAdd` or `AddOrUpdate` may run more than once and is not a safe place for non-idempotent side effects like charging a credit card or incrementing a global counter.

### Queue, stack, and bag
`ConcurrentQueue<T>` is the typical FIFO producer-consumer collection. It uses a lock-free segmented design optimized for many enqueuers and dequeuers. Reach for it when ordering matters and multiple threads exchange work items.

`ConcurrentStack<T>` is the LIFO counterpart. It is implemented with compare-and-swap style operations (`Interlocked.CompareExchange`) rather than coarse locking. It works well for pools or algorithms where the most recently produced item is the most useful.

`ConcurrentBag<T>` is different. It keeps thread-local work lists and uses stealing when another thread needs items. That makes it great when the same thread often both produces and consumes items, but less ideal when one dedicated producer thread feeds a different dedicated consumer thread. In that case, `ConcurrentQueue<T>` is usually a better fit.

### `ImmutableDictionary` versus `ConcurrentDictionary`
Both solve concurrency, but with opposite strategies.

| Type | Strategy | Best when | Trade-off |
| --- | --- | --- | --- |
| `ConcurrentDictionary<TKey,TValue>` | Shared mutable structure with concurrent coordination | Frequent reads and writes on one shared map | Readers may observe ongoing mutations |
| `ImmutableDictionary<TKey,TValue>` | Every update returns a new snapshot | Readers need stable snapshots and lock-free reads | Writes allocate a new version |

Immutable collections shine in configuration snapshots, routing tables, or caches where readers want a consistent point-in-time view and writers can publish a replacement reference atomically.

### `BlockingCollection<T>`
`BlockingCollection<T>` is a higher-level producer-consumer wrapper over any `IProducerConsumerCollection<T>` implementation, often a `ConcurrentQueue<T>`. It can add a bounded capacity and offers blocking methods such as `Take()` plus consuming enumeration. That made it popular before async-first APIs became standard.

Today, it still works well for dedicated worker threads, but it is not ideal for async pipelines because blocking methods occupy threads while waiting. For async producer-consumer workflows, [Channel<T>](./channel-t.md) is usually the better modern choice.

### Practical selection guide

| Collection | Best use | Core characteristic | Main caveat |
| --- | --- | --- | --- |
| `ConcurrentDictionary<TKey,TValue>` | Shared map/cache | Fine-grained concurrent updates | Delegate factories can run multiple times |
| `ConcurrentQueue<T>` | FIFO work queue | Lock-free segmented queue | No bounding by itself |
| `ConcurrentStack<T>` | LIFO pools/backtracking | Lock-free CAS stack | Ordering is LIFO, not fair |
| `ConcurrentBag<T>` | Same-thread produce/consume | Thread-local lists + stealing | Poor fit for strict cross-thread handoff |
| `BlockingCollection<T>` | Bounded blocking producer-consumer | Wraps another concurrent collection | Blocking, not async |

## Code Example
```csharp
using System.Collections.Concurrent;
using System.Collections.Immutable;

namespace RuntimeSamples.ConcurrentCollections;

internal static class Program
{
    public static void Main()
    {
        var counts = new ConcurrentDictionary<string, int>();
        var queue = new ConcurrentQueue<int>();
        var bag = new ConcurrentBag<int>();
        using var blocking = new BlockingCollection<int>(boundedCapacity: 2);

        Parallel.ForEach(Enumerable.Range(1, 6), item =>
        {
            queue.Enqueue(item); // FIFO handoff.
            bag.Add(item);       // Optimized for same-thread reuse patterns.

            counts.AddOrUpdate(
                key: item % 2 == 0 ? "even" : "odd",
                addValueFactory: _ => 1,
                updateValueFactory: (_, current) => current + 1); // Keep this delegate side-effect free.
        });

        blocking.Add(10);
        blocking.Add(20);
        blocking.CompleteAdding();

        Console.WriteLine($"Counts: odd={counts["odd"]}, even={counts["even"]}");

        while (queue.TryDequeue(out var value))
        {
            Console.WriteLine($"Dequeued: {value}");
        }

        Console.WriteLine($"Bag count: {bag.Count}");

        foreach (var value in blocking.GetConsumingEnumerable())
        {
            Console.WriteLine($"BlockingCollection consumed: {value}");
        }

        var immutable = ImmutableDictionary<string, int>.Empty.Add("version", 1);
        immutable = immutable.SetItem("version", 2); // Publish a new snapshot instead of mutating shared state.
        Console.WriteLine($"Immutable snapshot version: {immutable["version"]}");
    }
}
```

## Common Follow-up Questions
- Are `GetOrAdd` and `AddOrUpdate` delegates guaranteed to run only once?
- When is `ConcurrentBag<T>` a bad choice despite being thread-safe?
- Why might immutable collections outperform mutable concurrent collections for read-mostly data?
- What does `BlockingCollection<T>` add on top of `ConcurrentQueue<T>`?
- How would you bound a producer-consumer queue without blocking threads?

## Common Mistakes / Pitfalls
- Putting side effects inside `ConcurrentDictionary` factory delegates.
- Choosing `ConcurrentBag<T>` for strict FIFO or cross-thread handoff scenarios.
- Assuming concurrent collections remove all need to think about higher-level invariants.
- Using `BlockingCollection<T>` in async server code where blocked threads hurt scalability.
- Replacing immutable snapshots with shared mutable dictionaries in read-heavy code paths.

## References
- https://learn.microsoft.com/dotnet/standard/collections/thread-safe/
- https://learn.microsoft.com/dotnet/api/system.collections.concurrent.concurrentdictionary-2
- https://learn.microsoft.com/dotnet/api/system.collections.concurrent.concurrentqueue-1
- https://learn.microsoft.com/dotnet/api/system.collections.concurrent.blockingcollection-1
- https://learn.microsoft.com/dotnet/api/system.collections.immutable.immutabledictionary-2
