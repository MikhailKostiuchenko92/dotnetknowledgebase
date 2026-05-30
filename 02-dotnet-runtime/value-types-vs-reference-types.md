# Value Types vs Reference Types

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟢 Junior
**Tags:** `value types`, `reference types`, `struct`, `class`, `boxing`, `heap`, `stack`

## Question

> What is the difference between value types and reference types in .NET?

Also asked as:
> When does a value type live on the stack versus the heap?
> How do copy semantics differ for `struct` and `class`, and when should you choose one over the other?

## Short Answer

Value types usually store their data inline and are copied by value, while reference types are accessed through a reference that points to an object on the managed heap. The important caveat is that a value type is not automatically a stack object: if a struct is a field inside a class or an element in an array, its bits live inside that heap object. Choose a `struct` when the type is small, immutable, and truly has value semantics; choose a `class` when identity, inheritance, or shared mutable state matters.

## Detailed Explanation

### What "Value" and "Reference" Really Mean

In .NET, the distinction is about **representation and assignment semantics**, not simply “stack versus heap.” A value type (`int`, `double`, custom `struct`) contains its data directly. A reference type (`string`, arrays, custom `class`) is represented by a reference that points to an object elsewhere.

When you assign a value type, the runtime copies the value. When you assign a reference type, the runtime copies the reference, so both variables point to the same object.

| Aspect | Value type (`struct`) | Reference type (`class`) |
|---|---|---|
| Assignment | Copies the value | Copies the reference |
| Default storage | Inline where declared | Object on managed heap |
| Nullability | Non-null by default (`T?` for nullable) | Can be `null` |
| Inheritance | No user-defined inheritance hierarchy | Supports inheritance/polymorphism |
| Boxing risk | Yes, when treated as `object` or interface | No boxing |

> **Warning:** “Value type = stack” is an interview trap. A struct field inside a class instance lives inside that class object on the heap, and a struct in an array lives inline inside the array object on the heap.

### Stack vs Heap Allocation Caveat

Local variables of value type are often stored in the current stack frame or registers, which is why they feel lightweight. But storage depends on context and JIT optimization, not the keyword alone. Consider these cases:

- A local `int x = 42;` is typically stack or register-resident.
- A `Point` struct field inside `class Window` lives inside the `Window` heap object.
- An array like `Point[]` is a heap object, and each `Point` element is stored inline inside that array.

This is why interviewers often say that value types are **inline-friendly**, not strictly stack-only.

### Copy Semantics vs Reference Semantics

Copying a small immutable struct is cheap and predictable. Copying a reference type is also cheap, but both variables now share the same object identity and mutations are visible through every alias.

That difference drives design choices. If two instances with the same data should be considered the same *value*, a struct can be a good fit. If the object has lifecycle, identity, or evolving state, a class is usually better.

### When to Choose Struct vs Class

A practical guideline is:

- Prefer `struct` when the type is **small (often ≤ 16 bytes)**
- Make it **immutable**
- Use it when the type represents a value, such as coordinates, ranges, or money
- Avoid it if you need inheritance or frequent mutation

Large mutable structs are problematic because each assignment copies all fields and readonly use sites can trigger defensive copies. For many domain models, `class` is the safer default.

### Boxing: The Hidden Cost

If a value type is treated as `object` or as a non-generic interface, the CLR may need to **box** it: allocate an object on the heap and copy the value into that object. That adds allocation and GC pressure, which is why boxing matters in hot paths. See [boxing-and-unboxing.md](./boxing-and-unboxing.md).

### Why This Matters in Interviews

The core idea is that value types optimize for compact, inline storage and value semantics, while reference types optimize for identity and object-oriented flexibility. The best answer avoids oversimplifying the memory model and explicitly calls out boxing and the stack/heap caveat.

## Code Example

```csharp
namespace RuntimeSamples;

public readonly struct Point(int x, int y)
{
    public int X { get; } = x;
    public int Y { get; } = y;
}

public sealed class Container
{
    // This struct field lives inside the heap object for Container.
    public Point Location { get; init; } = new(10, 20);
}

public static class ValueVsReferenceDemo
{
    public static void Main()
    {
        Point p1 = new(1, 2);
        Point p2 = p1; // Copies both fields.
        Console.WriteLine($"Struct copy: {p1.X},{p1.Y} == {p2.X},{p2.Y}");

        var c1 = new Container();
        var c2 = c1; // Copies only the reference.
        Console.WriteLine(ReferenceEquals(c1, c2)); // True

        object boxed = p1; // Boxing: heap allocation + value copy.
        Point unboxed = (Point)boxed; // Unboxing copies the value back out.
        Console.WriteLine($"Unboxed point: {unboxed.X},{unboxed.Y}");

        Point[] points = [new(3, 4), new(5, 6)];
        Console.WriteLine(points[0].X); // Struct elements live inline in the heap array.
    }
}
```

## Common Follow-up Questions

- Why is `string` a reference type even though it behaves like a value in many APIs?
- What is boxing, and when does it happen implicitly?
- Why are small immutable structs recommended over large mutable ones?
- How do arrays of structs differ from arrays of classes in memory layout?
- When does passing a struct to a method copy it, and how can `in` or `ref` change that?

## Common Mistakes / Pitfalls

- Saying that all value types are allocated on the stack and all reference types are allocated on the heap.
- Using a large mutable struct and then paying for hidden copies on every assignment or method call.
- Choosing `struct` for something that really needs identity, inheritance, or shared mutable state.
- Forgetting that boxing turns a value type operation into a heap allocation.
- Assuming copying a reference type clones the object rather than just copying the reference.

## References

- [Value types - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/value-types)
- [Reference types - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/reference-types)
- [Choosing between class and struct](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [Boxing and unboxing - C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/types/boxing-and-unboxing)
