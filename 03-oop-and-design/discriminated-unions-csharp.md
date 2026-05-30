# Discriminated Unions in C#

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🔴 Senior
**Tags:** `discriminated-unions`, `OneOf`, `records`, `pattern-matching`

## Question
> C# does not have native discriminated unions today, so how can you model them, and why are they often better than booleans, nullable fields, or weak status enums?

## Short Answer
A discriminated union models a value that can be exactly one of several named cases, where each case can carry different data. In C#, you usually approximate that with a closed record hierarchy plus pattern matching, or with a library such as OneOf. The big benefit is correctness: callers must handle valid outcomes explicitly, and impossible state combinations become much harder to represent.

## Detailed Explanation
### What problem discriminated unions solve
A lot of everyday C# APIs return loosely related values such as `bool Success`, `string? Error`, `T? Value`, and maybe an enum on top. That design lets invalid combinations slip through, such as `Success = true` and `Error = "failed"` at the same time. A discriminated union avoids that by saying the result is exactly one case from a known set.

| Modeling approach | Typical weakness |
| --- | --- |
| Boolean + nullable payloads | Invalid combinations are easy |
| Enum + optional properties | Callers must guess which fields matter |
| Discriminated union | Valid cases are explicit by construction |

For example, a payment operation might return `Paid(receiptId)`, `Declined(reason)`, or `ValidationError(errors)`. Each case carries only the data that belongs to that state.

### How to model unions in C# today
C# still lacks native discriminated union syntax like F#, so the usual approaches are pragmatic:
1. A closed class or record hierarchy.
2. A third-party library such as OneOf.
3. A result type tailored to your domain, sometimes with nested records.

Records are a good fit because they are concise, immutable by default, and work naturally with pattern matching. A sealed hierarchy gives you clear case types and readable `switch` expressions when consuming them.

OneOf reduces boilerplate, which can be attractive in application code. The trade-off is that the domain meaning of the cases can become less self-documenting than a named hierarchy designed around your business language.

> Warning: discriminated unions work best when the set of cases is truly limited. If external plugins or third parties must keep adding new variants, interfaces may model that extensibility better.

### Why they improve design
The biggest benefit is making illegal states unrepresentable, or at least much harder to create. That usually leads to better APIs, fewer null checks, and fewer “this field only matters when status is X” comments. They are especially strong for workflow results, parser outcomes, state machines, and message handling.

They also pair extremely well with pattern matching. A `switch` expression over known cases is often clearer than nested `if` statements checking enums and nulls. The compiler cannot fully enforce exhaustiveness the way some functional languages can, but the structure still guides developers toward explicit case handling.

### Trade-offs and future direction
The cost is ceremony. Without native syntax, you write more types or introduce a library dependency. Also, adding a new case is usually a breaking change because every consumer should decide how to handle it. That can feel expensive, but it is often desirable because it prevents silently ignoring new outcomes.

The interview-ready answer is balanced: discriminated unions are not just a functional-programming novelty. They are a design technique for expressing domain outcomes safely. In modern C#, the idiomatic way to model them is records plus pattern matching, with libraries like OneOf as a lighter-weight option.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        PaymentResult result = PaymentProcessor.Process(120m);
        Console.WriteLine(PaymentProcessor.Describe(result));
    }
}

internal abstract record PaymentResult;
internal sealed record Paid(string ReceiptId) : PaymentResult;
internal sealed record Declined(string Reason) : PaymentResult;
internal sealed record ValidationError(string Message) : PaymentResult;

internal static class PaymentProcessor
{
    public static PaymentResult Process(decimal amount)
    {
        if (amount <= 0)
        {
            return new ValidationError("Amount must be positive.");
        }

        return amount <= 500m
            ? new Paid(Guid.NewGuid().ToString("N"))
            : new Declined("Amount exceeded the demo limit.");
    }

    public static string Describe(PaymentResult result) => result switch
    {
        Paid paid => $"Paid with receipt {paid.ReceiptId}",
        Declined declined => $"Declined: {declined.Reason}",
        ValidationError error => $"Validation error: {error.Message}",
        _ => throw new ArgumentOutOfRangeException(nameof(result))
    };
}
```

## Common Follow-up Questions
- Why are discriminated unions safer than enums plus nullable payload fields?
- How would you model a union in C# without language support?
- When is OneOf a better choice than a custom record hierarchy?
- How does pattern matching make union-like modeling practical in C#?
- What is the maintenance cost of adding a new case?

## Common Mistakes / Pitfalls
- Returning status enums plus unrelated nullable fields instead of modeling real cases.
- Leaving the base type open so arbitrary derived types can break your assumptions.
- Using unions for highly extensible plugin scenarios where interfaces are a better fit.
- Forgetting to update `switch` expressions when a new case is introduced.
- Mixing exceptional failures and ordinary union cases without a clear team convention.

## References
- [C# record types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
- [Pattern matching overview](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/functional/pattern-matching)
- [Patterns - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)
- [OneOf](https://github.com/mcintyre321/OneOf)
