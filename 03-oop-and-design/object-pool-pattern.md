# Object Pool Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟡 Middle
**Tags:** `object-pool`, `creational`, `performance`, `ArrayPool`, `MemoryPool`

## Question
> What is the Object Pool pattern in .NET, how do `ObjectPool<T>`, `ArrayPool<T>`, and `MemoryPool<T>` differ, and when does pooling actually improve performance?

## Short Answer
Object Pool reuses objects instead of allocating and collecting them repeatedly, which can help on hot paths where objects are expensive or very frequent. In .NET, `ObjectPool<T>` is for reusable object instances, `ArrayPool<T>` is for arrays, and `MemoryPool<T>` is for owned memory buffers. Pooling pays off only when allocation/reset cost and GC pressure are significant; for cheap objects it often adds complexity without real benefit.

## Detailed Explanation
### What the pattern is
Object Pool is a creational pattern that keeps a set of reusable objects ready for checkout and return. Instead of constructing a new instance every time, the application borrows one from the pool, uses it, resets it, and returns it.

In managed runtimes like .NET, this pattern should be used carefully. The garbage collector is already very good at handling short-lived small objects, so pooling is not automatically faster. The pattern becomes valuable only when repeated allocation creates measurable cost, especially for large buffers or expensive-to-initialize reusable state.

### The main .NET pooling options
.NET gives you several pooling APIs, each aimed at a slightly different problem.

| API | Best for | Important note |
| --- | --- | --- |
| `ObjectPool<T>` | Reusable reference objects with reset logic | Good for objects that are expensive to initialize. |
| `ArrayPool<T>` | Temporary arrays | Returned arrays may be larger than requested and may contain old data. |
| `MemoryPool<T>` | Rented memory with ownership semantics | Often used in pipelines and high-performance I/O. |

`ObjectPool<T>` from `Microsoft.Extensions.ObjectPool` lets you define how instances are created and reset. `ArrayPool<T>` is optimized for renting arrays without repeated large allocations. `MemoryPool<T>` wraps memory in an owner object so lifetime is explicit through `Dispose()`.

### How pooling works internally
A pool usually has a fast path that returns an already-available instance and a fallback path that allocates when the pool is empty. Returning an item does not always guarantee it will be stored forever; some pools cap retained items.

The real challenge is object hygiene. Pooled objects must be safe to reuse. That means clearing buffers, resetting counters, and removing references that could leak data or keep other objects alive.

> Warning: After returning an object or buffer to the pool, you must treat it as invalid. Using it again creates very subtle bugs because another caller may already be reusing it.

### When pooling pays off
Pooling makes sense when at least one of these is true:
- allocations are frequent on a hot path,
- objects are large enough to increase GC pressure,
- initialization is expensive,
- profiling shows pooling reduces latency or allocation rate.

A common good case is temporary byte arrays for serialization, compression, or network I/O. Another is reusable parsers or builders that allocate internal buffers repeatedly.

### Trade-offs and when not to use it
Pooling increases complexity. You now have a borrow/return protocol, reset logic, possible contention, and correctness risks. If an object is cheap and short-lived, the GC may outperform a custom pool because the runtime is optimized for that scenario.

Array pooling also has security and correctness implications. Rented arrays are not guaranteed to be zeroed, so code must clear sensitive data explicitly. And because pooled arrays can be larger than requested, callers should track the logical length separately.

Use pooling only after measuring. In interviews, a strong answer is: it is a performance tool, not a default design pattern.

## Code Example
```csharp
using System;
using System.Buffers;

namespace KnowledgeBase.OopDesign;

internal static class Program
{
    private static void Main()
    {
        // Rent a reusable buffer instead of allocating a new array each time.
        var pool = ArrayPool<byte>.Shared;
        byte[] buffer = pool.Rent(1024);

        try
        {
            var text = "Hello, pooled buffer!"u8;
            text.CopyTo(buffer); // Use only the requested logical length.

            Console.WriteLine($"Rented length: {buffer.Length}");
            Console.WriteLine($"Payload length: {text.Length}");
        }
        finally
        {
            // Clear data if it may contain sensitive information.
            Array.Clear(buffer, 0, buffer.Length);
            pool.Return(buffer);
        }
    }
}
```

## Common Follow-up Questions
- Why can pooling be slower than allocation for small cheap objects?
- What is the difference between `ArrayPool<T>` and `MemoryPool<T>`?
- How do you safely reset state before returning an object to `ObjectPool<T>`?
- Why are rented arrays not guaranteed to be zero-initialized?
- What metrics would you check before deciding to introduce pooling?

## Common Mistakes / Pitfalls
- Pooling tiny or cheap objects without profiling and adding complexity for no measurable gain.
- Using a pooled object or array after it has already been returned.
- Forgetting to clear sensitive data before returning buffers to the pool.
- Assuming `ArrayPool<T>.Rent()` returns an array of exactly the requested length.
- Returning objects to the pool without resetting state, causing data leaks across callers.

## References
- [Object reuse with ObjectPool in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/objectpool?view=aspnetcore-9.0)
- [ObjectPool<T> Class](https://learn.microsoft.com/dotnet/api/microsoft.extensions.objectpool.objectpool-1)
- [ArrayPool<T> Class](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [MemoryPool<T> Class](https://learn.microsoft.com/dotnet/api/system.buffers.memorypool-1)
