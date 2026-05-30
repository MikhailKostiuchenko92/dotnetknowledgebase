# Argument Null Validation Patterns

**Category:** C# / Nullability
**Difficulty:** Middle
**Tags:** `null-checks`, `guard-clauses`, `exceptions`, `api-design`

## Question
> What are the recommended patterns for validating method arguments against `null` in modern C#?
>
> When should I use `ArgumentNullException.ThrowIfNull`, guard clauses, or custom validation helpers?
>
> How should null validation look in .NET 8/9 code, and what happened to the rejected C# `!!` parameter null-check syntax?

## Short Answer
In modern C#, the default pattern is an early guard clause, usually `ArgumentNullException.ThrowIfNull(argument)`. Use specialized helpers such as `ArgumentException.ThrowIfNullOrEmpty` for strings when the rule is about more than just `null`, and keep validation close to the public API boundary so failures are immediate and clear.

## Detailed Explanation
### Preferred modern pattern
The cleanest pattern is to fail fast at the start of a public method or constructor. That keeps invariants simple and avoids pushing `null` deeper into the call stack.

| Pattern | Best use case | Notes |
| --- | --- | --- |
| `ArgumentNullException.ThrowIfNull` | Any reference argument, `object?`, delegates, services | Standard, concise, no manual `nameof` needed |
| `ArgumentException.ThrowIfNullOrEmpty` | `string` that must not be `null` or empty | Expresses a stronger contract than null-only |
| `ArgumentException.ThrowIfNullOrWhiteSpace` | `string` that must contain non-whitespace text | Best for user input or identifiers |
| Custom guard method | Repeated domain-specific rules | Good when the rule has business meaning |

`ThrowIfNull` is preferred over handwritten `if (arg is null) throw ...` in most everyday code because it is shorter and standardized.

> Tip: validate at the boundary of the method that owns the contract. Internal private helpers often do not need repeated checks if the public entry point already enforced invariants.

See also [Nullable Analysis Attributes](./nullability-attributes.md) and [Nullable Reference Types](./nullable-reference-types.md).

### Guard clauses vs deep nesting
Guard clauses flatten control flow. Instead of wrapping the entire method body in nested `if` statements, you reject invalid input immediately and let the happy path stay readable.

```csharp
// Preferred shape
ArgumentNullException.ThrowIfNull(customer);
ArgumentException.ThrowIfNullOrWhiteSpace(orderId);
```

This style improves readability, helps analyzers, and makes intent obvious during code review.

### What about the `!!` syntax?
C# explored parameter null-check syntax such as `void Save(string name!!)`, but it was rejected and never became part of the language. In .NET 8/9 code, you should still use explicit guard clauses or helper methods.

That is actually a good outcome for many teams: explicit validation is easier to search for, easier to customize, and clearer when different arguments need different exception types or messages.

> Warning: do not confuse nullable annotations with validation. A parameter typed as `string` in nullable-enabled code still may receive `null` at runtime from older code, reflection, JSON binding, or external callers.

## Code Example
```csharp
using System;

var service = new ReportService();
Console.WriteLine(service.BuildReport("sales", "Q1"));

sealed class ReportService
{
    public string BuildReport(string reportName, string period)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(reportName); // Validates content, not just null.
        ArgumentException.ThrowIfNullOrWhiteSpace(period);

        return $"Report '{reportName}' for '{period}'";
    }

    public void Send(string recipientEmail, Action<string> sender)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(recipientEmail);
        ArgumentNullException.ThrowIfNull(sender); // Delegate must exist.

        sender($"Sending report to {recipientEmail}");
    }

    public void Save(Settings settings)
    {
        ArgumentNullException.ThrowIfNull(settings); // Fail fast at the API boundary.

        if (!settings.IsEnabled)
        {
            throw new ArgumentException("Settings must be enabled before saving.", nameof(settings));
        }

        Console.WriteLine("Saved.");
    }
}

sealed record Settings(bool IsEnabled);
```

## Common Follow-up Questions
- Why is `ThrowIfNull` usually better than writing `if (x is null)` manually?
- When should I throw `ArgumentException` instead of `ArgumentNullException`?
- Do I still need runtime null validation if nullable reference types are enabled?
- Should private methods repeat the same null checks as public methods?
- When is a custom guard helper a better choice than the built-in throw helpers?

## Common Mistakes / Pitfalls
- Relying on nullable annotations alone and skipping runtime validation at public boundaries.
- Throwing `NullReferenceException` manually instead of `ArgumentNullException` or `ArgumentException`.
- Using `ThrowIfNull` for a string when the real rule is “not null or whitespace.”
- Duplicating the same guards across every private helper even though the public entry point already validated input.
- Assuming the rejected `!!` syntax is available in current C# versions.

## References
- [Microsoft Docs: ArgumentNullException.ThrowIfNull](https://learn.microsoft.com/dotnet/api/system.argumentnullexception.throwifnull)
- [Microsoft Docs: ArgumentException.ThrowIfNullOrEmpty](https://learn.microsoft.com/dotnet/api/system.argumentexception.throwifnullorempty)
- [Microsoft Docs: Nullable reference types](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/nullable-reference-types)
- [See: Nullable Analysis Attributes](./nullability-attributes.md)
- [See: Null-Forgiving Operator](./null-forgiving-operator.md)
