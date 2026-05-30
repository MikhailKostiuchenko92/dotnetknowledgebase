# What is Primitive Obsession?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `primitive-obsession`, `value-object`, `type-safety`, `refactoring`

## Question
> What is primitive obsession, why is it dangerous, and how would you refactor it in C#?

## Short Answer
Primitive obsession means using raw strings, integers, decimals, and booleans for domain concepts that deserve their own types. It looks simple at first, but it weakens validation, makes invalid states easy to represent, and spreads the same rules across the codebase. A common fix is to introduce value objects so the domain becomes more explicit and type-safe.

## Detailed Explanation
### What it is
Primitive obsession happens when domain concepts are modeled as basic language types instead of meaningful abstractions. Examples include using `string` for email addresses, `decimal` for money, `int` for customer IDs, or `bool` flags to represent workflow states. The code compiles, but the model stops communicating intent.

The core problem is not that primitives are bad. The problem is that **the business meaning disappears**. If a method takes three `string` values, the compiler cannot tell whether they are an email, a country code, and a ZIP code or three unrelated pieces of text.

| Primitive-based design | Value-object design |
| --- | --- |
| Rules are repeated in many places | Rules are centralized in one type |
| Parameters are ambiguous | Types document intent |
| Invalid combinations compile easily | Type mismatches fail earlier |
| Refactoring is harder | Domain language becomes clearer |

### Why it becomes dangerous
Primitive obsession usually leads to duplicated validation. One controller trims emails, another service checks them with a regex, and a background job forgets validation entirely. Now the same concept behaves differently depending on who created it.

It also creates subtle bugs. Passing a gross amount where a net amount was expected, or swapping `billingEmail` and `shippingEmail`, will still compile if both are strings. The compiler loses the ability to help you.

> Warning: primitive obsession is especially risky in distributed systems and APIs because invalid or inconsistent data can travel far before anyone notices the bug.

### Why value objects are the usual fix
In DDD terms, a **value object** models a concept defined by its value rather than identity. `EmailAddress`, `Money`, `Percentage`, or `CustomerId` are good candidates. A value object can validate itself on creation, enforce formatting rules, and expose intention-revealing behavior.

C# makes this pleasant with `record` and `record struct`. For lightweight immutable concepts, a `readonly record struct` often works well. It gives value semantics while keeping the code concise.

### Trade-offs and when not to overdo it
Introducing value objects has costs. Serialization, EF Core mapping, and JSON converters can become a little more involved. Over-modeling every primitive can also create noise. A loop counter does not need to become `IterationIndex`.

A good interview answer shows balance: use value objects for domain concepts with business rules, invariants, formatting, or high semantic importance. Do not wrap primitives just to satisfy a pattern.

### Incremental refactoring approach
A safe path is to start with the most error-prone primitive, such as `EmailAddress` or `Money`. Replace it at API boundaries, then move inward. Once one concept becomes explicit, many downstream signatures become clearer automatically. That is the real benefit: not more types, but **better domain communication and safer code**.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

using System.Globalization;

internal static class Program
{
    private static void Main()
    {
        // Bad: nothing stops callers from swapping or mis-formatting these primitives.
        Console.WriteLine(BadRegistrationService.Register("not-an-email", "100.50"));

        // Refactored: value objects make intent explicit and validate early.
        var email = new EmailAddress("ada@example.com");
        var credit = Money.FromString("100.50");
        Console.WriteLine(GoodRegistrationService.Register(email, credit));
    }
}

internal static class BadRegistrationService
{
    public static string Register(string email, string creditLimit)
    {
        // Bad: validation and parsing happen far away from the concept itself.
        return $"Registered {email} with limit {creditLimit}";
    }
}

internal static class GoodRegistrationService
{
    public static string Register(EmailAddress email, Money creditLimit)
    {
        // Good: invalid values are rejected before this method is called.
        return $"Registered {email.Value} with limit {creditLimit.Amount:C}";
    }
}

internal readonly record struct EmailAddress
{
    public string Value { get; }

    public EmailAddress(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || !value.Contains('@'))
        {
            throw new ArgumentException("Email address is invalid.", nameof(value));
        }

        Value = value.Trim();
    }
}

internal readonly record struct Money(decimal Amount)
{
    public static Money FromString(string value)
    {
        if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal amount) || amount < 0)
        {
            throw new ArgumentException("Money value is invalid.", nameof(value));
        }

        return new Money(amount);
    }
}
```

## Common Follow-up Questions
- What makes a value object different from an entity?
- Which domain concepts are the best candidates for value objects?
- How would you map value objects with EF Core?
- When does wrapping primitives become over-engineering?
- How can primitive obsession lead to production bugs even when the code compiles?

## Common Mistakes / Pitfalls
- Replacing every primitive in the codebase, including trivial technical values with no domain meaning.
- Creating wrapper types that add no validation or behavior, so the design becomes noisier without benefits.
- Leaving public constructors too permissive, which still allows invalid states.
- Forgetting about serialization, EF Core configuration, or JSON converters when introducing value objects.
- Using mutable value objects, which weakens predictability and equality semantics.

## References
- [Primitive Obsession](https://refactoring.guru/smells/primitive-obsession)
- [Records in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [Implementing value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [Value Object](https://martinfowler.com/eaaCatalog/valueObject.html)
