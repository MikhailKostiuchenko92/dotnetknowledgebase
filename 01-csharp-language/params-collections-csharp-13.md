# `params` Collections in C# 13

**Category:** C# / Modern C# Features
**Difficulty:** Middle
**Tags:** `params`, `csharp-13`, `collection-expressions`, `ReadOnlySpan`, `api-design`

## Question

> What changed for `params` in C# 13, and why can it now work with collection types beyond arrays?

Also asked as:
- "How is C# 13 `params` different from classic `params T[]`?"
- "Can `params` use spans or other collection-like types now?"
- "What are the performance and API design implications of params collections?"

## Short Answer

Historically, `params` was limited to array parameters like `params int[] values`. C# 13 expands that model so `params` can work with additional recognized collection shapes, which makes APIs more flexible and can reduce unnecessary array allocations in some cases—especially with span-friendly designs. In .NET 9-era code, that is powerful, but public API authors still need to think about language-version compatibility, overload clarity, and whether convenience is worth a broader surface area.

## Detailed Explanation

### What actually changed

Classic C# lowers a `params` call into an array when the caller passes separate arguments. C# 13 generalizes the idea so the params parameter does not have to be only an array type. The compiler can target other supported collection forms, including span-friendly patterns and collection-expression-based construction scenarios.

| Version / style | Example | Main characteristic |
|---|---|---|
| Classic | `params int[] values` | Familiar, easy, often allocates an array |
| C# 13 collection-based | `params ReadOnlySpan<int> values` | More flexible, can be allocation-friendlier |
| Custom collection scenarios | Collection-shaped params target | Convenience with broader API design trade-offs |

### Why this matters for performance

For hot paths, `params T[]` can be surprisingly expensive if callers frequently pass a handful of values and each call allocates a new array. A span-based or other collection-based params target can let the compiler and runtime avoid some of that overhead, especially when combined with modern collection-expression lowering.

That does **not** mean every params API should be rewritten. For many business APIs, call convenience matters more than micro-optimizing a small allocation.

> **Warning:** Public APIs that depend on the latest `params` collection rules may be less friendly to older language versions or teams that are not yet on C# 13 / .NET 9.

### API design implications

Good reasons to use params collections:
- convenience-heavy helper APIs
- performance-sensitive helpers where arrays are avoidable
- span-oriented APIs that already operate on contiguous data

Reasons to stay with `params T[]` or avoid params altogether:
- you need maximum familiarity for broad audiences
- overload resolution would become confusing
- the API wants a stable, explicit collection abstraction from the caller

### Relationship to collection expressions

C# 13 params collections fit naturally with [collection-expressions.md](./collection-expressions.md). Both features make collection-shaped call sites more expressive, and both rely on understanding the target type and lowering behavior rather than assuming the syntax alone tells the whole story.

## Code Example

```csharp
using System;

namespace Demo;

Console.WriteLine(Sum(1, 2, 3, 4));
Console.WriteLine(Sum([10, 20, 30]));

static int Sum(params ReadOnlySpan<int> values)
{
    var total = 0;

    foreach (var value in values)
    {
        total += value; // Span-based iteration keeps the API concise and efficient.
    }

    return total;
}
```

## Common Follow-up Questions

- What limitation did classic `params T[]` have before C# 13?
- Why can params collections reduce allocations in some scenarios?
- When is `params T[]` still the better public API choice despite the new flexibility?
- How do collection expressions complement params collections at the call site?
- What compatibility concerns should library authors consider before exposing C# 13-only API shapes?

## Common Mistakes / Pitfalls

- Assuming every params collection call is allocation-free.
- Converting familiar APIs to newer params shapes without measuring or justifying the change.
- Ignoring language-version compatibility for consumers of a shared library.
- Making overload resolution harder just to save a little syntax or a small allocation.
- Forgetting that explicit collection parameters can still be clearer for many APIs.

## References

- [params keyword - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/params)
- [C# 13 params collections proposal](https://github.com/dotnet/csharplang/blob/main/proposals/csharp-13.0/params-collections.md)
- [Collection expressions (Collection literals) - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/collection-expressions)
- [See: collection-expressions.md](./collection-expressions.md)
- [See: target-typed-new.md](./target-typed-new.md)
