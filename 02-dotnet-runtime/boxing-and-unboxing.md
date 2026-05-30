# Boxing and Unboxing

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟢 Junior
**Tags:** `boxing`, `unboxing`, `IL`, `struct`, `generics`, `allocations`, `GC`

## Question

> What are boxing and unboxing in .NET, and why do they matter for performance?

Also asked as:
> What do the IL `box` and `unbox.any` instructions do?
> Where does boxing happen implicitly when working with structs and interfaces?

## Short Answer

Boxing is the process of wrapping a value type in a heap-allocated object so it can be treated as `object` or as a non-generic interface; unboxing extracts the value back out as the target value type. The cost is not just a cast: boxing allocates memory and copies the value, which increases GC pressure in hot paths. Generics, generic collections, and `Span<T>`-based APIs help avoid boxing because they preserve the concrete value type at compile time.

## Detailed Explanation

### What the CLR Actually Does

A value type normally lives inline, but `object` and interface references point to heap objects. When the runtime needs a value type to behave like an object, it emits the IL instruction `box`, which allocates an object and copies the raw value into it. Later, `unbox.any` reads the value back out into a value-type variable.

Typical IL shape:

| C# | Representative IL |
|---|---|
| `object o = x;` | `ldloc x` → `box <T>` |
| `int y = (int)o;` | `ldloc o` → `unbox.any [System.Int32]` |
| `IFormattable f = x;` | `ldloc x` → `box <T>` |

> **Warning:** Unboxing is only valid if the boxed object really contains the exact value type you cast to. `object o = 42; long x = (long)o;` throws `InvalidCastException` even though numeric conversion from `int` to `long` normally exists.

### Where Boxing Happens Implicitly

Interviewers usually care less about the definition and more about **surprising boxing sites**:

- Assigning a struct to `object`
- Calling a non-generic interface method on a struct in a context that requires interface conversion
- Using legacy APIs such as `ArrayList`
- Passing value types through formatting APIs that take `object` or `params object[]`

Historically, `string.Format("{0}", number)` boxes `number` because the overload accepts `params object?[]`. Modern interpolated string handlers reduce some of this overhead in many cases, but boxing can still appear depending on the API shape.

### Why Boxing Hurts Performance

Boxing has two costs:

1. **Heap allocation** for the boxed wrapper object
2. **Value copy** from the original struct into that object

If this happens inside a loop, you create many short-lived heap objects and force more frequent garbage collections. That is why boxing often shows up in performance investigations: not because one box is catastrophic, but because repeated boxing is easy to overlook.

| Pattern | Allocation behavior |
|---|---|
| `ArrayList.Add(int)` | Boxes each `int` |
| `List<int>.Add(int)` | No boxing |
| `Equals(object)` on struct | Often boxes one side |
| `IEquatable<T>.Equals(T)` | Avoids boxing |

### How Generics Avoid Boxing

Generics are the main answer. In `List<int>`, the JIT knows the element type is `int`, so values stay as `int` rather than being wrapped as `object`. Similarly, generic constraints such as `where T : struct` still preserve the actual value type.

This is one reason modern .NET code prefers `List<T>`, `Dictionary<TKey,TValue>`, and generic equality/comparer interfaces over old non-generic collections.

### How `Span<T>` Helps

`Span<T>` and `ReadOnlySpan<T>` let you work with slices of arrays, stack memory, or native memory without converting elements to `object`. They are generic, stack-friendly abstractions, so operations can stay type-safe and allocation-free. See [span-t-and-memory-t.md](./span-t-and-memory-t.md).

### What to Say in an Interview

A strong answer explains the IL concept, names common implicit boxing scenarios, and ties the feature to real production impact: extra allocations and GC pressure. Mentioning generics and `IEquatable<T>` shows you know how to avoid it in practice.

## Code Example

```csharp
using System.Collections;

namespace RuntimeSamples;

public readonly struct Counter(int value) : IFormattable
{
    public int Value { get; } = value;

    public string ToString(string? format, IFormatProvider? formatProvider) =>
        Value.ToString(format, formatProvider);
}

public static class BoxingDemo
{
    public static void Main()
    {
        Counter counter = new(42);

        object boxed = counter; // IL: box RuntimeSamples.Counter
        Counter unboxed = (Counter)boxed; // IL: unbox.any RuntimeSamples.Counter
        Console.WriteLine(unboxed.Value);

        long before = GC.GetAllocatedBytesForCurrentThread();
        ArrayList list = new(); // Non-generic collection boxes value types.
        for (int i = 0; i < 10_000; i++)
        {
            list.Add(i); // Each Add boxes the int.
        }
        long arrayListBytes = GC.GetAllocatedBytesForCurrentThread() - before;

        before = GC.GetAllocatedBytesForCurrentThread();
        List<int> genericList = [];
        for (int i = 0; i < 10_000; i++)
        {
            genericList.Add(i); // Stores int directly, no boxing per element.
        }
        long genericListBytes = GC.GetAllocatedBytesForCurrentThread() - before;

        Console.WriteLine($"ArrayList allocated: {arrayListBytes:N0} bytes");
        Console.WriteLine($"List<int> allocated: {genericListBytes:N0} bytes");

        string message = string.Format("Value = {0}", counter); // Often boxes via params object[].
        Console.WriteLine(message);
    }
}
```

## Common Follow-up Questions

- Why does `List<int>` avoid boxing while `ArrayList` does not?
- How can implementing `IEquatable<T>` help avoid boxing in equality checks?
- Why can interface calls on structs introduce boxing?
- Does interpolated string syntax always avoid boxing in modern .NET?
- What is the difference between `unbox` and `unbox.any` in IL?

## Common Mistakes / Pitfalls

- Assuming boxing is just a cast rather than a heap allocation plus value copy.
- Using non-generic collections like `ArrayList` or `Hashtable` with value types in performance-sensitive code.
- Calling `Equals(object)` on structs and accidentally boxing during comparisons.
- Forgetting that formatting APIs with `object` or `params object[]` may box value types.
- Thinking unboxing performs numeric conversion; it only succeeds for the exact boxed value type.

## References

- [Boxing and unboxing - C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/types/boxing-and-unboxing)
- [OpCodes.Box Field](https://learn.microsoft.com/dotnet/api/system.reflection.emit.opcodes.box)
- [OpCodes.Unbox_Any Field](https://learn.microsoft.com/dotnet/api/system.reflection.emit.opcodes.unbox_any)
- [System.Span<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.span-1)
