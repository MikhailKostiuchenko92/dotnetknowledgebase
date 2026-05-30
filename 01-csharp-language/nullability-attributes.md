# Nullable Analysis Attributes

**Category:** C# / Nullability
**Difficulty:** Senior
**Tags:** `nullable-reference-types`, `attributes`, `analyzers`, `api-design`

## Question
> What are C# nullability analysis attributes such as `[MaybeNull]`, `[NotNull]`, `[MaybeNullWhen]`, `[NotNullWhen]`, `[MemberNotNull]`, and `[DoesNotReturn]`, and how do they affect nullable warnings?
>
> How do you communicate null-state information to the compiler when plain nullable annotations are not expressive enough?
>
> How does the Roslyn analyzer use nullability attributes to understand postconditions and control flow?

## Short Answer
Nullable analysis attributes let you describe null-state facts that `?` alone cannot express. They do not change runtime behavior by themselves; instead, the compiler and analyzers use them to refine flow analysis, reduce false positives, and warn callers more accurately.

## Detailed Explanation
### Why nullable annotations are not enough
Nullable reference types tell the compiler whether a reference is intended to allow `null`, but many APIs have conditional behavior that depends on method results, helper methods, or initialization patterns. That is where nullable analysis attributes help.

| Attribute | Typical target | Meaning for analysis |
| --- | --- | --- |
| `[MaybeNull]` | Return value, `out`, field, property | Value may be `null` even if the type is non-nullable |
| `[NotNull]` | Parameter, field, property, return value | Value is not `null` after the method/assignment point |
| `[MaybeNullWhen(false)]` | `out`, `ref`, parameter | Value may be `null` when the method returns the specified boolean |
| `[NotNullWhen(true)]` | Parameter | Argument is not `null` when the method returns the specified boolean |
| `[MemberNotNull]` | Method, property | Listed members are guaranteed non-null after successful return |
| `[DoesNotReturn]` | Method | Method never returns, so analysis stops there |

A good mental model is: nullable annotations describe types, while these attributes describe control-flow facts.

> Tip: use these attributes when you are shaping a reusable API. They are most valuable when callers consume your code, not just inside a single method body.

For background, see [Nullable Reference Types](./nullable-reference-types.md) and [Null-Forgiving Operator](./null-forgiving-operator.md).

### How Roslyn uses them in flow analysis
Roslyn tracks null-state as code flows through branches, throws, and assignments. Nullable analysis attributes act like extra facts fed into that flow engine.

For example, if a helper returns `true` and a parameter is annotated with `[NotNullWhen(true)]`, the compiler treats that parameter as definitely non-null inside the `if` branch. Similarly, `[DoesNotReturn]` tells the analyzer that execution stops, so code after a call can assume the exceptional path is gone.

This is especially useful for:
- Validation helpers
- `TryGet...` patterns
- Lazy initialization methods
- Methods that throw on failure
- Generic APIs where plain `T?` can be ambiguous

### Common patterns and trade-offs
`[MaybeNull]` and `[NotNull]` are often used when the surface type should stay non-nullable for ergonomics, but specific flows need additional precision. A classic case is `T FindOrDefault()` in generic code, where `default` may be `null` for reference types or a zeroed value for value types; see [Nullable Annotations in Generics](./nullable-in-generics.md) and [Generic Constraints](./generic-constraints.md).

`[MemberNotNull]` is ideal when a helper initializes required members that the compiler cannot see through. It is often better than sprinkling `!` because it documents the contract instead of suppressing warnings.

> Warning: these attributes do not enforce runtime checks. If you mark something `[NotNull]` but still return `null`, the compiler trusts your contract and callers may fail later.

## Code Example
```csharp
using System;
using System.Diagnostics.CodeAnalysis;

Console.WriteLine(FormatLength("Copilot"));
Console.WriteLine(FormatLength(null));

string? alias = null;
EnsureAssigned(ref alias);
Console.WriteLine(alias.Length); // Safe after EnsureAssigned.

var settings = new Settings();
settings.EnsureLoaded();
Console.WriteLine(settings.ConnectionString.Length); // Safe after EnsureLoaded.

static string FormatLength(string? input)
{
    if (IsNotNullOrWhiteSpace(input))
    {
        return $"Length: {input.Length}"; // input is known non-null here.
    }

    return "No value";
}

static bool IsNotNullOrWhiteSpace([NotNullWhen(true)] string? value)
{
    return !string.IsNullOrWhiteSpace(value);
}

[return: MaybeNull]
static T FindFirstOrDefault<T>(T[] items)
{
    if (items.Length > 0)
    {
        return items[0];
    }

    return default; // Runtime value may be null for reference types.
}

static void EnsureAssigned([NotNull] ref string? value)
{
    value ??= "fallback";
}

static bool TryGetFirst<T>(T[] items, [MaybeNullWhen(false)] out T value)
{
    if (items.Length > 0)
    {
        value = items[0];
        return true;
    }

    value = default;
    return false;
}

sealed class Settings
{
    public string? ConnectionString { get; private set; }

    [MemberNotNull(nameof(ConnectionString))]
    public void EnsureLoaded()
    {
        ConnectionString ??= "Server=.;Database=App;Trusted_Connection=True;";
    }
}

static class Guard
{
    public static void Fail(string message)
    {
        ThrowInvalidOperation(message);
    }

    [DoesNotReturn]
    private static void ThrowInvalidOperation(string message)
    {
        throw new InvalidOperationException(message);
    }
}
```

## Common Follow-up Questions
- When should I prefer a nullable analysis attribute over the null-forgiving operator?
- What is the difference between `[NotNull]` and `[NotNullWhen(true)]`?
- Why is `[MemberNotNull]` useful with lazy initialization or helper methods?
- How do these attributes behave in generic APIs returning `default`?
- Do nullable analysis attributes add any runtime validation automatically?

## Common Mistakes / Pitfalls
- Using nullable analysis attributes as if they were runtime guards.
- Applying `[NotNull]` or `[NotNullWhen]` to express a contract that the code does not actually satisfy.
- Overusing `!` instead of documenting the real postcondition with `[MemberNotNull]` or `[NotNullWhen]`.
- Forgetting that callers only benefit when nullable context is enabled.
- Assuming these attributes replace clear API naming and good method design.

## References
- [Microsoft Docs: Nullable static analysis attributes](https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis)
- [Microsoft Docs: Nullable reference types](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/nullable-reference-types)
- [See: Nullable Reference Types](./nullable-reference-types.md)
- [See: Null-Forgiving Operator](./null-forgiving-operator.md)
- [See: Nullable Annotations in Generics](./nullable-in-generics.md)
- [See: Custom Attributes](./custom-attributes.md)
