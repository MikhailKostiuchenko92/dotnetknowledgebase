# With Expressions and Non-Destructive Mutation

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `with`, `records`, `record-struct`, `immutability`, `shallow-copy`

## Question
> What is a `with` expression in C#, and how does it support non-destructive mutation?

Related phrasings:
- "How does `with` create a modified copy instead of changing the original object?"
- "What does the compiler generate for `with` on records, and how is it different for structs?"
- "Why can `with` be dangerous when nested reference-type members exist?"

## Short Answer
A `with` expression creates a new value from an existing one and then applies selected member changes to the new copy. In modern C# on .NET 8/9, it is most commonly used with records, but it also works with struct types. The important detail is that the copy is usually shallow, so nested mutable reference-type members are still shared unless you explicitly clone them too.

## Detailed Explanation

### What Non-Destructive Mutation Means
Non-destructive mutation means you model a state change by creating a new object or value instead of mutating the original instance in place. That style fits immutable design well because the old value remains valid and observable while the new value represents the changed state.

In C#, the `with` expression is the built-in syntax for that pattern:

- copy the original value
- apply the listed assignments to the copy
- return the new value

That makes code concise and readable for DTOs, messages, and value objects, especially when combined with [records-vs-classes.md](./records-vs-classes.md) and [init-only-properties.md](./init-only-properties.md).

### How `with` Works for Record Classes
For record classes, `with` relies on compiler-generated copy machinery. Conceptually, the runtime starts from a copy of the source record and then runs object-initializer-style assignments for the members you specify.

The compiler synthesizes members so record classes can support this naturally, including copy behavior tied to record semantics. That is one reason records feel "data-first" in C# 12/13.

| Scenario | What `with` does |
|---|---|
| `record class` | Creates a new record instance based on the source record, then assigns the specified members |
| `record struct` | Copies the value, then assigns the specified members on the copied value |
| `struct` | Copies the struct value, then applies the specified member assignments |

For reference-type records, this means the result is a different instance. Equality may still say they are equal if all participating values match, as explained in [value-equality-in-records.md](./value-equality-in-records.md).

### How `with` Works for Structs
For structs, the behavior is simpler: the value is copied, then the specified members are changed on that copy. This aligns with normal value-type semantics from [class-vs-struct.md](./class-vs-struct.md) and [record-struct-vs-record-class.md](./record-struct-vs-record-class.md).

That also means `with` on a large struct can be more expensive than it first appears, because copying the full value may cost something. For small immutable structs, it is usually clear and efficient enough.

### `with` Is Usually a Shallow Copy
This is the most important interview point. `with` does **not** automatically deep-clone nested object graphs. If a copied record contains a `List<string>`, both the old and new record may still reference the same list instance.

> **Warning:** `with` is copy-plus-update, not deep cloning. If the object graph contains mutable reference-type members, changing those nested objects can affect both the original and the copied value.

That is why `with` works best when the whole graph is immutable, or when you manually clone the nested members that need isolation.

### Why `with` Pairs So Well with Records
Records encourage immutable APIs through generated equality, friendly printing, and concise initialization. `with` completes that model by making state transitions readable:

- `draft with { Status = "Published" }`
- `order with { Total = order.Total + 10m }`
- `user with { Address = user.Address with { City = "Kyiv" } }`

That last example shows how nested non-destructive mutation often becomes a chain of `with` expressions.

### When to Use It
`with` is a strong fit when:

- the type is immutable or mostly immutable
- changes are small relative to the full object
- you want expressive state transitions
- equality and snapshot-style reasoning matter

It is a weaker fit when:

- the type is heavily mutable anyway
- the object graph is large and deeply nested
- deep copies are required for safety

In those cases, explicit constructors, factory methods, or dedicated cloning code may be clearer.

## Code Example
```csharp
using System;
using System.Collections.Generic;

var original = new UserPreferences("dark")
{
    RecentProjects = new List<string> { "dotnetknowledgebase", "sample-api" }
};

var updated = original with { Theme = "light" }; // New record instance.
updated.RecentProjects.Add("console-tool");       // Mutates the shared list.

Console.WriteLine(original.Theme);                 // dark
Console.WriteLine(updated.Theme);                  // light
Console.WriteLine(original.RecentProjects.Count);  // 3: shallow copy shares nested list

var hd = new ScreenSize { Width = 1920, Height = 1080 };
var ultrawide = hd with { Width = 3440 };          // Struct copy, then update the copy.

Console.WriteLine(hd);         // ScreenSize { Width = 1920, Height = 1080 }
Console.WriteLine(ultrawide);  // ScreenSize { Width = 3440, Height = 1080 }

public record UserPreferences(string Theme)
{
    public List<string> RecentProjects { get; init; } = new();
}

public struct ScreenSize
{
    public int Width { get; init; }
    public int Height { get; init; }

    public override string ToString() => $"ScreenSize {{ Width = {Width}, Height = {Height} }}";
}
```

## Common Follow-up Questions
- How does `with` behave differently for `record class`, `record struct`, and plain `struct`?
- Why is `with` usually described as a shallow copy?
- What members can you assign inside a `with` expression?
- When would a custom copy constructor or factory be preferable to `with`?
- How does `with` interact with `init` accessors and immutable design?

## Common Mistakes / Pitfalls
- Assuming `with` performs a deep clone of nested objects.
- Using `with` on large structs without thinking about copy cost.
- Combining `with` with mutable child collections and then being surprised by shared state.
- Treating `with` as a record-only feature when it also works for struct types.
- Using `with` on fundamentally mutable domain entities where direct mutation is the clearer model.

## References
- [The `with` expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/with-expression)
- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [record - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
- [See: init-only-properties.md](./init-only-properties.md)
- [See: record-struct-vs-record-class.md](./record-struct-vs-record-class.md)
