# `lock` and `Monitor`

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `lock`, `Monitor`, `thread-safety`, `reentrancy`, `synchronization`

## Question
> How does the `lock` statement work in C#, what does it compile to under the hood, and what objects should you lock on?

Also asked as:
- "What is the relationship between `lock` and `Monitor.Enter`/`Monitor.Exit`?"
- "Why is it a bad idea to `lock(this)` or lock on a string?"

## Short Answer
`lock` is C# syntax sugar over `Monitor.Enter` and `Monitor.Exit` wrapped in a `try/finally`, which guarantees the lock is released even if an exception occurs. It is reentrant, so the same thread can acquire the same lock multiple times. You should lock on a private dedicated reference object, not `this`, not `typeof(SomeType)`, and not strings, because external code could lock the same object and create accidental deadlocks or contention.

## Detailed Explanation

### What `lock` does
A `lock` ensures only one thread at a time enters a protected critical section for a given reference object. If another thread already owns that monitor, the current thread blocks until the monitor becomes available.

Conceptually, this:

```csharp
lock (_gate)
{
    UpdateSharedState();
}
```

becomes roughly this:

```csharp
bool lockTaken = false;
try
{
    Monitor.Enter(_gate, ref lockTaken);
    UpdateSharedState();
}
finally
{
    if (lockTaken)
    {
        Monitor.Exit(_gate);
    }
}
```

That `try/finally` is the important safety feature. Even if `UpdateSharedState` throws, the monitor is released.

### Reentrancy
`Monitor` is reentrant. If the same thread enters the same monitor again, it succeeds and increments an internal recursion count. The thread must then call `Exit` the same number of times before another thread can enter.

That is why this is legal:

```csharp
lock (_gate)
{
    CallAnotherMethodThatAlsoLocksGate();
}
```

Reentrancy is convenient, but it can also hide design problems. If lock ownership becomes too implicit, the code is harder to reason about.

| Behavior | `lock` / `Monitor` |
|---|---|
| Reentrant for same thread | Yes |
| Works with `await` inside the block | No |
| Requires reference type object | Yes |
| Automatically released on exception | Yes, via generated `finally` |

### What to lock on
The best practice is to lock on a private, readonly object that no outside code can access.

```csharp
private readonly object _gate = new();
```

That makes the lock boundary explicit and prevents accidental interference.

### What **not** to lock on
These are dangerous choices:

- `this` — external callers can also lock your instance.
- `typeof(MyType)` — any code in the AppDomain can lock that `Type` object.
- strings — string interning means apparently separate code paths can share the same string instance.
- public fields or properties — outside code can coordinate on them without your knowledge.

> **Warning:** a lock is not just about mutual exclusion; it is also part of your public synchronization contract. Locking on publicly reachable objects leaks that contract accidentally.

### When `Monitor` directly is useful
The `lock` statement covers the common case. Use `Monitor` directly when you need more control, such as timed attempts with `Monitor.TryEnter`.

That can be useful for diagnostics or avoiding indefinite waits, but it also makes code easier to get wrong because you must manage `lockTaken` correctly yourself.

### `lock` and async code
You cannot use `await` inside a `lock` block because the continuation may resume on a different thread while the monitor is still owned. For async coordination, use `SemaphoreSlim.WaitAsync` or a purpose-built async lock.

### Memory semantics and deadlock discipline
`Monitor.Enter` and `Monitor.Exit` are not just mutual exclusion operations; they also form synchronization boundaries. In practical terms, writes done by one thread before releasing the lock become visible to another thread that later acquires the same lock. That is one reason a lock often solves both race conditions and visibility issues at once.

The remaining danger is deadlock. If two threads acquire locks in inconsistent order, each can wait forever for the other. A simple engineering rule helps a lot: define a global lock acquisition order and keep nested locking rare.

### When a plain `lock` is the best answer
Developers sometimes jump to more advanced primitives too early. If you are protecting a small in-memory invariant such as "update two fields together" or "read-modify-write a short section," `lock` is often the clearest and most maintainable solution. It is easy to audit, it composes well with ordinary synchronous code, and the runtime implementation is highly optimized for uncontended paths.

### Contention and scope design
A lock is cheap when uncontended and expensive when many threads pile up behind it. That is why the real performance question is often not "should I use `lock`?" but "how much work am I doing while the lock is held?" Moving expensive computation outside the critical section usually helps more than changing primitives.

> **Tip:** keep lock scopes tiny. Protect the minimum shared state, and never do network I/O, file I/O, or long CPU work while holding a monitor.

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

var counter = new SafeCounter();

Task[] tasks = new Task[4];
for (int i = 0; i < tasks.Length; i++)
{
    tasks[i] = Task.Run(() =>
    {
        for (int j = 0; j < 10_000; j++)
        {
            counter.Increment();
        }
    });
}

await Task.WhenAll(tasks);
Console.WriteLine($"Final count: {counter.Value}");

sealed class SafeCounter
{
    private readonly object _gate = new(); // Private dedicated lock object.
    private int _value;

    public int Value
    {
        get
        {
            lock (_gate)
            {
                return _value;
            }
        }
    }

    public void Increment()
    {
        lock (_gate)
        {
            // Shared state update is protected by the monitor.
            _value++;
            LogWhileHoldingSameLock(); // Reentrant call is allowed.
        }
    }

    private void LogWhileHoldingSameLock()
    {
        lock (_gate)
        {
            // Same thread can acquire the same monitor again.
            if (_value % 10_000 == 0)
            {
                Console.WriteLine($"Reached {_value} on thread {Environment.CurrentManagedThreadId}");
            }
        }
    }
}
```

## Common Follow-up Questions
- How does `Monitor.TryEnter` differ from a normal `lock` block?
- Why is `lock` reentrant, and how can that affect design?
- What should you use instead of `lock` in async methods?
- What memory ordering guarantees do `Monitor.Enter` and `Monitor.Exit` provide?
- How does this compare with [reader-writer-lockslim.md](./reader-writer-lockslim.md)?

## Common Mistakes / Pitfalls
- Locking on `this`, `typeof(...)`, or a string, which exposes your synchronization object to external code.
- Holding a lock while doing slow work such as I/O, sleeping, or expensive computation.
- Assuming `lock` works with `await`; it does not.
- Forgetting that multiple locks acquired in inconsistent order can deadlock.
- Using too many tiny unrelated locks without a clear ownership model, which makes correctness hard to verify.

## References
- [The lock statement — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock)
- [Monitor Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.monitor)
- [Managed threading best practices — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices)
- [See: reader-writer-lockslim.md](./reader-writer-lockslim.md)
- [See: volatile-and-memory-barriers.md](./volatile-and-memory-barriers.md)
- [See: semaphoreslim-and-mutex.md](./semaphoreslim-and-mutex.md)
