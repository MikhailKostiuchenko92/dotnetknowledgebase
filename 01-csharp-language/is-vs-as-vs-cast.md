# `is` vs `as` vs Cast

**Category:** C# / Type System
**Difficulty:** Junior
**Tags:** `is`, `as`, `cast`, `pattern-matching`, `null`, `type-checking`

## Question
> What is the difference between `is`, `as`, and a direct cast in C#?

Related phrasings:
- "When should I use `is T value`, `as`, or `(T)obj`?"
- "How do they differ in null handling and exceptions?"
- "Is `is` pattern matching usually better than `as` plus a null check?"

## Short Answer
Use a direct cast when failure should be exceptional, use `as` when you want a nullable result instead of an exception, and use `is T value` when you want both a safe type check and a strongly typed variable. In modern C# 12/13 on .NET 8/9, `is` pattern matching is usually the clearest choice because it avoids a second cast and makes control flow explicit. The key behavioral difference is simple: a bad direct cast throws, while `as` returns `null`.

## Detailed Explanation

### What Each Form Does
These three forms answer related but different questions.

| Form | Meaning | Failure behavior |
|---|---|---|
| `obj is T value` | "Is this a `T`, and if yes bind it" | Returns `false` |
| `obj as T` | "Try converting to `T` if possible" | Returns `null` |
| `(T)obj` | "Treat this as `T`" | Throws `InvalidCastException` |

The modern default in application code is often `is T value`, especially after pattern matching became central to C#.

### `is` Pattern Matching
`is T value` is both a test and a safe cast. If the value matches, you get a strongly typed variable in the true branch.

That makes it cleaner than older code like this:

```csharp
var dog = animal as Dog;
if (dog != null) { ... }
```

Today, this is usually preferred:

```csharp
if (animal is Dog dog) { ... }
```

### `as` and Null Handling
`as` attempts a reference or nullable conversion. If it cannot convert, it returns `null` instead of throwing.

That behavior can be useful, but it also means you must handle `null` correctly. It is not available for arbitrary non-nullable value-type casts.

> **Tip:** `as` is not "safer" unless you actually handle the resulting `null`. Otherwise you just moved the failure point farther away.

### Direct Casts
A direct cast is appropriate when you are confident the type is correct and a mismatch means a programmer error or invalid program state. It is explicit and fail-fast.

Examples include infrastructure code where an API contract guarantees the type, or places where silently continuing would hide a bug.

### Performance Nuance
Older advice often focused heavily on micro-performance. In modern .NET 8/9 code, readability and correct behavior matter more. The JIT is good, and in many real cases the difference is negligible.

Still, `is T value` is nice because it combines the check and typed binding in one expression instead of encouraging a separate check and cast.

### Practical Rule of Thumb
A good interview summary is:

- prefer `is T value` in most branching logic
- use `as` when `null` is the intended "not this type" result
- use direct casts when failure should be exceptional

This fits well with [pattern-matching-overview.md](./pattern-matching-overview.md) and [nullable-reference-types.md](./nullable-reference-types.md).

## Code Example
```csharp
using System;

Animal animal = new Dog("Rex");

if (animal is Dog dog)
{
    Console.WriteLine($"is-pattern: {dog.Name}"); // Safe and concise.
}

var dogOrNull = animal as Dog;
Console.WriteLine(dogOrNull?.Name ?? "Not a dog");

var unknown = new Cat("Milo");
Console.WriteLine(unknown as Dog is null); // True: failed cast returns null.

try
{
    var forcedDog = (Dog)unknown; // Throws because Cat is not Dog.
    Console.WriteLine(forcedDog.Name);
}
catch (InvalidCastException ex)
{
    Console.WriteLine(ex.GetType().Name);
}

public abstract record Animal(string Name);
public sealed record Dog(string Name) : Animal(Name);
public sealed record Cat(string Name) : Animal(Name);
```

## Common Follow-up Questions
- Why is `is T value` usually preferred over `as` plus a null check?
- When is a direct cast the right choice?
- Why can `as` not replace every kind of cast?
- How does nullable reference type analysis affect `as` results?
- How do these forms relate to switch expressions and pattern matching?

## Common Mistakes / Pitfalls
- Using `as` and then forgetting to handle the possible `null` result.
- Doing a separate type check and then another cast instead of using `is T value`.
- Using a direct cast when a mismatch is normal control flow rather than an exceptional situation.
- Assuming `as` works for every non-nullable value-type scenario.

## References
- [Type-testing operators and cast expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/type-testing-and-cast)
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
- [See: pattern-matching-overview.md](./pattern-matching-overview.md)
- [See: nullable-reference-types.md](./nullable-reference-types.md)
