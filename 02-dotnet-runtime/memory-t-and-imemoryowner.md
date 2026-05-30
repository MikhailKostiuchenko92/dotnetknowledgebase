# Memory<T> and IMemoryOwner<T>

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `Memory<T>`, `IMemoryOwner<T>`, `MemoryPool<T>`, `pipelines`, `async`, `buffer ownership`

## Question

> What is `IMemoryOwner<T>`, and how does it relate to `Memory<T>` in .NET?

Also asked as:
> How do you safely pass buffers across async boundaries?
> Why does `MemoryPool<T>.Shared.Rent()` return `IMemoryOwner<T>` instead of just `Memory<T>`?

## Short Answer

`Memory<T>` is a heap-safe view over contiguous memory, while `IMemoryOwner<T>` represents the component that owns that memory and is responsible for returning or releasing it when finished. `MemoryPool<T>.Shared.Rent()` returns an `IMemoryOwner<T>` so lifetime is explicit: consumers can use the `Memory<T>`, but disposal signals that the owner is done and the buffer can be reused. This ownership model is especially important in asynchronous and pipeline-based code where `Span<T>` cannot safely cross method suspension points.

## Detailed Explanation

### View vs Ownership

A common mistake is to think `Memory<T>` owns data. It does not. It is just a view, similar to a safe, heap-capable cousin of `Span<T>`. The actual storage may come from an array, a pooled buffer, or some custom memory manager.

`IMemoryOwner<T>` solves the missing piece: **who is responsible for the buffer’s lifetime?** It wraps the storage and exposes a `Memory<T>` property, while `Dispose()` releases that ownership.

| Type | Purpose | Can cross `await` | Owns memory |
|---|---|---|---|
| `Span<T>` | Fast sync view | No | No |
| `Memory<T>` | Heap-safe async-friendly view | Yes | No |
| `IMemoryOwner<T>` | Ownership + disposal | Yes | Yes |

### Why `MemoryPool<T>` Uses `IMemoryOwner<T>`

If `MemoryPool<T>` returned only `Memory<T>`, there would be no clear signal for when the underlying buffer should be returned to the pool. `IMemoryOwner<T>` makes that explicit. The caller rents a buffer, passes around the `Memory<T>` view as needed, and disposes the owner when the buffer is no longer in use.

This design reduces accidental lifetime bugs and works naturally with `using`.

> **Warning:** Disposing the owner invalidates the logical right to use the associated `Memory<T>`. Keeping a copy of `Memory<T>` after disposal is a correctness bug, even if the underlying bytes still appear readable for a while.

### Async Boundaries and Safe Buffer Flow

Because `Memory<T>` is not stack-only, it can safely be stored in fields, returned from methods, and passed into async operations. This makes it the correct abstraction for asynchronous pipelines, socket processing, and staged parsers.

A typical pattern is:

1. rent `IMemoryOwner<byte>` from `MemoryPool<byte>`
2. expose or pass `owner.Memory[..count]`
3. await async I/O that fills or consumes the buffer
4. dispose the owner when the pipeline stage is done

That is the core reason `Memory<T>` exists alongside `Span<T>` rather than replacing it.

### Relationship to `System.IO.Pipelines`

`System.IO.Pipelines` is built around explicit buffer ownership and efficient slicing. While the public API uses `ReadOnlySequence<T>` and other abstractions, the broader ecosystem frequently relies on pooled memory and ownership semantics that align with `IMemoryOwner<T>`. That makes the interface an important mental model for high-performance .NET I/O.

### Practical Design Advice

Use `Memory<T>` when:

- the buffer must survive beyond the current synchronous method
- you need to store it in an object
- you need to pass it across `await`

Use `IMemoryOwner<T>` when:

- you rented pooled memory
- multiple components need a clear ownership contract
- disposal should trigger buffer return/release

See [span-t-and-memory-t.md](./span-t-and-memory-t.md) and [arraypool-and-memorypool.md](./arraypool-and-memorypool.md).

### Interview Takeaway

The crisp answer is: `Memory<T>` is the buffer view; `IMemoryOwner<T>` is the lifetime contract. Together they let high-performance .NET code stay allocation-aware without losing safety across asynchronous boundaries.

## Code Example

```csharp
using System.Buffers;
using System.Text;

namespace RuntimeSamples;

public static class MemoryOwnerDemo
{
    public static async Task Main()
    {
        using IMemoryOwner<byte> owner = MemoryPool<byte>.Shared.Rent(1024);
        Memory<byte> buffer = owner.Memory[..32];

        int written = Encoding.UTF8.GetBytes("hello pipeline".AsSpan(), buffer.Span);
        await SendAsync(buffer[..written]); // Memory<T> is safe across await
    }

    private static async Task SendAsync(Memory<byte> payload)
    {
        await Task.Delay(10);
        Console.WriteLine(Encoding.UTF8.GetString(payload.Span));
    }
}
```

## Common Follow-up Questions

- Why is `Memory<T>` allowed across `await` while `Span<T>` is not?
- What bug occurs if you keep using `Memory<T>` after disposing its `IMemoryOwner<T>`?
- When should you choose `ArrayPool<T>` over `MemoryPool<T>`?
- How does ownership matter in pipeline or socket code?
- Does `Memory<T>` itself allocate or own the underlying array?

## Common Mistakes / Pitfalls

- Treating `Memory<T>` as the owner of the underlying storage.
- Disposing an `IMemoryOwner<T>` too early while another component still uses the buffer.
- Keeping `Memory<T>` slices alive after the owning buffer has been returned to the pool.
- Using `Span<T>` in APIs that need to survive asynchronous suspension.
- Forgetting to dispose owners in long-running services, causing pooled-buffer leaks.

## References

- [System.Memory<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.memory-1)
- [IMemoryOwner<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.imemoryowner-1)
- [MemoryPool<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.memorypool-1)
- [Memory<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
