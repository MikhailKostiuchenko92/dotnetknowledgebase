# ref struct

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `ref struct`, `Span<T>`, `stack-only`, `C# 13`, `async`, `managed pointers`

## Question

> What is a `ref struct`, and why does C# restrict where it can be used?

Also asked as:
> Why is `Span<T>` a `ref struct`?
> What are the main restrictions on stack-only types, especially around async and interfaces?

## Short Answer

A `ref struct` is a stack-only value type that cannot be boxed, stored in normal heap locations, or used in ways that could let it outlive the stack frame it depends on. C# imposes strict rules because many `ref struct` values wrap managed pointers or stack memory, and letting them escape would be unsafe. `Span<T>` is the canonical example: it gives fast, allocation-free access to contiguous memory while the language prevents invalid lifetimes.

## Detailed Explanation

### Why `ref struct` Exists

Some types need to represent memory that is only valid for a short scope, such as stackalloc buffers, slices over arrays, or regions of native memory. A normal struct could be boxed or stored inside a heap object, which would let that value outlive the memory it points at. That would be unsafe.

`ref struct` solves this by making the type **stack-only**. The compiler enforces rules that keep the value from escaping beyond the lifetime of the referenced memory.

| Capability | Normal struct | `ref struct` |
|---|---|---|
| Can be boxed | Yes | No |
| Can be field of class | Yes | No |
| Can cross `await`/`yield` boundary | Yes | No |
| Can be used with stackalloc safely | Limited | Yes, intended |
| Common example | `DateTime` | `Span<T>` |

> **Warning:** The restriction is about *lifetime safety*, not performance alone. `ref struct` is not just “a faster struct”; it is a type that the compiler must keep from escaping.

### Why `Span<T>` Is a `ref struct`

`Span<T>` conceptually contains a reference to the first element plus a length. The underlying memory may come from:

- a managed array
- `stackalloc`
- native memory

If a `Span<T>` over stack memory were boxed or stored on the heap, it could survive after the method returned, leaving a dangling reference. By making `Span<T>` a `ref struct`, C# prevents that misuse at compile time.

### Important Restrictions

Because `ref struct` values cannot escape safely, the language disallows several scenarios:

- cannot be boxed to `object`
- cannot be stored as a field in a class or normal struct
- cannot be captured by lambdas that outlive the scope
- cannot be used across `await` or `yield return`
- historically could not implement interfaces

These rules can feel strict, but they are what make `Span<T>` practical without introducing unsafe lifetime bugs into normal C# code.

### Async and Iterator Boundaries

Async methods and iterators transform local variables into state-machine objects stored on the heap. If a `ref struct` local crossed an `await`, it would need to be stored in that heap state machine, which is forbidden. That is why you can use `Span<T>` freely in synchronous hot paths, but for async flows you usually switch to `Memory<T>`. See [span-t-and-memory-t.md](./span-t-and-memory-t.md).

### C# 13 and `allows ref struct`

C# 13 adds the `allows ref struct` generic anti-constraint so generic code can explicitly say a type parameter may be a `ref struct`. This is important because older generic APIs often excluded stack-only types entirely. The feature makes certain abstractions more flexible while still preserving escape analysis rules.

### Interview Takeaway

The interviewer usually wants two ideas: `ref struct` is stack-only, and the restrictions exist to prevent invalid lifetimes. Mentioning `Span<T>` and async boundaries is usually enough to show strong understanding.

## Code Example

```csharp
namespace RuntimeSamples;

public ref struct LineParser(ReadOnlySpan<char> input)
{
    private ReadOnlySpan<char> _remaining = input;

    public ReadOnlySpan<char> ReadToken()
    {
        int separator = _remaining.IndexOf(',');
        if (separator < 0)
        {
            ReadOnlySpan<char> token = _remaining;
            _remaining = ReadOnlySpan<char>.Empty;
            return token;
        }

        ReadOnlySpan<char> next = _remaining[..separator];
        _remaining = _remaining[(separator + 1)..];
        return next;
    }
}

public static class RefStructDemo
{
    public static void Main()
    {
        Span<int> buffer = stackalloc int[4]; // Stack memory
        buffer[0] = 10;
        buffer[1] = 20;

        var parser = new LineParser("red,green,blue".AsSpan());
        Console.WriteLine(parser.ReadToken().ToString());

        // object boxed = buffer;            // ❌ Compile-time error: cannot box ref struct
        // await Task.Yield();               // ❌ A Span<T> local cannot survive across await
    }
}
```

## Common Follow-up Questions

- Why can `Memory<T>` be used in async code while `Span<T>` cannot?
- Why is boxing forbidden for `ref struct`?
- Can a `ref struct` be a generic type argument in older C# versions?
- What problems would happen if a `Span<T>` over `stackalloc` escaped to the heap?
- How does C# 13 `allows ref struct` change generic API design?

## Common Mistakes / Pitfalls

- Treating `ref struct` as merely a performance optimization instead of a lifetime-safety feature.
- Trying to store `Span<T>` or another `ref struct` in a class field.
- Using `Span<T>` in an async method across an `await` and being surprised by the compiler error.
- Assuming every struct that works with memory should be a `ref struct`.
- Forgetting that stack-only restrictions also affect lambdas, iterators, and some generic abstractions.

## References

- [ref struct - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/ref-struct)
- [System.Span<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.span-1)
- [Memory<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [What's new in C# 13](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-13) (verify URL)
