# Primitive Obsession

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `primitive-obsession`, `value-object`, `type-safety`, `refactoring`

## Question
> What is primitive obsession, and how do value objects help replace raw strings, numbers, and IDs with safer domain concepts?

## Short Answer
Primitive obsession means modeling important domain concepts with raw primitives like `string`, `int`, or `decimal` everywhere. That seems simple at first, but it spreads validation rules, weakens type safety, and makes invalid states easier to create. A common fix is introducing value objects such as `EmailAddress`, `Money`, or `CustomerId` so the type system carries more domain meaning.

## Detailed Explanation
### What the smell looks like
Primitive obsession shows up when many parameters or properties technically compile but communicate almost nothing about business meaning. If a method takes three strings, are they an email, a country code, and an order ID, or something else? The compiler cannot help much because every string is interchangeable.

| Primitive-based design | Value-object design |
| --- | --- |
| `string email` | `EmailAddress email` |
| `decimal amount` | `Money amount` |
| `string customerId` | `CustomerId customerId` |

The problem is not that primitives are bad. The problem is using them for concepts that have rules, identity, formatting, and invariants of their own. Once that happens, validation logic gets duplicated across controllers, services, and repositories.

### Why value objects help
A value object wraps a primitive or a small set of primitives and enforces rules in one place. For example, an `EmailAddress` type can normalize casing, reject obviously invalid input, and prevent accidental mix-ups with unrelated strings. A `Money` type can keep currency and amount together so you do not accidentally add euros to dollars.

This improves type safety and readability. A method signature with value objects tells you the domain language directly, not just the storage representation. It also centralizes rules so they are not re-implemented inconsistently throughout the codebase.

> Warning: introducing value objects blindly can become over-engineering. Wrap concepts that carry real rules or meaning, not every single integer in the system.

### How to refactor safely
A common path is to start where bugs already happen: IDs getting mixed up, email validation duplicated, or money calculations using naked decimals. Replace one primitive at a time and let the new type expose obvious operations. In modern C#, `record struct` or `readonly record struct` is often a good fit for lightweight immutable value objects.

A useful interview point is that value objects are not just “nicer types.” They change where rules live. Instead of every caller remembering how to validate or compare the value, the type itself owns that logic.

### Trade-offs and when not to overdo it
Value objects add some ceremony. Serialization, EF Core mapping, and model binding may need configuration. Teams that do not share the design intent may also create inconsistent wrappers. But when the domain meaning matters, the benefits usually outweigh the cost: fewer invalid combinations, clearer APIs, and code that reads in business terms rather than storage terms.

The balanced answer is that primitive obsession is a smell when primitives erase domain meaning. Value objects fix that by making important concepts explicit and validated at the type level.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        var email = EmailAddress.Create(" Person@Example.com ");
        var price = new Money(120m, "USD");

        Console.WriteLine(email.Value);
        Console.WriteLine(price);
    }
}

internal readonly record struct EmailAddress
{
    public string Value { get; }

    private EmailAddress(string value) => Value = value;

    public static EmailAddress Create(string input)
    {
        string normalized = input.Trim().ToLowerInvariant();

        if (!normalized.Contains('@'))
        {
            throw new ArgumentException("Invalid email address.", nameof(input));
        }

        return new EmailAddress(normalized); // Validation lives in one place.
    }
}

internal readonly record struct Money(decimal Amount, string Currency)
{
    public override string ToString() => $"{Amount:0.00} {Currency}";
}
```

## Common Follow-up Questions
- How do value objects differ from entities?
- Which domain concepts are worth wrapping first?
- What is the cost of using value objects with EF Core or Web APIs?
- Can primitive obsession exist even in strongly typed languages like C#?
- When does wrapping primitives become unnecessary complexity?

## Common Mistakes / Pitfalls
- Wrapping trivial values with no rules just to look “DDD-friendly.”
- Creating value objects but still exposing raw mutable primitives everywhere else.
- Forgetting normalization rules, so logically equal values compare as different.
- Using primitives in method signatures and value objects only in persistence models.
- Treating a value object like an entity and giving it identity-based behavior.

## References
- [Primitive Obsession](https://refactoring.guru/smells/primitive-obsession)
- [Value objects](https://martinfowler.com/bliki/ValueObject.html)
- [C# record types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
- [Implement value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
