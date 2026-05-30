# How Does Thread-Local Storage Work in .NET?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Middle  
**Tags:** `threading`, `threadlocal`, `threadstatic`, `tls`, `thread-affinity`

## Question
> How do you store per-thread state in .NET, and when would you choose `ThreadLocal<T>` over `[ThreadStatic]`?
>
> What is thread-local storage, and what are the practical differences between `ThreadLocal<T>` and a `[ThreadStatic]` field?
>
> Why can thread-local state become dangerous with ThreadPool threads or thread-affine resources?

## Short Answer
Thread-local storage gives each thread its own independent copy of a value, so threads can avoid synchronizing around that state. In .NET, the two common mechanisms are `ThreadLocal<T>` and `[ThreadStatic]`: `ThreadLocal<T>` supports factory-based per-thread initialization and optional enumeration of per-thread values, while `[ThreadStatic]` turns a static field into one value per thread but does not run the field initializer for every thread. `ThreadLocal<T>` is usually safer and more expressive, but it must be disposed when many threads may come and go, or it can retain per-thread data longer than expected.

## Detailed Explanation
### Why thread-local storage exists
Sometimes sharing is the problem, not the solution. If each thread can keep its own buffer, random generator, parser state, or scratch object, you avoid contention entirely because no lock is needed. The runtime stores thread-local data separately for each thread, so reads and writes are isolated even though the code references one logical field or wrapper object.

This is especially useful when the state is inherently thread-bound: reusable buffers, culture-sensitive formatting caches, or native handles that must only be touched from one thread. It is much less useful for request-scoped or async-scoped data, because async work may resume on another thread. Thread-local state follows the physical thread, not the logical operation.

### `ThreadLocal<T>`
`ThreadLocal<T>` is an object wrapper around per-thread values. You access the current thread's value through `.Value`, and you can optionally provide a factory so every thread lazily creates its own value the first time it touches the instance. That makes initialization predictable and avoids the biggest `[ThreadStatic]` trap.

If you construct it with `trackAllValues: true`, the `Values` property lets you inspect all per-thread values currently associated with that `ThreadLocal<T>`. That can be useful for diagnostics or aggregation, but it also means the instance tracks references to those values, which is one reason cleanup matters.

> `ThreadLocal<T>` implements `IDisposable`. If you create many instances or use it across many short-lived threads, not disposing it can retain thread-associated data longer than necessary and effectively behave like a memory leak.

### `[ThreadStatic]`
`[ThreadStatic]` is lower-level. You apply it to a `static` field, and the CLR gives each thread a separate copy of that field. The major pitfall is initialization: a field initializer runs only for the declaring thread during type initialization. Other threads get the default value for the type, not the initializer value.

That means this is wrong for most reference types:

| Pattern | Result |
| --- | --- |
| `[ThreadStatic] private static StringBuilder _buffer = new();` | Only the first thread gets `new StringBuilder()` |
| `[ThreadStatic] private static StringBuilder? _buffer;` + lazy init in code | Correct |

So `[ThreadStatic]` is fine when you control lazy initialization manually and want the lowest ceremony, but it is easy to misuse in interviews and in production.

### `ThreadLocal<T>` vs `[ThreadStatic]`

| Aspect | `ThreadLocal<T>` | `[ThreadStatic]` |
| --- | --- | --- |
| Initialization | Factory per thread | Manual lazy init required |
| Scope | Instance wrapper around thread-specific values | Static field only |
| Enumerate all values | `Values` when tracking enabled | No built-in support |
| Disposal | Yes, should be disposed | No wrapper object to dispose |
| Typical risk | Forgetting disposal | Incorrect initialization assumptions |

`ThreadLocal<T>` is usually the better default when you want correctness and readability. `[ThreadStatic]` is appropriate when you need a static per-thread slot and fully understand the initialization model.

### Thread-affine resources and when TLS is the wrong abstraction
Some resources are thread-affine, meaning they must be created and used on a specific thread. Examples include OpenGL contexts, COM STA objects, and many UI objects. These are reasonable candidates for per-thread storage if you control thread ownership carefully.

But not everything that is “not thread-safe” should go into TLS. For example, EF Core `DbContext` is not thread-safe, but it is typically scoped to a unit of work or request, not to a physical thread. On ThreadPool threads, a request may hop threads, and ThreadPool threads are reused for unrelated work. That makes thread-local `DbContext` a poor design.

> Thread-local storage and `async` often conflict. If the data should follow a logical call flow rather than a specific OS thread, prefer an async-friendly mechanism such as `AsyncLocal<T>` instead of TLS.

For related ThreadPool behavior, see [ThreadPool Basics](./threadpool-basics.md).

## Code Example
```csharp
using System.Text;

namespace RuntimeSamples.ThreadLocalStorage;

internal static class Program
{
    [ThreadStatic]
    private static string? _threadStaticCorrelationId; // Each thread gets its own field.

    private static readonly ThreadLocal<StringBuilder> Buffers = new(
        valueFactory: () => new StringBuilder($"buffer-for-thread-{Environment.CurrentManagedThreadId}: "),
        trackAllValues: true);

    public static void Main()
    {
        Parallel.For(0, 4, i =>
        {
            // `[ThreadStatic]` does not run a field initializer for every thread.
            _threadStaticCorrelationId ??= $"corr-{Environment.CurrentManagedThreadId}";

            var buffer = Buffers.Value; // Lazily created once per thread.
            buffer.Append($"item {i}; ");

            Console.WriteLine(
                $"Thread {Environment.CurrentManagedThreadId}: " +
                $"ThreadStatic={_threadStaticCorrelationId}, Buffer='{buffer}'");
        });

        Console.WriteLine("\nTracked ThreadLocal values:");
        foreach (var value in Buffers.Values)
        {
            Console.WriteLine(value.ToString());
        }

        Buffers.Dispose(); // Important when many threads may be created over time.
    }
}
```

## Common Follow-up Questions
- What problem does `AsyncLocal<T>` solve that `ThreadLocal<T>` does not?
- Why does `[ThreadStatic]` often produce `null` on worker threads even when a field initializer exists?
- Is `ThreadLocal<T>.Value` initialized eagerly or lazily?
- Why can ThreadPool reuse make thread-local state surprising?
- When is it safe to enumerate `ThreadLocal<T>.Values`?

## Common Mistakes / Pitfalls
- Assuming a `[ThreadStatic]` field initializer runs for every thread.
- Storing request-scoped or async-flow data in thread-local storage.
- Forgetting to dispose long-lived `ThreadLocal<T>` instances that track many per-thread values.
- Treating non-thread-safe resources like `DbContext` as thread-affine when they are really scope-affine.
- Using `ThreadLocal<T>.Values` without enabling tracking or without understanding the memory cost.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.threadlocal-1
- https://learn.microsoft.com/dotnet/api/system.threadstaticattribute
- https://learn.microsoft.com/ef/core/dbcontext-configuration/
- https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices
