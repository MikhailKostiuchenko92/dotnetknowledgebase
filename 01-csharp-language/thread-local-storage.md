# Thread-Local Storage

**Category:** C# / Threading & Concurrency
**Difficulty:** Senior
**Tags:** `ThreadLocal<T>`, `AsyncLocal<T>`, `ExecutionContext`, `threading`, `async`

## Question

> What is thread-local storage in .NET, and how do `ThreadLocal<T>` and `AsyncLocal<T>` differ?

Also asked as:
- "When should I use `ThreadLocal<T>` instead of `AsyncLocal<T>`?"
- "Why does `AsyncLocal<T>` flow across `await`, while `ThreadLocal<T>` does not?"

## Short Answer

`ThreadLocal<T>` gives each physical thread its own independent value. `AsyncLocal<T>` stores data in the ambient `ExecutionContext`, so the value flows with logical async execution across `await` boundaries even when the continuation resumes on a different thread. Use `ThreadLocal<T>` for true per-thread state; use `AsyncLocal<T>` for per-request, correlation, or ambient context that must follow asynchronous work.

## Detailed Explanation

### What Thread-Local Storage Actually Means

Thread-local storage (TLS) is a mechanism that gives each thread its own copy of a value. That means thread A and thread B can both access the same variable-like abstraction, but each sees a different value.

In .NET, the main modern APIs are:
- `ThreadLocal<T>` for **per-thread** data.
- `AsyncLocal<T>` for **per-logical-call-context** data.

Those look similar, but they solve different problems. The confusion usually starts when asynchronous code enters the picture, because `async` methods do not promise thread affinity. After an `await`, execution may continue on another thread pool thread.

### `ThreadLocal<T>` — Bound to the Physical Thread

`ThreadLocal<T>` stores one value per actual thread. If a thread pool work item runs on thread 12, it sees the thread-12 copy. If the next work item runs on thread 19, it sees the thread-19 copy.

That makes `ThreadLocal<T>` appropriate for:
- Thread-confined caches.
- Per-thread random number generators.
- Expensive objects reused only within the same dedicated thread.
- Algorithms using raw threads or `Parallel` APIs where work stays thread-oriented.

It is **not** a good fit for request context in ASP.NET Core or for ambient values that must survive `await`.

> **Warning:** With thread pool threads, thread-local state can outlive a single request or operation because the pool reuses threads. If you forget cleanup, the next unrelated work item may inherit stale per-thread data.

### `AsyncLocal<T>` — Bound to Logical Async Flow

`AsyncLocal<T>` participates in `ExecutionContext`. When the runtime captures and restores execution context across async continuations, the `AsyncLocal<T>` value flows too.

That makes it useful for:
- Correlation IDs.
- Current tenant/user/request context.
- Distributed tracing and logging scopes.
- Libraries that need ambient state without passing extra parameters everywhere.

The key idea is that the value follows the **logical operation**, not the current thread. If an `await` resumes on another thread, the `AsyncLocal<T>` value still comes with it.

### Comparison Table

| Aspect | `ThreadLocal<T>` | `AsyncLocal<T>` |
|---|---|---|
| Scope | Physical thread | Logical async flow (`ExecutionContext`) |
| Survives `await` | No | Yes |
| Good for ASP.NET request context | No | Yes |
| Good for per-thread cache | Yes | Usually no |
| Works with raw dedicated threads | Yes | Only if execution context flows |
| Main risk | Leaking stale state across reused pool threads | Hidden ambient coupling and context-flow overhead |

### Why `AsyncLocal<T>` Flows

The runtime captures `ExecutionContext` when scheduling async continuations and restores it before executing them. `AsyncLocal<T>` values are part of that context. This is separate from `SynchronizationContext`.

That means:
- `SynchronizationContext` decides **where** a continuation runs.
- `ExecutionContext` carries ambient data like `AsyncLocal<T>`, culture, and security context.

In ASP.NET Core there is generally no custom `SynchronizationContext`, but `AsyncLocal<T>` still flows because `ExecutionContext` still exists.

### Important Trade-Offs and Pitfalls

`AsyncLocal<T>` is convenient, but it is easy to abuse. Heavy mutable objects in `AsyncLocal<T>` can make behavior hard to reason about and can increase allocation/copy costs as execution context changes. Prefer explicit parameters when the dependency should be obvious.

`ThreadLocal<T>` also needs disposal in some cases. It can hold values alive for every thread that touched it. If the values are expensive or reference unmanaged resources, call `Dispose()` when the `ThreadLocal<T>` is no longer needed.

### When to Choose Which

Choose `ThreadLocal<T>` when the problem is truly thread-based. Choose `AsyncLocal<T>` when the problem is operation-based and must cross `await`.

A useful rule is:
- If the state belongs to a **thread**, use `ThreadLocal<T>`.
- If the state belongs to a **request/operation**, use `AsyncLocal<T>`.
- If the state is required input, prefer passing it explicitly rather than using either ambient mechanism.

See also [task-vs-thread.md](./task-vs-thread.md), [async-await-fundamentals.md](./async-await-fundamentals.md), and [synchronization-context.md](./synchronization-context.md).

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

ThreadLocal<int> perThreadCounter = new(() => 0);
AsyncLocal<string?> correlationId = new();

correlationId.Value = "request-123";

await Task.WhenAll(
    Task.Run(async () =>
    {
        perThreadCounter.Value++; // Value belongs to this physical thread.
        Console.WriteLine($"Task A start: thread-local={perThreadCounter.Value}, async-local={correlationId.Value}");

        correlationId.Value = "request-123/A"; // Flows with this logical async flow.
        await Task.Delay(20);

        Console.WriteLine($"Task A resume: thread-local={perThreadCounter.Value}, async-local={correlationId.Value}");
    }),
    Task.Run(async () =>
    {
        perThreadCounter.Value++;
        Console.WriteLine($"Task B start: thread-local={perThreadCounter.Value}, async-local={correlationId.Value}");

        correlationId.Value = "request-123/B";
        await Task.Delay(20);

        Console.WriteLine($"Task B resume: thread-local={perThreadCounter.Value}, async-local={correlationId.Value}");
    }));

var dedicatedThread = new Thread(() =>
{
    perThreadCounter.Value = 42; // Dedicated thread gets its own slot.
    Console.WriteLine($"Dedicated thread: thread-local={perThreadCounter.Value}, async-local={correlationId.Value}");
});

dedicatedThread.Start();
dedicatedThread.Join();

perThreadCounter.Dispose(); // Release per-thread values when done.
```

## Common Follow-up Questions

- How does `ExecutionContext` differ from `SynchronizationContext` in async code?
- Why can `AsyncLocal<T>` contribute to hidden coupling in large applications?
- When would `ThreadStatic` be preferable or inferior to `ThreadLocal<T>`?
- What happens to `AsyncLocal<T>` when you suppress execution-context flow with `ExecutionContext.SuppressFlow()`?
- Why is `ThreadLocal<T>` dangerous with thread pool reuse in server applications?

## Common Mistakes / Pitfalls

- Using `ThreadLocal<T>` to store request-specific data in ASP.NET Core and assuming it will survive `await`.
- Putting large mutable objects into `AsyncLocal<T>` and creating ambient global state that is hard to test.
- Forgetting to dispose `ThreadLocal<T>` when it holds expensive per-thread values.
- Assuming `AsyncLocal<T>` is free; execution-context flow has real overhead in hot paths.
- Treating `AsyncLocal<T>` as a replacement for proper method parameters when explicit dependencies are clearer.

## References

- [ThreadLocal<T> Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.threadlocal-1)
- [AsyncLocal<T> Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.asynclocal-1)
- [ExecutionContext Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.executioncontext)
- [See: task-vs-thread.md](./task-vs-thread.md)
- [See: synchronization-context.md](./synchronization-context.md)
