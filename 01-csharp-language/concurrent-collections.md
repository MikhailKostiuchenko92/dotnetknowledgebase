# Concurrent Collections

**Category:** C# / Collections & LINQ
**Difficulty:** 🔴 Senior
**Tags:** `ConcurrentDictionary`, `ConcurrentBag`, `ConcurrentQueue`, `BlockingCollection`, `thread-safety`, `lock-free`

## Question

> What concurrent collections does .NET provide, and when should you use each? How does `ConcurrentDictionary<TKey, TValue>` achieve thread safety?

Additional phrasings:
- *"What is the difference between `ConcurrentBag<T>` and `ConcurrentQueue<T>`?"*
- *"When is `ConcurrentDictionary` NOT safe, and what pattern should you use instead?"*

## Short Answer

.NET's `System.Collections.Concurrent` namespace provides lock-free or fine-grained-locking collections: `ConcurrentDictionary` (striped locking, safe for all operations), `ConcurrentQueue` (lock-free FIFO), `ConcurrentStack` (lock-free LIFO), `ConcurrentBag` (thread-local storage, good for same-thread produce-and-consume), and `BlockingCollection` (bounded producer-consumer wrapper). `ConcurrentDictionary` is the most commonly used; its key pitfall is that **read-modify-write sequences are not atomic** — use `AddOrUpdate` and `GetOrAdd` with the correct overloads, or use `ImmutableInterlocked` for snapshot semantics.

## Detailed Explanation

### Why Regular Collections Are Not Thread-Safe

`Dictionary<K,V>`, `List<T>`, etc. are not safe for concurrent modification. A concurrent `Add` + `Add` can corrupt internal state (infinite loop in hash chains, data loss). Even concurrent reads while a writer is active can crash. All accesses to these types must be serialized (e.g., with `lock`).

### `ConcurrentDictionary<TKey, TValue>`

The most frequently used concurrent collection. Uses **lock striping**: the internal buckets are divided into segments (number of segments = `concurrencyLevel`, default = `Environment.ProcessorCount * 4`), and only one lock per segment is held during mutation. This allows concurrent writes to different key groups and always-concurrent reads.

**Thread-safe operations:**
- `TryAdd`, `TryGetValue`, `TryRemove`, `TryUpdate` — atomic single-key operations.
- `GetOrAdd(key, valueFactory)` — get or add atomically.
- `AddOrUpdate(key, addFactory, updateFactory)` — update atomically.
- `Count`, `IsEmpty`, `ContainsKey` — safe reads.

**Not atomic (pitfall):**
```csharp
// ❌ Check-then-act: another thread may Add between ContainsKey and Add
if (!dict.ContainsKey(key))
    dict[key] = value;

// ✅ Atomic:
dict.TryAdd(key, value);
```

**`GetOrAdd` factory is not guaranteed to run only once:**
```csharp
// The factory may be called multiple times if two threads miss simultaneously;
// only one value wins — but the factory runs for both
var conn = dict.GetOrAdd(key, k => new DatabaseConnection(k)); // factory may run 2×
```

If the factory is expensive or has side effects, use `GetOrAdd(key, value)` (pre-computed) or `Lazy<T>` as the value:
```csharp
var lazy = dict.GetOrAdd(key, k => new Lazy<T>(() => CreateExpensive(k)));
T result = lazy.Value; // initialization is thread-safe within Lazy<T>
```

**`AddOrUpdate` atomicity:**
`AddOrUpdate` is atomic per-call but the `updateFactory` delegate **may be called more than once** under contention — it must be pure (no side effects, idempotent):
```csharp
// Safe: pure increment
dict.AddOrUpdate(key, 1, (k, oldVal) => oldVal + 1);

// Unsafe: if factory has side effects, they may run multiple times
dict.AddOrUpdate(key, 1, (k, old) => { _sideEffect(); return old + 1; });
```

### `ConcurrentQueue<T>` — Lock-Free FIFO

Uses a linked-list of segments with interlocked pointer operations. Safe for concurrent `Enqueue` from multiple producers and concurrent `TryDequeue` from multiple consumers. Ideal for work queues.

```csharp
var queue = new ConcurrentQueue<int>();
queue.Enqueue(1);
if (queue.TryDequeue(out int item)) Console.WriteLine(item);
queue.TryPeek(out int next); // peek without removing
```

### `ConcurrentStack<T>` — Lock-Free LIFO

Uses an interlocked linked list. `Push`/`TryPop` are atomic. Also has `PushRange`/`TryPopRange` for batch operations (more efficient than individual calls under contention).

### `ConcurrentBag<T>` — Unordered, Thread-Local Optimized

`ConcurrentBag` uses **thread-local storage** for its backing store: each thread has its own list. Adding to and removing from your own list is essentially lock-free. Stealing from another thread's list requires a lock. This makes `ConcurrentBag` efficient when the **same thread** both produces and consumes items (e.g., a worker thread that recycles objects it just finished with). Poor choice when a producer thread feeds consumer threads — `ConcurrentQueue` is better there.

### `BlockingCollection<T>` — Bounded Producer-Consumer

`BlockingCollection<T>` wraps any `IProducerConsumerCollection<T>` (default: `ConcurrentQueue<T>`) and adds:
- **Bounded capacity**: `Add` blocks when full (backpressure).
- **Blocking `Take`**: consumer blocks when empty.
- **`CompleteAdding()` / `IsCompleted`**: signals end-of-work.
- **`GetConsumingEnumerable()`**: `foreach`-friendly consumer.

Good for classic bounded producer-consumer pipelines. For more advanced async scenarios, prefer `Channel<T>` ([See: producer-consumer-with-channel.md](./producer-consumer-with-channel.md)).

### Collection Comparison

| Collection | Order | Thread model | Blocking | Use case |
|---|---|---|---|---|
| `ConcurrentDictionary` | None | Any | No | Shared cache, counters |
| `ConcurrentQueue` | FIFO | Multi-prod / multi-cons | No | Work queues |
| `ConcurrentStack` | LIFO | Multi-prod / multi-cons | No | Undo stacks, DFS |
| `ConcurrentBag` | None | Same-thread prod+cons | No | Object pools |
| `BlockingCollection` | Depends on backing | Multi-prod / multi-cons | Yes | Bounded pipelines |

## Code Example

```csharp
using System.Collections.Concurrent;
using System.Threading.Tasks;

// === ConcurrentDictionary: safe counter ===
var counter = new ConcurrentDictionary<string, int>();

Parallel.For(0, 100, _ =>
{
    // ✅ Atomic increment — no race condition
    counter.AddOrUpdate("hits", 1, (_, old) => old + 1);
});
Console.WriteLine(counter["hits"]); // 100

// === GetOrAdd with Lazy<T> for expensive factory ===
var cache = new ConcurrentDictionary<string, Lazy<string>>();
string result = cache
    .GetOrAdd("key", k => new Lazy<string>(() => ComputeExpensive(k)))
    .Value;
Console.WriteLine(result);

static string ComputeExpensive(string k) { Thread.Sleep(10); return $"value:{k}"; }

// === ConcurrentQueue: producer-consumer ===
var workQueue = new ConcurrentQueue<int>();

// Producer task
var producer = Task.Run(() =>
{
    for (int i = 0; i < 10; i++) workQueue.Enqueue(i);
});

// Consumer task
var consumer = Task.Run(async () =>
{
    int processed = 0;
    while (processed < 10)
    {
        if (workQueue.TryDequeue(out int item))
        {
            Console.Write($"{item} ");
            processed++;
        }
        else
            await Task.Yield(); // avoid busy-waiting
    }
});

await Task.WhenAll(producer, consumer);
Console.WriteLine();

// === BlockingCollection: bounded pipeline with backpressure ===
using var collection = new BlockingCollection<int>(boundedCapacity: 5);

var bProducer = Task.Run(() =>
{
    for (int i = 0; i < 20; i++)
    {
        collection.Add(i); // blocks when capacity (5) is reached
        Console.Write($"+{i} ");
    }
    collection.CompleteAdding(); // signal done
});

var bConsumer = Task.Run(() =>
{
    foreach (int item in collection.GetConsumingEnumerable())
        Console.Write($"-{item} ");
});

await Task.WhenAll(bProducer, bConsumer);

// === ConcurrentBag: object pool pattern ===
var pool = new ConcurrentBag<StringBuilder>();

static StringBuilder Rent(ConcurrentBag<StringBuilder> pool)
    => pool.TryTake(out var sb) ? sb : new StringBuilder();

static void Return(ConcurrentBag<StringBuilder> pool, StringBuilder sb)
{
    sb.Clear();
    pool.Add(sb); // return to pool
}
```

## Common Follow-up Questions

- When should you use `Channel<T>` instead of `BlockingCollection<T>`?
- How does lock striping in `ConcurrentDictionary` differ from a single global lock?
- Is `ConcurrentDictionary.Count` reliable for decision-making in multi-threaded code?
- What is the difference between `ConcurrentDictionary` and `ImmutableDictionary` for thread-safe reads?
- How does `ConcurrentQueue<T>` avoid locks internally?
- When is it appropriate to use `lock` on a regular `Dictionary` vs switching to `ConcurrentDictionary`?

## Common Mistakes / Pitfalls

- **Read-check-then-write on `ConcurrentDictionary`.** `ContainsKey` + `Add`, or `TryGetValue` + assign are not atomic. Use `TryAdd`, `AddOrUpdate`, or `GetOrAdd` for atomic semantics.
- **Relying on `GetOrAdd` factory running exactly once.** Under contention, multiple threads may invoke the factory; only one value is stored. If the factory is expensive or non-idempotent, use `Lazy<T>` as the value type.
- **Using `ConcurrentBag` for a multi-producer/multi-consumer pipeline.** `ConcurrentBag` is optimized for same-thread produce-and-consume. For separate producer and consumer threads, `ConcurrentQueue` or `Channel<T>` is more appropriate.
- **Holding the result of `ConcurrentDictionary.Count` as an invariant.** `Count` is computed by summing all segment counts — it's a point-in-time snapshot. By the time you act on it, the count may have changed.
- **Using `BlockingCollection` in async code.** `BlockingCollection.Take()` blocks the calling thread synchronously. In `async` methods this occupies a thread pool thread. Use `Channel<T>` with `await channel.Reader.ReadAsync()` for async-friendly producer-consumer.

## References

- [ConcurrentDictionary<TKey,TValue> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.concurrent.concurrentdictionary-2)
- [ConcurrentQueue<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.concurrent.concurrentqueue-1)
- [BlockingCollection<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.concurrent.blockingcollection-1)
- [Thread-safe collections — .NET docs](https://learn.microsoft.com/dotnet/standard/collections/thread-safe/)
- [When to use a thread-safe collection — .NET docs](https://learn.microsoft.com/dotnet/standard/collections/thread-safe/when-to-use-a-thread-safe-collection)
