# Thread Safety of Collections

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `collections`, `thread-safety`, `List<T>`, `Dictionary<TKey,TValue>`, `ConcurrentDictionary`, `ImmutableArray`

## Question
> Which .NET collection types are thread-safe, which are not, and what bugs commonly appear when `List<T>` or `Dictionary<TKey,TValue>` are shared across threads?

Also asked as:
- "Is it safe to read from a `List<T>` or `Dictionary<TKey,TValue>` from multiple threads?"
- "When should I use `ConcurrentDictionary`, immutable collections, or my own `lock` around a normal collection?"

## Short Answer
Most ordinary BCL collections such as `List<T>`, `Dictionary<TKey,TValue>`, `HashSet<T>`, and `Queue<T>` are **not** safe for concurrent mutation and usually not safe for mixed read/write access either. For shared mutable access, use the collection from `System.Collections.Concurrent`, immutable collections, or an explicit synchronization strategy such as `lock`. `List<T>` and `Dictionary<TKey,TValue>` bugs often show up as lost updates, exceptions during enumeration, stale reads, or corrupted assumptions around check-then-act logic.

## Detailed Explanation

### The default rule: ordinary collections are not thread-safe
The generic collections in `System.Collections.Generic` are optimized for single-threaded correctness and speed. They do not synchronize their own internal state. That means operations like resize, rehash, add, remove, and enumeration can race with each other.

For example, a `List<T>.Add` may trigger an array resize and copy. If another thread is reading or writing at the same time, the reader can observe inconsistent state or the writer can overwrite assumptions made by the first thread.

### Safe, unsafe, and conditionally safe choices
A useful interview answer is to split collections into categories.

| Collection family | Thread-safe for concurrent mutation? | Typical strategy |
|---|---|---|
| `List<T>`, `Dictionary<TKey,TValue>`, `HashSet<T>` | No | Protect with `lock` or avoid sharing |
| `ConcurrentDictionary`, `ConcurrentQueue`, `ConcurrentBag` | Yes for supported operations | Use built-in atomic APIs |
| Immutable collections | Yes for concurrent reads and sharing | Replace whole snapshot on update |
| Frozen collections | Safe for concurrent reads after creation | Build once, then share read-only |

### Common `List<T>` bugs
With `List<T>`, common failures include:

- two threads appending and losing data or racing during resize
- one thread enumerating while another mutates, causing `InvalidOperationException`
- check-then-act bugs like `if (list.Count > 0) list.RemoveAt(0)` without synchronization

Even read-only access is only safe if the collection is no longer being mutated anywhere.

### Common `Dictionary<TKey,TValue>` bugs
`Dictionary<TKey,TValue>` is especially dangerous under concurrent writes because it may rehash and rebalance internal buckets. Common issues include:

- `ContainsKey` followed by add or index assignment is not atomic
- enumeration while mutating throws
- multiple writers can produce lost updates or inconsistent expectations

If you need concurrent keyed updates, `ConcurrentDictionary<TKey,TValue>` is the standard choice.

> **Warning:** "Mostly reads, only occasional writes" is still not safe for normal mutable collections unless you synchronize those writes and the reads that overlap with them.

### Choosing the right strategy
The right answer depends on the workload:

- **Shared mutable queue/dictionary:** use concurrent collections.
- **Read-mostly configuration snapshot:** immutable collections are often simpler.
- **Small internal state with multi-step invariants:** a `lock` around a normal collection can be the clearest design.
- **Precomputed lookup used only for reads after startup:** frozen collections are excellent.

### Enumeration and snapshots
A subtle but important point: some concurrent collections allow safe concurrent enumeration, but the enumeration is often a moment-in-time snapshot or has relaxed semantics. It is safe, but not necessarily a perfectly current transactionally consistent view.

### Practical guidance
If you have to perform several related operations together, a plain `lock` around a normal collection may still be the right abstraction. If you only need individual atomic dictionary or queue operations, prefer the concurrent type. If the data is naturally replaced as a whole, immutable collections often beat locking in clarity.

### Read-only wrappers are not the same as thread safety
Another common misunderstanding is confusing "read-only" with "thread-safe." A read-only view only prevents mutation through that API surface. It does not stop some other part of the program from mutating the underlying collection at the same time. True thread safety requires either no mutation at all after publication, or synchronization around every overlapping mutation and read.

That is why immutable and frozen collections are powerful: they do not just hide mutation; they eliminate it from the shared instance.

### Pick operations, not types, as your unit of reasoning
A collection can be thread-safe for individual operations and still be the wrong tool for a larger multi-step workflow. For example, dequeue-then-update-two-other-structures may still need a surrounding design-level synchronization strategy. Thinking in terms of end-to-end invariants prevents false confidence.

That is why experienced engineers often choose a collection together with its surrounding access protocol, not as an isolated data-structure decision.

> **Tip:** do not ask "which collection is thread-safe?" in isolation. Ask "what access pattern do I need to support safely and clearly?"

## Code Example
```csharp
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Threading.Tasks;

// 1. ConcurrentDictionary for shared mutable keyed state.
var counters = new ConcurrentDictionary<string, int>();

Parallel.For(0, 10_000, _ =>
{
    counters.AddOrUpdate("hits", 1, (_, current) => current + 1);
});

Console.WriteLine($"Hits: {counters["hits"]}");

// 2. Plain List<T> protected by a lock for multi-step operations.
var values = new List<int>();
object gate = new();

Task[] writers = new Task[4];
for (int i = 0; i < writers.Length; i++)
{
    int workerId = i;
    writers[i] = Task.Run(() =>
    {
        for (int j = 0; j < 100; j++)
        {
            lock (gate)
            {
                // The lock protects both Add and any related invariants.
                values.Add(workerId * 1_000 + j);
            }
        }
    });
}

await Task.WhenAll(writers);
Console.WriteLine($"Protected list count: {values.Count}");

// 3. Immutable snapshot: replace the whole value when updating.
ImmutableArray<string> snapshot = ["alpha", "beta"];
snapshot = snapshot.Add("gamma"); // Creates a new snapshot safely sharable across threads.
Console.WriteLine(string.Join(", ", snapshot));
```

## Common Follow-up Questions
- When is `ConcurrentDictionary<TKey,TValue>` better than `lock` around `Dictionary<TKey,TValue>`?
- How do immutable and frozen collections differ for concurrent reading?
- Are concurrent collection enumerations fully up to date or snapshot-like?
- Why is `ContainsKey` plus add a race, even if the dictionary itself is concurrent?
- How does this relate to [concurrent-collections.md](./concurrent-collections.md) and [reader-writer-lockslim.md](./reader-writer-lockslim.md)?

## Common Mistakes / Pitfalls
- Sharing `List<T>` or `Dictionary<TKey,TValue>` across threads without one clear synchronization strategy.
- Assuming "read-only most of the time" makes a mutable collection safe while occasional writes still happen.
- Enumerating a mutable collection while another thread modifies it.
- Using `ConcurrentDictionary` but still writing non-atomic check-then-act logic around it.
- Reaching for a concurrent collection when immutable snapshots would make the design simpler.

## References
- [Thread-safe collections — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/collections/thread-safe/)
- [ConcurrentDictionary<TKey,TValue> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.collections.concurrent.concurrentdictionary-2)
- [Immutable collections — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.collections.immutable)
- [See: concurrent-collections.md](./concurrent-collections.md)
- [See: frozencollections.md](./frozencollections.md)
- [See: immutablecollections.md](./immutablecollections.md)
