# `ReaderWriterLockSlim`

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `ReaderWriterLockSlim`, `lock`, `upgradeable-read-lock`, `thread-safety`, `contention`

## Question
> What is `ReaderWriterLockSlim`, how is it different from `lock`, and when does it actually pay off?

Also asked as:
- "What is an upgradeable read lock, and why does `ReaderWriterLockSlim` have one?"
- "Why is `ReaderWriterLockSlim` not automatically better than a normal `lock`?"

## Short Answer
`ReaderWriterLockSlim` allows many readers to enter concurrently while still giving writers exclusive access, which can help when reads are frequent, writes are rare, and the protected work is substantial enough to justify the extra coordination cost. Its upgradeable read lock lets one thread read first and then safely switch to writing without racing another upgrader. For small critical sections or mixed read/write workloads, a plain `lock` is often simpler and just as fast or faster.

## Detailed Explanation

### How it differs from `lock`
A normal `lock` is exclusive: one thread at a time, regardless of whether the work is read-only or mutating. `ReaderWriterLockSlim` splits access modes:

- **read lock**: many readers can hold it at once
- **write lock**: only one writer, and no readers
- **upgradeable read lock**: one thread may read with the option to upgrade to write later

That sounds strictly better, but it comes with more bookkeeping and more ways to misuse it.

| Primitive | Concurrent readers | Concurrent writers | Complexity | Best fit |
|---|---|---|---|---|
| `lock` | No | No | Low | Small, simple critical sections |
| `ReaderWriterLockSlim` | Yes | No | Higher | Read-heavy shared state |

### When it pays off
`ReaderWriterLockSlim` helps when all of these are true:

1. Reads vastly outnumber writes.
2. Reads are long enough or frequent enough that allowing concurrency matters.
3. The protected state cannot easily be made immutable or replaced with a concurrent collection.

If the code inside the critical section is tiny, the overhead can outweigh the benefit. In those cases, a `lock` may be faster and is almost always easier to understand.

### Upgradeable read lock
The upgradeable read lock exists to avoid a common race. Imagine you need to check whether a key exists and add it if not. If you enter an ordinary read lock, then exit and later enter a write lock, another thread can change the state in between.

The upgradeable mode says, "I am the only potential upgrader right now." You can inspect state under read semantics and then switch to a write lock only if needed.

That is useful for cache-like patterns, but there can be only one upgradeable reader at a time, so overusing it reduces concurrency.

> **Warning:** do not treat upgradeable read mode as the default. If every caller takes it, you lose most of the reader parallelism you wanted in the first place.

### Reentrancy and disposal
`ReaderWriterLockSlim` is disposable and should be disposed when the owning component is done. By default, it is not intended for arbitrary recursive entry patterns; you can enable recursion support, but that usually signals design complexity rather than elegance.

### Practical alternatives
Before choosing `ReaderWriterLockSlim`, ask whether one of these is simpler:

- immutable snapshots for mostly-read data
- `ConcurrentDictionary<TKey,TValue>` for keyed access
- a plain `lock` because the critical section is tiny

### Guidelines for good usage
- Keep the locked section short.
- Never `await` while holding the lock.
- Acquire and release in `try/finally`.
- Prefer ordinary read locks for pure reads, and use upgradeable mode only when a write might happen conditionally.

### Costs and contention behavior
`ReaderWriterLockSlim` wins only when it can exploit genuine reader parallelism. If writes are frequent, or if readers are so short that coordination dominates the work, the extra machinery can cost more than it saves. There is also an application-design cost: the more lock modes a team has to reason about, the easier it is to create accidental bottlenecks.

Another practical consideration is writer progress. A reader-heavy workload can still make writes feel expensive because writers must wait for active readers to drain before entering. That is fine when writes are rare, but it can become a latency problem when the data changes often.

### A design smell to watch for
If code often needs to "peek, maybe mutate, maybe downgrade, maybe upgrade again," the shared-state design may be too complicated. Sometimes the better fix is not a fancier lock but a simpler data flow, such as immutable snapshots or a dedicated owning component.

That architectural simplification often improves both correctness and performance more than a more sophisticated locking strategy.

> **Tip:** benchmark before "optimizing" to `ReaderWriterLockSlim`. It is a targeted tool, not a universal upgrade over `lock`.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

var cache = new SettingsCache();

Task writer = Task.Run(() => cache.Set("theme", "dark"));
Task<string?> reader1 = Task.Run(() => cache.Get("theme"));
Task<string?> reader2 = Task.Run(() => cache.GetOrAdd("language", () => "en-US"));

await Task.WhenAll(writer, reader1, reader2);
Console.WriteLine($"theme = {reader1.Result}");
Console.WriteLine($"language = {reader2.Result}");

sealed class SettingsCache : IDisposable
{
    private readonly ReaderWriterLockSlim _lock = new();
    private readonly Dictionary<string, string> _values = new();

    public string? Get(string key)
    {
        _lock.EnterReadLock();
        try
        {
            return _values.TryGetValue(key, out string? value) ? value : null;
        }
        finally
        {
            _lock.ExitReadLock();
        }
    }

    public void Set(string key, string value)
    {
        _lock.EnterWriteLock();
        try
        {
            _values[key] = value;
        }
        finally
        {
            _lock.ExitWriteLock();
        }
    }

    public string GetOrAdd(string key, Func<string> factory)
    {
        _lock.EnterUpgradeableReadLock();
        try
        {
            if (_values.TryGetValue(key, out string? existing))
            {
                return existing;
            }

            _lock.EnterWriteLock();
            try
            {
                return _values[key] = factory();
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }
        finally
        {
            _lock.ExitUpgradeableReadLock();
        }
    }

    public void Dispose() => _lock.Dispose();
}
```

## Common Follow-up Questions
- How does `ReaderWriterLockSlim` compare with `ConcurrentDictionary<TKey,TValue>`?
- Why is there only one upgradeable reader at a time?
- What happens if you hold a read lock and then try to enter a write lock directly?
- When would immutable snapshots outperform reader-writer locking?
- How does this compare with [lock-and-monitor.md](./lock-and-monitor.md)?

## Common Mistakes / Pitfalls
- Replacing every `lock` with `ReaderWriterLockSlim` without measuring whether read concurrency actually helps.
- Using upgradeable read mode everywhere, which serializes callers unnecessarily.
- Forgetting to release the lock in `finally`, causing deadlocks under failure.
- Holding the lock across slow operations or any `await` point.
- Ignoring simpler alternatives such as immutable data or concurrent collections.

## References
- [ReaderWriterLockSlim Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.readerwriterlockslim)
- [Overview of synchronization primitives — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/overview-of-synchronization-primitives)
- [Managed threading best practices — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices)
- [See: lock-and-monitor.md](./lock-and-monitor.md)
- [See: concurrent-collections.md](./concurrent-collections.md)
- [See: thread-safety-of-collections.md](./thread-safety-of-collections.md)
