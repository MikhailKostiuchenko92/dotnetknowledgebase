# Record Structs

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `record struct`, `record class`, `value equality`, `with expressions`, `readonly struct`, `DTO`

## Question

> What is a `record struct`, and how is it different from a regular `struct` or `record class`?

Also asked as:
> When would you use `record struct` instead of `record class`?
> Are `record struct` types mutable, and how do value equality and `with` expressions work?

## Short Answer

A `record struct` is a value type with record-style generated members such as value-based equality, `Deconstruct`, and support for `with` expressions. Compared with a `record class`, it has value-type copy semantics and no object identity; compared with a regular struct, it gives you more generated boilerplate for data-centric scenarios. It is a good fit for small DTO-like values such as coordinates or money amounts, especially when you want concise syntax and value equality by default.

## Detailed Explanation

### What `record struct` Adds

A regular struct already has value semantics, but it does not automatically generate the rich “record” experience. A `record struct` adds synthesized members for equality, printing, and nondestructive mutation patterns.

| Type | Allocation model | Equality style | `with` support | Inheritance model |
|---|---|---|---|---|
| `struct` | Value type | Default field-based unless customized | No built-in synthesis | No hierarchy |
| `record struct` | Value type | Generated value equality | Yes | No hierarchy |
| `class` | Reference type | Reference equality by default | No built-in synthesis | Full hierarchy |
| `record class` | Reference type | Generated value equality over members | Yes | Record inheritance |

### Value Equality by Default

For record structs, the compiler generates equality members that compare data rather than object identity. That means two instances with the same component values compare equal without writing the full equality boilerplate yourself.

This makes record structs attractive for compact data carriers where identity is irrelevant.

### Positional Syntax and `with`

One of the biggest usability benefits is concise positional syntax:

```csharp
public readonly record struct Point(int X, int Y);
```

The compiler generates properties, a constructor, equality members, `ToString()`, and `Deconstruct`. You can then use `with` expressions to create a modified copy.

This feels similar to record classes, but the result is still a value type, so assignments copy the entire value.

> **Warning:** `with` on a record struct still copies the whole struct. That is usually fine for small values, but a large record struct still has large-copy costs.

### Mutable vs Readonly Record Structs

A plain `record struct` is mutable by default if its synthesized properties are writable. A `readonly record struct` is often a better choice because it reinforces immutability and behaves better in readonly contexts.

That leads to a practical rule:

- use `readonly record struct` for small immutable value objects
- use mutable `record struct` only when you truly need writable value properties

This connects directly to the guidance in [readonly-struct.md](./readonly-struct.md) and [value-types-vs-reference-types.md](./value-types-vs-reference-types.md).

### When to Use It

Good candidates include:

- coordinates and geometric values
- money or percentage value objects
- protocol message headers
- lightweight DTOs crossing internal layers

Bad candidates are large mutable domain entities or anything that needs inheritance, identity, or reference-based sharing.

### Interview Takeaway

The interview-ready answer is: a record struct is a struct with record conveniences. It keeps value-type behavior while generating useful members for value-based data objects. The nuance is that you still need normal struct discipline: keep it small and preferably immutable.

That is why record structs are great for compact values, but not a free pass to ignore normal value-type trade-offs such as copy cost and defensive-copy behavior in readonly contexts.

## Code Example

```csharp
namespace RuntimeSamples;

public readonly record struct Point(int X, int Y);

public record class Customer(string Id, string Name);

public static class RecordStructDemo
{
    public static void Main()
    {
        Point p1 = new(10, 20);
        Point p2 = p1 with { X = 99 }; // Creates a modified copy

        Console.WriteLine(p1); // Point { X = 10, Y = 20 }
        Console.WriteLine(p2); // Point { X = 99, Y = 20 }
        Console.WriteLine(p1 == new Point(10, 20)); // True: value equality

        Customer c1 = new("42", "Ada");
        Customer c2 = c1 with { Name = "Grace" }; // New reference-type record instance
        Console.WriteLine(ReferenceEquals(c1, c2)); // False
    }
}
```

## Common Follow-up Questions

- How is `record struct` different from `record class` in equality and copying behavior?
- Why is `readonly record struct` often better than mutable `record struct`?
- Does `with` on a record struct allocate memory?
- When would a regular struct be preferable to a record struct?
- Can a record struct participate in inheritance the way record classes can?

## Common Mistakes / Pitfalls

- Assuming a record struct is immutable without declaring it `readonly` or checking generated property setters.
- Using a large record struct and then paying for expensive copies with assignment or `with` expressions.
- Choosing `record struct` for entities that need identity rather than value semantics.
- Forgetting that record structs still cannot use class-style inheritance.
- Assuming `with` means in-place mutation; it creates a copy.

## References

- [Records - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
- [struct - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
- [Choosing between class and struct](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [Value types - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/value-types)
