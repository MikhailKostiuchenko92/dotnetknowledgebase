# ArrayPool<T> and MemoryPool<T>

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `ArrayPool<T>`, `MemoryPool<T>`, `IMemoryOwner<T>`, `LOH`, `buffer pooling`, `System.Buffers`

## Question

> What are `ArrayPool<T>` and `MemoryPool<T>`, and when should you use them?

Also asked as:
> Why can a rented pooled buffer be larger than the requested length?
> How do pooling APIs help avoid large-object-heap allocations in high-throughput I/O code?

## Short Answer

`ArrayPool<T>` and `MemoryPool<T>` let you rent reusable buffers instead of allocating new arrays for every operation. `ArrayPool<T>.Shared.Rent(minLength)` may return a larger array because pools manage buckets of standard sizes, not exact lengths. Pooling can reduce GC pressure and help avoid repeated LOH allocations, but it requires strict lifetime discipline: once a buffer is returned, it must be treated as unusable.

## Detailed Explanation

### Why Buffer Pooling Exists

High-throughput applications often allocate many temporary buffers for I/O, parsing, compression, and serialization. If every request allocates fresh `byte[]` instances, the application creates constant garbage and may push large buffers onto the Large Object Heap (LOH), which is expensive to collect and can fragment memory.

Pooling replaces “allocate and discard” with “rent, use, return.” Instead of paying the full allocation cost every time, you reuse existing buffers.

| API | What you get | Lifetime model |
|---|---|---|
| `ArrayPool<T>` | `T[]` | Manual `Return` |
| `MemoryPool<T>` | `IMemoryOwner<T>` exposing `Memory<T>` | Dispose returns ownership |
| `new T[n]` | Fresh array | GC eventually reclaims |

### `ArrayPool<T>` Basics

The shared pool is easy to use:

- `Rent(minLength)` gives you an array with **at least** that size
- `Return(buffer, clearArray)` gives it back to the pool

The array may be larger than requested because the pool organizes buffers in size buckets, typically powers of two or similar ranges. Returning a slightly larger reusable array is usually cheaper than allocating an exact-sized one every time.

> **Warning:** Never assume `buffer.Length == requestedLength`. Use the requested logical length separately, especially when writing to streams or sockets.

### `MemoryPool<T>` and Ownership

`MemoryPool<T>` is useful when you want explicit ownership semantics rather than a raw array. `Rent` returns an `IMemoryOwner<T>`, which exposes a `Memory<T>` and returns the buffer to the pool when disposed.

This makes it easier to pass buffers between components because ownership is represented explicitly. It is especially useful in pipelines and advanced buffering scenarios.

### LOH Avoidance in I/O Loops

A `byte[]` larger than roughly 85,000 bytes goes to the LOH. If your networking loop repeatedly allocates such arrays, you can create expensive memory churn. Renting from a pool lets the application reuse those large buffers instead of constantly creating new LOH objects. See [large-object-heap.md](./large-object-heap.md).

### Common Correctness Hazards

Pooling is powerful, but it is easy to misuse:

- using a buffer after returning it
- assuming contents are zeroed
- leaking sensitive data by not clearing when necessary
- returning the same buffer twice

These are logic bugs, not compiler errors, which is why buffer pooling needs disciplined code review.

### Interview Takeaway

A strong answer emphasizes both performance and safety. Pooling reduces allocations and GC pressure, especially for large or frequent buffers, but the trade-off is manual lifetime management. `MemoryPool<T>` adds a safer ownership model on top of the same idea.

Another good interview nuance is that pooling is most valuable on hot paths with repeated buffer churn. For one-off or tiny allocations, plain arrays are often simpler and perfectly acceptable.

## Code Example

```csharp
using System.Buffers;
using System.Text;

namespace RuntimeSamples;

public static class PoolingDemo
{
    public static void Main()
    {
        byte[] buffer = ArrayPool<byte>.Shared.Rent(100_000); // May be larger than requested
        try
        {
            int written = Encoding.UTF8.GetBytes("Hello from a pooled buffer".AsSpan(), buffer);
            Console.WriteLine($"Logical length: {written}, actual buffer length: {buffer.Length}");
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer, clearArray: true); // Clear if sensitive data may remain
        }

        using IMemoryOwner<byte> owner = MemoryPool<byte>.Shared.Rent(4096);
        Memory<byte> memory = owner.Memory[..128]; // Use only the logical slice you need
        int count = Encoding.ASCII.GetBytes("PING".AsSpan(), memory.Span);
        Console.WriteLine(Encoding.ASCII.GetString(memory.Span[..count]));

        // Do not use `buffer` or `owner.Memory` after the buffer is returned/disposed.
    }
}
```

## Common Follow-up Questions

- Why might `Rent(1000)` return an array much larger than 1000 elements?
- When should you use `MemoryPool<T>` instead of `ArrayPool<T>`?
- How does pooling help with LOH allocations?
- Should you always pass `clearArray: true` when returning a buffer?
- What bug happens if code keeps a reference after returning a rented buffer?

## Common Mistakes / Pitfalls

- Reading or writing a rented buffer after it has been returned to the pool.
- Assuming pooled arrays are zero-initialized or contain only your current operation’s data.
- Forgetting that the returned array can be larger than the requested minimum length.
- Overusing pooling for tiny, infrequent allocations where complexity outweighs benefit.
- Returning the same buffer twice or returning a buffer to the wrong pool.

## References

- [ArrayPool<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [MemoryPool<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.memorypool-1)
- [IMemoryOwner<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.imemoryowner-1)
- [Large object heap on Windows systems](https://learn.microsoft.com/dotnet/standard/garbage-collection/large-object-heap)
