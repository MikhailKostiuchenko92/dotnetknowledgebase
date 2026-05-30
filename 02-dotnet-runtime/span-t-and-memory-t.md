# Span<T> and Memory<T>

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `Span<T>`, `Memory<T>`, `ReadOnlySpan<T>`, `ReadOnlyMemory<T>`, `stackalloc`, `slicing`

## Question

> What is the difference between `Span<T>` and `Memory<T>` in .NET?

Also asked as:
> When should you use `Span<T>` versus `Memory<T>` or `ReadOnlySpan<T>`?
> How do slicing and `stackalloc` help you avoid allocations in hot paths?

## Short Answer

`Span<T>` is a stack-only view over contiguous memory that is ideal for synchronous, allocation-sensitive code, while `Memory<T>` is the heap-safe counterpart that can be stored, returned, and passed across async boundaries. `ReadOnlySpan<T>` and `ReadOnlyMemory<T>` represent immutable views. The main rule of thumb is: use `Span<T>` in synchronous hot paths, and use `Memory<T>` when the buffer needs to survive beyond the current stack frame or flow through async APIs.

## Detailed Explanation

### What These Types Represent

`Span<T>` and `Memory<T>` do **not** own memory. They are lightweight views over an existing contiguous region. That region might come from an array, pooled buffer, `stackalloc`, or unmanaged memory.

The important difference is lifetime safety:

| Type | Stack-only | Can be field/property | Can cross `await` | Mutable view |
|---|---|---|---|---|
| `Span<T>` | Yes | No | No | Yes |
| `ReadOnlySpan<T>` | Yes | No | No | No |
| `Memory<T>` | No | Yes | Yes | Yes |
| `ReadOnlyMemory<T>` | No | Yes | Yes | No |

`Span<T>` is fast because it is a `ref struct`, so the compiler keeps it on the stack and prevents invalid escapes. `Memory<T>` is designed for broader API usage where the value may need to live on the heap.

### Why Slicing Is Powerful

Before `Span<T>`, developers often created substrings or copied subarrays just to process a subset of data. With spans and memory, slicing is **O(1)**: the runtime creates a new view that points at the same underlying storage with a different start and length.

Examples:

- `arr.AsSpan(start, length)`
- `span[..10]`
- `memory.Slice(offset, count)`

That means you can parse, tokenize, and transform data without allocating new arrays for each step.

> **Warning:** Slicing avoids allocations, but the sliced view still depends on the original buffer being valid. If the underlying array is returned to an `ArrayPool<T>` too early, every slice becomes unsafe to use logically.

### `stackalloc` and Temporary Buffers

One of the biggest wins comes from pairing `Span<T>` with `stackalloc`. For small temporary buffers, you can allocate directly on the stack instead of the heap:

- zero GC pressure for the temporary buffer
- very fast allocation/deallocation semantics
- ideal for formatting, parsing, and encoding hot paths

This is why many BCL APIs expose span-based overloads for UTF-8 handling, formatting, and text processing.

### When to Use Each Type

A practical interview answer usually looks like this:

| Scenario | Preferred type |
|---|---|
| Tight synchronous parsing loop | `Span<T>` / `ReadOnlySpan<T>` |
| API storing buffer in a class field | `Memory<T>` / `ReadOnlyMemory<T>` |
| Async pipeline stage | `Memory<T>` |
| Read-only text parsing | `ReadOnlySpan<char>` |
| Temporary scratch buffer | `Span<T>` with `stackalloc` |

If you need to call `await`, store the buffer, or pass it to a long-lived object, choose `Memory<T>`. If the work is immediate and synchronous, `Span<T>` is usually better.

### Relationship to `ref struct` and Pooling

Because `Span<T>` is stack-only, it inherits all `ref struct` restrictions. See [ref-structs.md](./ref-structs.md). When the underlying storage comes from a pool, spans and memory let you process that buffer without extra copies; `ArrayPool<T>` and `MemoryPool<T>` are common partners. See [arraypool-and-memorypool.md](./arraypool-and-memorypool.md).

### Interview Takeaway

The key message is that these APIs help you write allocation-aware code without dropping into unsafe pointer logic. The distinction is mostly about **lifetime** and **where the view is allowed to live**.

## Code Example

```csharp
namespace RuntimeSamples;

public static class SpanAndMemoryDemo
{
    public static async Task Main()
    {
        int[] values = [10, 20, 30, 40, 50];

        Span<int> middle = values.AsSpan(1, 3); // O(1) slice, no new array
        middle[0] = 99;
        Console.WriteLine(string.Join(", ", values)); // 10, 99, 30, 40, 50

        Span<byte> scratch = stackalloc byte[16]; // Stack-only temporary buffer
        scratch.Fill((byte)'A');
        Console.WriteLine(scratch.Length);

        Memory<int> memory = values.AsMemory(2, 2); // Heap-safe view
        await ProcessAsync(memory); // Safe across await
    }

    private static async Task ProcessAsync(Memory<int> memory)
    {
        await Task.Delay(10);

        Span<int> span = memory.Span; // Convert back to Span<T> for immediate sync work
        span[0] *= 2;
        Console.WriteLine($"Processed value: {span[0]}");
    }
}
```

## Common Follow-up Questions

- Why can `Memory<T>` cross an `await` boundary but `Span<T>` cannot?
- Does slicing a span or memory allocate a new buffer?
- When should you prefer `ReadOnlySpan<T>` over `Span<T>`?
- How do `ArrayPool<T>` and `MemoryPool<T>` pair with these APIs?
- Why is `Span<T>` implemented as a `ref struct`?

## Common Mistakes / Pitfalls

- Returning or storing a `Span<T>` beyond the current synchronous scope.
- Using `Memory<T>` everywhere even in tight synchronous loops where `Span<T>` is simpler and faster.
- Assuming a slice is independent from the original buffer; it is just another view.
- Holding on to `Memory<T>` or `Span<T>` after the pooled buffer behind it has been returned.
- Using very large `stackalloc` buffers and risking stack overflow.

## References

- [System.Span<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.span-1)
- [System.Memory<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.memory-1)
- [Memory<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [System.ReadOnlySpan<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.readonlyspan-1)
