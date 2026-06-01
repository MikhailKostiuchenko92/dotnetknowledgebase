# Value Object Implementation

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `value-object`, `IEquatable`, `records`, `validation`

## Question
> How do you implement value objects correctly in C#, including equality, operator overloading, validation, collection wrapping, and when to use records?

## Short Answer
A value object should be immutable, validated at creation time, and compared by its contained values rather than by identity. In C#, you can implement that with a record, or with a class that implements `IEquatable<T>` and consistent `Equals`, `GetHashCode`, and operators. When a value object wraps collections or more complex data, you often need custom equality and defensive copying to keep it truly safe.

## Detailed Explanation
### Core implementation goals
A value object models a concept like `Money`, `EmailAddress`, `DateRange`, or `Address`. The implementation should reflect the DDD idea: no identity, structural equality, and protection against invalid state. In practice, that means immutability, constructor or factory validation, and carefully defined equality semantics.

If your value object can exist in an invalid state, or if it mutates after being used as a dictionary key or set member, subtle bugs appear quickly.

### `IEquatable<T>`, `Equals`, and operators
For a class-based value object, the standard pattern is to implement `IEquatable<T>`, override `Equals(object?)`, and override `GetHashCode()`. If you define `==` and `!=`, they must behave consistently with `Equals`.

This matters for collections, LINQ distinct operations, and dictionary keys. Equality logic must include exactly the components that define the value.

| Technique | Pros | Cons | Good fit |
| --- | --- | --- | --- |
| C# record | Minimal boilerplate, built-in value equality | Less control by default | Simple immutable value objects |
| Custom class + `IEquatable<T>` | Full control, explicit semantics | More code | Complex equality or validation |
| `record struct` | Allocation-friendly for tiny values | Copy semantics need care | Small, truly value-like types |

### Records as value objects
Records are often the first choice in modern C#. They provide value-based equality and support concise immutable modeling. They are a strong fit when the generated equality matches your domain semantics.

However, records are not magic. You still need validation, normalization, and sometimes custom members. For example, an email address value object may need to trim whitespace, normalize casing rules carefully, and reject invalid formats.

### Validation and collection wrapping
Validation should happen at creation time so invalid instances never exist. You can use a constructor, a static factory, or a `TryCreate` method depending on your error-handling style. Domain-specific validation belongs here, not scattered across consumers.

Collection-valued value objects require extra care. If a value object exposes a mutable list, callers can change its state after construction, which breaks immutability and may break equality. The usual fix is defensive copying plus an immutable or read-only representation. Equality for collections should then be structural and based on domain meaning, not reference identity.

> Warning: a record that contains a mutable collection is not automatically a safe value object. You still need to control mutation and define the right collection equality semantics.

### Trade-offs and when not to overcomplicate
Not every small concept needs a custom base class or operator overloads. Sometimes a record with a validated factory is enough. But for important concepts like money, date ranges, units, identifiers, or contact info, a proper value object prevents primitive obsession and centralizes rules.

The right implementation level depends on domain importance, not on a generic style rule.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;

namespace DomainDrivenDesignSamples;

public sealed class Money : IEquatable<Money>
{
    public Money(decimal amount, string currency)
    {
        if (amount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount cannot be negative.");
        }

        if (string.IsNullOrWhiteSpace(currency))
        {
            throw new ArgumentException("Currency is required.", nameof(currency));
        }

        Amount = amount;
        Currency = currency.ToUpperInvariant(); // Normalize during creation.
    }

    public decimal Amount { get; }
    public string Currency { get; }

    public bool Equals(Money? other)
        => other is not null && Amount == other.Amount && Currency == other.Currency;

    public override bool Equals(object? obj) => Equals(obj as Money);
    public override int GetHashCode() => HashCode.Combine(Amount, Currency);

    public static Money operator +(Money left, Money right)
    {
        if (left.Currency != right.Currency)
        {
            throw new InvalidOperationException("Currencies must match.");
        }

        return new Money(left.Amount + right.Amount, left.Currency);
    }

    public static bool operator ==(Money? left, Money? right) => Equals(left, right);
    public static bool operator !=(Money? left, Money? right) => !Equals(left, right);
}

public sealed record Tags
{
    public Tags(IEnumerable<string> values)
    {
        Values = values
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim().ToUpperInvariant())
            .Distinct()
            .ToImmutableArray(); // Defensive copy plus immutable storage.
    }

    public ImmutableArray<string> Values { get; }
}

public static class Program
{
    public static void Main()
    {
        var total = new Money(10m, "usd") + new Money(5m, "USD");
        var tags = new Tags(["new", "sale", "sale"]);

        Console.WriteLine(total == new Money(15m, "USD")); // Structural equality.
        Console.WriteLine(string.Join(", ", tags.Values));
    }
}
```

## Common Follow-up Questions
- When would you choose a record over a custom class for a value object?
- Why is immutability especially important for value objects?
- How do you implement equality when the value object contains a collection?
- Should value objects throw in constructors or use `TryCreate`?
- When would `record struct` be a reasonable choice?

## Common Mistakes / Pitfalls
- Exposing mutable properties or lists from a value object.
- Forgetting to normalize or validate values at creation time.
- Overloading operators without keeping them consistent with equality semantics.
- Assuming records automatically solve collection equality.
- Including fields in equality that the business does not actually consider part of the value.

## References
- [Implement value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [C# record types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
- [IEquatable<T> Interface](https://learn.microsoft.com/en-us/dotnet/api/system.iequatable-1)
- [How to define value equality for a type](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/statements-expressions-operators/how-to-define-value-equality-for-a-type)
