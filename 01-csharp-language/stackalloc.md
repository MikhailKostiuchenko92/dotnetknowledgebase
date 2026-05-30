# stackalloc

**Category:** C# / Memory & Performance
**Difficulty:** Senior
**Tags:** `stackalloc`, `span`, `performance`, `stack-memory`, `hot-paths`

## Question
> What does `stackalloc` do in C#, and when should you use it in modern .NET?
>
> How does `stackalloc` interact with `Span<T>`, and what are the size and safety trade-offs?
>
> When is `stackalloc` better than heap allocation or pooling in hot-path code?

## Short Answer
`stackalloc` allocates a block of memory on the current stack frame instead of the managed heap. In modern C#, it is most often used together with `Span<T>` or `ReadOnlySpan<T>` so you get fast temporary buffers without unsafe pointer code. It is excellent for small, short-lived buffers in hot paths, but it must be used carefully because large allocations can overflow the stack and the memory does not survive the current method scope.

## Detailed Explanation
### What `stackalloc` gives you
A `stackalloc` buffer is temporary memory tied to the current stack frame. There is no GC allocation, so there is no GC collection cost for that buffer. In C# today, the most ergonomic form is:

```csharp
Span<byte> buffer = stackalloc byte[64];
```

That gives you a stack-backed span with ordinary bounds checking and no unsafe arithmetic required.

| Technique | Allocation location | GC pressure | Lifetime |
| --- | --- | --- | --- |
| `new byte[64]` | Managed heap | Yes | Until collected |
| `stackalloc byte[64]` | Stack | No | Current method scope |
| `ArrayPool<byte>.Shared.Rent(64)` | Reused heap array | Reduced | Until returned |

### When it is a good fit
`stackalloc` shines for small buffers used immediately in parsing, formatting, encoding, and protocol handling. For example, converting a small value to text, normalizing input, or assembling a small packet header is a good candidate.

In .NET 8/9, it is common to combine `stackalloc` with spans and then fall back to heap allocation for larger inputs.

| Scenario | Good choice? | Why |
| --- | --- | --- |
| Small fixed-size scratch buffer | Yes | Fast and allocation-free |
| Buffer size depends on user input and may be large | Usually no | Stack overflow risk |
| Buffer must survive async work | No | Lifetime too short |
| Reusable medium/large buffers | Prefer pooling | Better control |

> Tip: if the required size can grow unpredictably, use a threshold pattern: `stackalloc` for small inputs and heap or pool for larger ones.

### Safety rules that matter in interviews
A `stackalloc` buffer is not automatically zeroed and it becomes invalid when the method returns. The biggest production mistake is overusing it for large buffers or in rarely tested code paths with larger-than-expected inputs.

It also pairs naturally with [span-of-t.md](./span-of-t.md), because spans preserve safety rules. If you need a heap-friendly buffer that can cross async boundaries, move to [memory-of-t.md](./memory-of-t.md). For larger reusable buffers, see [arraypool-and-memorypool.md](./arraypool-and-memorypool.md).

> Warning: do not use `stackalloc` with unbounded sizes derived from external input. A large enough request can terminate the process with `StackOverflowException`.

## Code Example
```csharp
using System;

Console.WriteLine(NormalizeToken("  dotnet  "));
Console.WriteLine(NormalizeToken("performance"));

static string NormalizeToken(ReadOnlySpan<char> input)
{
    input = input.Trim();
    const int StackThreshold = 64;

    // Small inputs stay on the stack; larger ones move to the heap.
    Span<char> buffer = input.Length <= StackThreshold
        ? stackalloc char[input.Length]
        : new char[input.Length];

    for (int i = 0; i < input.Length; i++)
    {
        buffer[i] = char.ToUpperInvariant(input[i]); // In-place transform.
    }

    return new string(buffer);
}
```

## Common Follow-up Questions
- Why is `stackalloc` usually paired with `Span<T>` in modern C#?
- Why is `stackalloc` dangerous for unbounded input sizes?
- When should you switch from `stackalloc` to `ArrayPool<T>`?
- Does `stackalloc` eliminate all costs, or only GC allocation cost?
- Why can a stack-allocated buffer not cross an async boundary?

## Common Mistakes / Pitfalls
- Allocating large or user-controlled buffers on the stack.
- Assuming stack memory is automatically zero-initialized.
- Returning or storing references to stack-allocated data beyond the current scope.
- Using `stackalloc` for buffers that would be clearer as ordinary arrays in non-hot code.
- Forgetting to measure whether the optimization matters at all.

## References
- [Microsoft Docs: `stackalloc` expression](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc)
- [Microsoft Docs: Span<T>](https://learn.microsoft.com/dotnet/api/system.span-1)
- [Microsoft Docs: Memory<T> and Span<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [See: Span<T>](./span-of-t.md)
- [See: ArrayPool and MemoryPool](./arraypool-and-memorypool.md)
