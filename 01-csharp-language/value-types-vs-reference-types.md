# Value Types vs Reference Types

**Category:** C# / Type System
**Difficulty:** 🟢 Junior
**Tags:** `value-types`, `reference-types`, `stack`, `heap`, `copy-semantics`, `equality`

## Question

> What is the difference between value types and reference types in C#?

Additional phrasings you may hear:
- *"When you assign a struct to another variable, what happens compared to assigning a class?"*
- *"Why does modifying a copied struct not affect the original?"*

## Short Answer

Value types (e.g., `int`, `struct`, `enum`) store their data directly in the variable; assigning one copies the entire value. Reference types (e.g., `class`, `string`, `array`) store a reference (pointer) to the data on the heap; assigning one copies only the reference, so both variables point to the same object. This distinction drives copy semantics, equality behavior, and memory allocation patterns.

## Detailed Explanation

### What Are Value Types?

A **value type** holds its data inline — wherever the variable lives (stack slot, object field, array element), that's where the bytes are. The built-in numeric types (`int`, `double`, `decimal`), `bool`, `char`, `DateTime`, and any user-defined `struct` or `enum` are value types.

Key characteristics:
- **Copy semantics:** assignment copies the full value; the two variables are independent.
- **Default equality:** `==` and `Equals` compare fields by value (for primitive types; user-defined structs need to override).
- **Cannot be `null`** (unless wrapped in `Nullable<T>` / `T?`).

### What Are Reference Types?

A **reference type** variable holds a managed pointer (reference) to an object on the **managed heap**. Classes, interfaces, delegates, arrays, and `string` are reference types.

Key characteristics:
- **Reference semantics:** assignment copies the reference, not the object — both variables now point to the same instance.
- **Default equality:** `==` compares references (identity), not content (unless overridden — `string` and records override this).
- **Can be `null`:** a reference variable that holds no address.

### Memory Layout

| Aspect | Value type | Reference type |
|---|---|---|
| Where data lives | Inline with the variable | Managed heap |
| Variable contains | The actual data bytes | A managed pointer |
| Assignment | Full data copy | Reference copy |
| GC involvement | No (unless boxed or in an object) | Yes |
| Default `Equals` | Field-wise (for primitives) | Reference identity |
| Can be `null` | No (only via `Nullable<T>`) | Yes |

### Copy vs Reference Semantics in Practice

When you pass a value type to a method, the method receives its own copy — mutations inside the method do **not** affect the caller's variable. With a reference type, both the caller and the callee share the same heap object, so mutations to the object's fields are visible to the caller.

> **Gotcha:** passing a reference type *by value* (the default) still shares the object — you can mutate its fields. What you *cannot* do is reassign the caller's variable to a different object without `ref`.

### User-Defined Structs

You can define your own value types using `struct`. Keep structs:
- **Small** (≤ 16 bytes is a common rule of thumb; larger structs pay higher copy costs).
- **Immutable** where possible — mutable structs are a frequent source of subtle bugs.
- **Logically a single value** (e.g., a 2D point, a color, a money amount).

[See: `ref struct` and restrictions](./ref-struct-and-ref-fields.md) for the special `ref struct` variant (e.g., `Span<T>`).

## Code Example

```csharp
// --- Value type: struct ---
Point a = new Point(1, 2);
Point b = a;           // full copy
b.X = 99;
Console.WriteLine(a.X); // 1 — a is unaffected

// --- Reference type: class ---
var p1 = new Person("Alice");
var p2 = p1;           // copy of the reference
p2.Name = "Bob";
Console.WriteLine(p1.Name); // "Bob" — both point to the same object

// --- Default equality ---
Console.WriteLine(a == new Point(1, 2));       // true  — value equality
Console.WriteLine(p1 == new Person("Bob"));    // false — reference equality (default)

// --- Nullable value type ---
int? maybe = null;     // Nullable<int>
Console.WriteLine(maybe.HasValue); // false

// Supporting types (file-scoped namespace, .NET 8)
struct Point(int X, int Y)          // primary constructor syntax (C# 12)
{
    public int X = X;
    public int Y = Y;
}

class Person(string name)
{
    public string Name { get; set; } = name;
}
```

## Common Follow-up Questions

- How does boxing relate to value types, and what are the performance implications? ([See: boxing-and-unboxing.md](./boxing-and-unboxing.md))
- Are value types always allocated on the stack?  ([See: stack-vs-heap.md](./stack-vs-heap.md))
- How does equality work for `struct` types you define yourself — do you need to override `Equals` and `GetHashCode`?
- What is the difference between `ref`, `out`, and `in` parameters and how do they affect value-type semantics?
- Why are strings reference types but behave like values in equality comparisons?
- When would you choose a `struct` over a `class` in a new design?

## Common Mistakes / Pitfalls

- **Assuming value types are always on the stack.** A `struct` field inside a `class` lives on the heap with the containing object; a boxed value type also lives on the heap.
- **Mutable structs leading to silent copy bugs.** Calling a method on a `struct` returned from a property creates a temporary copy; mutating it mutates the copy, not the original. The compiler warns about some of these in newer versions.
- **Forgetting that `string` is a reference type.** It has value-like equality (`==` is overloaded) but is still heap-allocated and reference-compared by default when using `object` references.
- **Comparing user-defined structs without overriding `Equals`/`GetHashCode`.** The default `ValueType.Equals` uses reflection-based field comparison which is slow and allocates; always override for structs used as dictionary keys or in collections.
- **Large struct copies in hot paths.** Passing a big struct by value to a method or storing it in a non-`ref` local creates a full copy, which can be expensive.

## References

- [Value types (C# reference) — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/value-types)
- [Reference types (C# reference) — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/reference-types)
- [Choosing Between Class and Struct — .NET Design Guidelines](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [Structure types — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
