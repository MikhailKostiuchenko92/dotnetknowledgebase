# Span<T>

**Category:** C# / Memory & Performance
**Difficulty:** Senior
**Tags:** `span`, `readonlyspan`, `ref-struct`, `slicing`, `parsing`

## Question
> What is `Span<T>` in C#, and why is it a `ref struct`?
>
> How do `Span<T>` and `ReadOnlySpan<T>` enable slicing and zero-copy parsing over contiguous memory?
>
> What restrictions come with `Span<T>` in .NET 8/9, especially around async methods and heap storage?

## Short Answer
`Span<T>` is a lightweight stack-only view over contiguous memory such as arrays, stackalloc buffers, strings, or unmanaged memory. It lets you slice, parse, and transform data without copying, which is why it is central to high-performance .NET APIs. The trade-off is lifetime safety: because it is a `ref struct`, `Span<T>` cannot be boxed, stored in ordinary heap objects, or used across `await` and `yield` boundaries.

## Detailed Explanation
### What `Span<T>` represents
`Span<T>` is not an owning collection. It is a view: conceptually a reference to the first element plus a length. That design lets one API work over many contiguous buffers without allocating new arrays or substrings.

| Source | Can become `Span<T>`? | Notes |
| --- | --- | --- |
| `T[]` | Yes | Most common source |
| `stackalloc` buffer | Yes | Very fast, stack-only |
| unmanaged memory | Yes | Advanced scenarios |
| `string` | As `ReadOnlySpan<char>` | Strings are immutable |

This is why `Span<T>` is so useful for parsing, encoding, formatting, and protocol handling.

### Why it is a `ref struct`
A `Span<T>` may point to stack memory. If it could escape to the heap, the referenced memory could disappear while the span still exists. C# prevents that by making `Span<T>` a `ref struct`.

| Operation | `Span<T>` |
| --- | --- |
| Stored in a class field | No |
| Boxed to `object` | No |
| Used across `await` | No |
| Sliced without copying | Yes |
| Mutates underlying memory | Yes |

See [ref-struct-and-ref-fields.md](./ref-struct-and-ref-fields.md) for the deeper lifetime rules.

> Tip: `Span<T>` is best understood as a safe, bounds-checked replacement for “pointer + length” inside ordinary managed code.

### `ReadOnlySpan<T>`, strings, and parsing
`ReadOnlySpan<T>` is the read-only sibling. It is heavily used with strings because you can slice a `string` as `ReadOnlySpan<char>` without allocating substrings. That is a major win in parsers and hot-path text processing.

| Type | Writable | Heap-storable |
| --- | --- | --- |
| `Span<T>` | Yes | No |
| `ReadOnlySpan<T>` | No | No |
| `Memory<T>` | Yes | Yes |
| `ReadOnlyMemory<T>` | No | Yes |

If you need to keep the buffer on an object or pass it through an async boundary, move up to [memory-of-t.md](./memory-of-t.md). For stack-based buffers, pair spans with [stackalloc.md](./stackalloc.md).

> Warning: the `.Span` property on `Memory<T>` or `ReadOnlyMemory<T>` gives you a span for a synchronous region only. Do not keep that span alive across `await`.

## Code Example
```csharp
using System;

ReadOnlySpan<char> input = "10,20,30,40".AsSpan();
Console.WriteLine(SumCsv(input));

Span<char> greeting = stackalloc char[5]; // Stack buffer, no heap array.
"hello".AsSpan().CopyTo(greeting);
greeting[0] = 'H';                        // Mutates the same buffer in place.
Console.WriteLine(greeting.ToString());

static int SumCsv(ReadOnlySpan<char> csv)
{
    int sum = 0;

    while (!csv.IsEmpty)
    {
        int commaIndex = csv.IndexOf(',');
        ReadOnlySpan<char> token = commaIndex >= 0 ? csv[..commaIndex] : csv;

        sum += int.Parse(token);          // Parses directly from the span.
        csv = commaIndex >= 0 ? csv[(commaIndex + 1)..] : ReadOnlySpan<char>.Empty;
    }

    return sum;
}
```

## Common Follow-up Questions
- Why is `Span<T>` a `ref struct` instead of a normal struct?
- When should you choose `ReadOnlySpan<T>` over `string` or `Substring`?
- Why can `Span<T>` not be stored in a field or used across `await`?
- When should `Memory<T>` be used instead of `Span<T>`?
- How does `stackalloc` make `Span<T>` even more useful in hot paths?

## Common Mistakes / Pitfalls
- Thinking `Span<T>` owns memory rather than viewing someone else's buffer.
- Returning a span that points to invalid or short-lived memory.
- Trying to keep a span in a class field or closure.
- Using `Span<T>` across `await` instead of switching to `Memory<T>`.
- Forgetting that slices still reference the original buffer, so mutations affect the source.

## References
- [Microsoft Docs: Span<T>](https://learn.microsoft.com/dotnet/api/system.span-1)
- [Microsoft Docs: Memory<T> and Span<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [Microsoft Docs: `stackalloc` expression](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc)
- [See: `ref struct` and `ref` Fields](./ref-struct-and-ref-fields.md)
- [See: Memory<T>](./memory-of-t.md)
