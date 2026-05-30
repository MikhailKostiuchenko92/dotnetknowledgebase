# When Should You Use ReaderWriterLockSlim?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Middle  
**Tags:** `readerwriterlockslim`, `locks`, `caching`, `shared-state`, `threading`

## Question
> What is `ReaderWriterLockSlim`, and when is it better than a normal `lock`?
>
> How do `EnterReadLock`, `EnterWriteLock`, and `EnterUpgradeableReadLock` differ?
>
> Why is `ReaderWriterLockSlim` preferred over the legacy `ReaderWriterLock`?

## Short Answer
`ReaderWriterLockSlim` allows many concurrent readers or one exclusive writer, so it can outperform a normal `lock` when shared state is read frequently and written rarely. It exposes separate modes for read, write, and upgradeable-read access, with only one upgradeable reader allowed at a time so it can safely promote to a writer. In modern .NET you should choose `ReaderWriterLockSlim`, not the older `ReaderWriterLock`, because the Slim version is faster, simpler, and less error-prone.

## Detailed Explanation
### Why a reader-writer lock exists
A regular `lock` is exclusive: even if ten threads only want to read immutable-looking shared state, they still serialize. That is wasteful for read-heavy structures such as configuration snapshots, routing metadata, or caches where writes are infrequent.

`ReaderWriterLockSlim` addresses that by allowing multiple readers to enter simultaneously while still guaranteeing exclusive access for writers.

### The three lock modes
The API exposes three main entry points:

| Mode | Method | Purpose |
| --- | --- | --- |
| Read | `EnterReadLock()` | Many readers may hold it concurrently |
| Write | `EnterWriteLock()` | Exactly one writer, no readers allowed |
| Upgradeable read | `EnterUpgradeableReadLock()` | Read first, then optionally promote to write |

The upgradeable read lock is the subtle one. Only one thread may hold it at a time. That restriction prevents a deadlock pattern where multiple readers all decide they now need to upgrade to a write lock and wait on each other forever.

A common pattern is “check under read access, and only if an update is needed, take the write lock.” Upgradeable read is built for that.

### When it helps and when it does not
`ReaderWriterLockSlim` helps when all of these are true:

- The protected resource is read much more often than written.
- Read sections are not trivial one-instruction operations.
- Contention is high enough that allowing parallel readers matters.

If writes are frequent, or the critical section is extremely short, a normal `lock` can be simpler and just as fast or faster. Reader-writer locks have bookkeeping overhead and are not a universal improvement.

> `ReaderWriterLockSlim` is a synchronous primitive. Do not hold it across `await`, and do not use it as if it were async-compatible.

### Starvation, convoying, and recursion
A classic risk with reader-heavy workloads is that writers get delayed by a stream of incoming readers. `ReaderWriterLockSlim` tries to balance this better than the legacy implementation, but you should still design critical sections to be short and avoid unnecessary nested access.

Use `LockRecursionPolicy.NoRecursion` unless you have a compelling, well-tested reason to allow recursion. Recursive locking makes reasoning harder and can worsen contention or hide design problems.

### Legacy `ReaderWriterLock` vs `ReaderWriterLockSlim`
The older `ReaderWriterLock` is mostly a historical interview topic now. It is heavier, more complex, and more prone to poor performance and upgrade-related confusion. `ReaderWriterLockSlim` was introduced specifically to improve those issues.

### Typical use case: read-mostly shared state
A cache or configuration dictionary is the classic example. Many threads read current values. Very occasionally, one thread refreshes the data. That is where `ReaderWriterLockSlim` earns its complexity.

For a broader comparison with other primitives, see [Synchronization Primitives Overview](./synchronization-primitives-overview.md).

## Code Example
```csharp
namespace RuntimeSamples.ReaderWriterLockDemo;

internal static class Program
{
    private static readonly ReaderWriterLockSlim Lock = new(LockRecursionPolicy.NoRecursion);
    private static readonly Dictionary<string, string> Config = new()
    {
        ["region"] = "eu-west-1"
    };

    public static void Main()
    {
        Console.WriteLine(GetValue("region"));
        EnsureValue("feature-x", "enabled");
        Console.WriteLine(GetValue("feature-x"));
    }

    private static string GetValue(string key)
    {
        Lock.EnterReadLock();
        try
        {
            return Config[key]; // Many readers can do this concurrently.
        }
        finally
        {
            Lock.ExitReadLock();
        }
    }

    private static void EnsureValue(string key, string value)
    {
        Lock.EnterUpgradeableReadLock(); // Only one thread may hold this mode at once.
        try
        {
            if (Config.ContainsKey(key))
            {
                return;
            }

            Lock.EnterWriteLock();
            try
            {
                Config[key] = value; // Exclusive mutation.
            }
            finally
            {
                Lock.ExitWriteLock();
            }
        }
        finally
        {
            Lock.ExitUpgradeableReadLock();
        }
    }
}
```

## Common Follow-up Questions
- Why is only one upgradeable reader allowed at a time?
- When is a normal `lock` still the better choice?
- Can `ReaderWriterLockSlim` be used safely across `await`?
- What kind of workload tends to starve writers?
- Why is recursion usually disabled with `LockRecursionPolicy.NoRecursion`?

## Common Mistakes / Pitfalls
- Using `ReaderWriterLockSlim` for write-heavy code where it adds overhead without benefit.
- Holding the lock across I/O or long-running work, increasing contention.
- Forgetting to exit the exact lock mode that was entered.
- Using recursive locking to paper over poor design.
- Treating the legacy `ReaderWriterLock` as an acceptable modern default.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.readerwriterlockslim
- https://learn.microsoft.com/dotnet/api/system.threading.readerwriterlock
- https://learn.microsoft.com/dotnet/standard/threading/overview-of-synchronization-primitives
- https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices
