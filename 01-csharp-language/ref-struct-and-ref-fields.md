# `ref struct` and `ref` Fields

**Category:** C# / Type System / Memory
**Difficulty:** 🔴 Senior
**Tags:** `ref struct`, `Span<T>`, `ref fields`, `stack`, `heap`, `memory-safety`, `C# 11`

## Question

> What is a `ref struct` in C#? Why is `Span<T>` a `ref struct`, and what restrictions does that impose?

Additional phrasings:
- *"What problem does `ref struct` solve, and why can't you put a `Span<T>` in a class field?"*
- *"What are `ref` fields (C# 11) and how do they relate to `ref struct`?"*

## Short Answer

A `ref struct` is a value type that is guaranteed by the compiler to live only on the stack — it can never be boxed, stored in a heap-allocated object, or used across `await` points. This guarantee exists to safely express a pointer into a memory buffer without risking the pointer outliving the buffer. `Span<T>` is a `ref struct` because it contains a managed reference (a pointer + length) into an arbitrary memory region; if `Span<T>` could escape to the heap, it might outlive the stack-allocated data it points to, causing memory corruption.

## Detailed Explanation

### The Problem `ref struct` Solves

Before `Span<T>` (introduced in .NET Core 2.1 / C# 7.2), there was no safe way to represent a typed slice of arbitrary memory (stack arrays, native memory, array segments) with zero overhead and without copying. The challenge was: how do you express "a pointer + length" in managed code safely?

The answer required a type with a **managed reference** (`ref T`) as a field. However, managed references are only valid while the memory they point to is alive. If such a type could be:
- stored in a class field (heap), or
- boxed to `object`, or
- captured by a lambda (which generates a heap-allocated closure),

…then it could outlive the stack frame it points into, leading to use-after-free — a critical safety violation in managed code.

`ref struct` is the compiler's mechanism to **statically prohibit all those escape paths**.

### Restrictions of `ref struct`

The compiler enforces:

| Operation | Allowed for `ref struct`? |
|---|---|
| Stack-local variable | ✅ Yes |
| Field in a `class` or non-`ref struct` | ❌ No |
| Field in another `ref struct` | ✅ Yes |
| Boxing to `object` or interface | ❌ No |
| Implementing interfaces | ❌ No (C# 12 relaxed this: `ref struct` can implement interfaces, but can only be used via the interface constraint in generic code, not boxed) |
| `async` method locals | ❌ No (state machine class can't hold it) |
| `yield` iterator locals | ❌ No |
| Captured by lambda/delegate | ❌ No |
| Array element type | ❌ No |
| Generic type argument | ❌ No (without `allows ref struct` constraint, C# 13) |

### How `Span<T>` Uses This

`Span<T>`'s internal representation (simplified):

```csharp
// Conceptual — actual implementation is in the runtime
ref struct Span<T>
{
    private ref T _reference;  // managed reference (ref field, C# 11)
    private int _length;
}
```

The `ref T _reference` field is a **managed reference** — it can point into a stack array, a heap array, or native memory. Because `Span<T>` is a `ref struct`, the compiler guarantees it never escapes the scope in which it was created, keeping `_reference` always valid.

### `ref` Fields (C# 11)

C# 11 (`.NET 7`) formalized `ref` fields in `ref struct`:

```csharp
ref struct Segment<T>
{
    public ref T FirstElement;  // ref field
    public int Length;
}
```

A `ref` field stores a managed reference (like `ref T`) rather than a value. It enables `ref struct` types to hold interior pointers to heap or stack memory. Previously, `Span<T>` used a runtime-internal hack; `ref` fields made this a language-level feature.

Rules for `ref` fields:
- Only allowed inside `ref struct`.
- Can be `ref readonly` to express a read-only interior reference.
- Must not outlive the referent (the compiler uses **ref safety scoping rules** to verify this).

### `ReadOnlySpan<T>` and Immutability

`ReadOnlySpan<T>` is also a `ref struct`, but its interior reference is `ref readonly T` — you can read elements but not write them. This enables zero-copy parsing of string literals:

```csharp
ReadOnlySpan<char> hello = "Hello, World!"; // no allocation — points into the string
```

### Performance and Use Cases

`ref struct` / `Span<T>` is the foundation of .NET's high-performance APIs:
- `MemoryMarshal`, `BinaryPrimitives`
- `System.Text.Json` internal parsing
- `System.IO.Pipelines`
- All `stackalloc`-based zero-copy patterns

[See: span-of-t.md](./span-of-t.md) for deep coverage of `Span<T>` usage.
[See: stack-vs-heap.md](./stack-vs-heap.md) for the memory model foundation.
[See: value-types-vs-reference-types.md](./value-types-vs-reference-types.md) for general struct/class distinctions.

## Code Example

```csharp
using System;

// === ref struct: can only live on the stack ===
ref struct StackBuffer
{
    private Span<int> _data;

    public StackBuffer(Span<int> data) => _data = data;

    public int Sum()
    {
        int total = 0;
        foreach (int v in _data) total += v;
        return total;
    }
}

// Usage
Span<int> memory = stackalloc int[] { 1, 2, 3, 4, 5 };
var buf = new StackBuffer(memory);
Console.WriteLine(buf.Sum()); // 15

// ❌ This would be a compile error:
// class Holder { StackBuffer _buf; } // ref struct can't be a field in a class

// === Span<T> zero-copy slicing ===
int[] array = { 10, 20, 30, 40, 50 };
Span<int> slice = array.AsSpan(1, 3); // [20, 30, 40] — no copy
slice[0] = 99;
Console.WriteLine(array[1]); // 99 — same memory

// === ReadOnlySpan<T> from a string literal — zero allocation ===
ReadOnlySpan<char> greeting = "Hello".AsSpan();
Console.WriteLine(greeting.Length); // 5

// === ref field (C# 11) ===
ref struct RefWrapper<T>
{
    public ref T Value;  // ref field — stores a managed reference

    public RefWrapper(ref T val) => Value = ref val;
}

int x = 42;
var wrapper = new RefWrapper<int>(ref x);
wrapper.Value = 100;
Console.WriteLine(x); // 100 — wrapper.Value refers directly to x

// ❌ Cannot use ref struct across await:
// async Task FooAsync()
// {
//     Span<int> s = stackalloc int[4];
//     await Task.Delay(1);  // compile error: s cannot be used across await
// }
```

## Common Follow-up Questions

- How do `Span<T>` and `Memory<T>` complement each other, and when would you use `Memory<T>` instead?
- What are the ref safety rules the compiler uses to verify `ref struct` lifetimes?
- What changed in C# 12/13 regarding `ref struct` implementing interfaces?
- How does `stackalloc` interact with `ref struct` and what are the size limits?
- How does `System.IO.Pipelines` use `ref struct` internally?
- What is `scoped ref` (C# 11) and what problem does it solve for `ref struct` parameters?

## Common Mistakes / Pitfalls

- **Trying to store `Span<T>` in a class field.** This is a compile error by design. Use `Memory<T>` (which is heap-safe) if you need a heap-stored slice.
- **Using `Span<T>` across `await` points.** The compiler will reject this. Restructure to capture data before `await` or use `Memory<T>` for the async portion.
- **Expecting `ref struct` to work with generics without `allows ref struct`.** Prior to C# 13, `Span<T>` couldn't be a type argument to generic methods/types. C# 13 added `allows ref struct` as a constraint to opt into this.
- **Creating excessively large `stackalloc` buffers.** The stack is ~1 MB per thread; allocating large buffers with `stackalloc` risks `StackOverflowException`. The typical safe maximum is a few kilobytes. Use `ArrayPool<T>` for larger buffers.
- **Confusing `readonly ref struct` with `ref readonly struct`.** `readonly ref struct` (the type is both `ref struct` and immutable), vs `ref readonly` fields inside a `ref struct` — these have different semantics.

## References

- [ref structure types — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/ref-struct)
- [System.Span<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.span-1)
- [ref fields and scoped ref — C# 11 what's new](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-11#ref-fields-and-ref-scoped-variables)
- [Safe context rules — C# spec](https://learn.microsoft.com/dotnet/csharp/language-reference/language-specification/structs#ref-safe-contexts) (verify URL)
- [Span<T> and Memory<T> usage guidelines — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
