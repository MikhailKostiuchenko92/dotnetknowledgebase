# ArrayPool and MemoryPool

**Category:** C# / Memory & Performance
**Difficulty:** Senior
**Tags:** `arraypool`, `memorypool`, `pooling`, `buffers`, `performance`

## Question
> What are `ArrayPool<T>` and `MemoryPool<T>`, and when should you use them?
>
> How do rent/return semantics work, and why might the rented buffer be larger than the requested size?
>
> What are the ownership and safety rules for pooled buffers in modern .NET?

## Short Answer
`ArrayPool<T>` and `MemoryPool<T>` reduce allocation pressure by reusing buffers instead of creating new ones each time. `ArrayPool<T>` rents raw arrays that must be returned manually, while `MemoryPool<T>` typically exposes `IMemoryOwner<T>` so disposal returns the underlying memory to the pool. Pooling is powerful in high-throughput systems, but only when ownership is disciplined: rented buffers may be larger than requested, may contain old data, and must be returned exactly once.

## Detailed Explanation
### Why pooling exists
Frequent allocation of medium or large buffers can create GC pressure, especially on server workloads that parse network payloads, serialize messages, or process streams repeatedly. Pools amortize that cost by keeping reusable buffers alive.

| Pool | Returns | Common shape |
| --- | --- | --- |
| `ArrayPool<T>` | `T[]` | Low-level and fast |
| `MemoryPool<T>` | `IMemoryOwner<T>` | Better ownership model |

`ArrayPool<T>` is often used in lower-level code where performance matters and the ownership rules are clear. `MemoryPool<T>` fits better when APIs want to expose `Memory<T>` and make ownership explicit through disposal.

### Important rent/return rules
A key detail is that the pool is allowed to return a buffer larger than you asked for. You requested a minimum capacity, not an exact length. The caller is responsible for tracking how much of the buffer is actually used.

| Rule | Why it matters |
| --- | --- |
| Returned buffer may be larger than requested | Use slices or a separate `written` count |
| Contents may be dirty | Clear when handling secrets or when logic depends on zeroed memory |
| Always return/dispose | Otherwise the pool loses its benefit |
| Do not use after return/dispose | Another caller may reuse the same storage |

> Tip: the strongest interview phrasing is “pooling trades allocation cost for ownership complexity.”

### Choosing pool vs stack vs heap
Not every buffer should come from a pool. For tiny short-lived buffers, [stackalloc.md](./stackalloc.md) is often simpler. For straightforward code outside hot paths, an ordinary array may be clearer.

| Scenario | Better choice |
| --- | --- |
| Tiny temporary buffer in one method | `stackalloc` |
| Medium/large reusable buffers on hot paths | `ArrayPool<T>` |
| Async-friendly owner-based API | `MemoryPool<T>` |
| Simpler non-hot path code | `new T[]` |

Pooling also combines naturally with [memory-of-t.md](./memory-of-t.md) and [span-of-t.md](./span-of-t.md), because you typically work with slices over a rented buffer.

> Warning: pooled buffers are shared resources. Returning the same array twice or continuing to use it after return can create subtle data corruption bugs.

## Code Example
```csharp
using System;
using System.Buffers;
using System.Text;
using System.Threading.Tasks;

byte[] rented = ArrayPool<byte>.Shared.Rent(16);

try
{
    Console.WriteLine($"Requested 16 bytes, got {rented.Length} bytes.");

    int written = Encoding.UTF8.GetBytes("pooled", rented);
    Console.WriteLine(Encoding.UTF8.GetString(rented.AsSpan(0, written)));
}
finally
{
    // Clear if the content may be sensitive.
    ArrayPool<byte>.Shared.Return(rented, clearArray: true);
}

using IMemoryOwner<byte> owner = MemoryPool<byte>.Shared.Rent(32);
Memory<byte> memory = owner.Memory[..32];
await FillAsync(memory);
Console.WriteLine(memory.Span[0]);

static Task FillAsync(Memory<byte> destination)
{
    destination.Span.Clear();
    destination.Span[0] = 42;
    return Task.CompletedTask;
}
```

## Common Follow-up Questions
- Why can a pooled array be larger than the requested size?
- When should you choose `MemoryPool<T>` over `ArrayPool<T>`?
- Why is pooling often more valuable in server applications than in simple scripts?
- What bugs happen if code keeps using a buffer after returning it?
- When is `stackalloc` a better choice than pooling?

## Common Mistakes / Pitfalls
- Assuming `Rent(100)` returns an array whose `Length` is exactly 100.
- Forgetting to return or dispose pooled buffers.
- Reading old data because the rented buffer is not automatically cleared.
- Using a buffer after it has been returned to the pool.
- Introducing pooling in low-frequency code where complexity outweighs benefit.

## References
- [Microsoft Docs: ArrayPool<T>](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [Microsoft Docs: MemoryPool<T>](https://learn.microsoft.com/dotnet/api/system.buffers.memorypool-1)
- [Microsoft Docs: Memory<T> and Span<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [See: Memory<T>](./memory-of-t.md)
- [See: `stackalloc`](./stackalloc.md)
