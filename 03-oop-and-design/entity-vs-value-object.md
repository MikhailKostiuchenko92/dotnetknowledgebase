# Entity vs Value Object

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟢 Junior
**Tags:** `DDD`, `entity`, `value-object`, `records`, `equality`

## Question
> In Domain-Driven Design, what is the difference between an entity and a value object, and how do C# records fit into value objects?

## Short Answer
An entity is defined mainly by identity, so it stays the “same thing” even when some of its data changes. A value object is defined by its attributes, so two instances with the same values are considered equal. In C#, records are often a good fit for value objects because they provide value-based equality and encourage immutability by default.

## Detailed Explanation
### What makes an entity an entity
In DDD, an entity has a stable identity that matters to the business. A `Customer`, `Order`, or `Invoice` may change state over time, but the business still treats it as the same conceptual thing. That is why equality for entities is usually identity-based, often using a database key, business key, or strongly typed ID.

The key point is that the current field values do not fully define the entity. Two `Order` objects with the same total and status are not necessarily the same order. They are the same only if they share the same identity.

### What makes a value object a value object
A value object has no conceptual identity. It is defined entirely by what it contains. Examples include `Money`, `Address`, `DateRange`, `GeoPoint`, or `EmailAddress`. If two `Money` objects both represent `10 USD`, the business usually treats them as equal regardless of when or where they were created.

Because value objects are compared by structure, they should usually be immutable. If a value changes, you typically create a new instance rather than mutating the existing one. That makes behavior safer and avoids confusing bugs in collections, caching, and concurrency.

| Characteristic | Entity | Value Object |
| --- | --- | --- |
| Identity | Required | None |
| Equality | Identity-based | Structural/value-based |
| Mutability | Often mutable over time | Prefer immutable |
| Lifecycle tracking | Important | Usually not important |
| Examples | Order, Customer, Product | Money, Address, EmailAddress |

### Why the distinction matters
This distinction affects design, persistence, and bugs. If you model a value object as an entity, you create unnecessary IDs, extra lifecycle management, and more accidental complexity. If you model an entity as a value object, you can accidentally merge distinct business objects just because their current data looks the same.

For example, two customers with the same name and email are still different customers. But two `Currency("USD")` objects are usually the same value.

### How C# records help
C# records are designed for value-like data. They automatically generate `Equals`, `GetHashCode`, and `==` semantics based on contained values. That makes them a natural fit for many value objects, especially immutable ones.

However, “record” and “value object” are not exact synonyms. A record is just a language feature. A value object is a modeling decision. You still need validation and domain meaning. An `Address` record with invalid state is still a bad value object.

> Warning: do not use records blindly for entities. Record equality is value-based by default, which often conflicts with entity identity semantics.

### Trade-offs and when not to use records
Records reduce boilerplate, but you may prefer a regular class when you need custom construction rules, stronger encapsulation, or fine-grained control over equality. Also, some value objects wrap collections; in that case, equality semantics may require extra care because collection references and structural comparison are not always the same thing.

For entities, regular classes are usually clearer because they make identity and lifecycle explicit. For value objects, records are often ideal, but only when their generated behavior matches your domain intent.

### Practical interview rule of thumb
If the business asks, “Which exact thing is this?” you are probably dealing with an entity. If it asks, “What value does this represent?” you are probably dealing with a value object.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed class Order
{
    public Order(Guid id, decimal total)
    {
        Id = id;
        Total = total;
    }

    public Guid Id { get; }
    public decimal Total { get; private set; }

    public void ChangeTotal(decimal newTotal) => Total = newTotal;

    public override bool Equals(object? obj)
        => obj is Order other && Id == other.Id; // Entity equality by identity.

    public override int GetHashCode() => Id.GetHashCode();
}

public sealed record Money(decimal Amount, string Currency); // Value object by structure.

public static class Program
{
    public static void Main()
    {
        var order1 = new Order(Guid.Parse("11111111-1111-1111-1111-111111111111"), 100m);
        var order2 = new Order(Guid.Parse("11111111-1111-1111-1111-111111111111"), 150m);

        Console.WriteLine(order1.Equals(order2)); // True: same identity.

        var price1 = new Money(10m, "USD");
        var price2 = new Money(10m, "USD");

        Console.WriteLine(price1 == price2); // True: same value.
    }
}
```

## Common Follow-up Questions
- Why are value objects usually immutable?
- Can an entity contain value objects inside it?
- When would you avoid using a record for a value object?
- How should equality be implemented for an entity in C#?
- What bugs happen if you give a value object its own identity?

## Common Mistakes / Pitfalls
- Comparing entities by all properties instead of by identity.
- Giving value objects surrogate IDs just because the database table has a key.
- Using mutable value objects and then placing them in hash-based collections.
- Assuming every record is automatically a good domain value object without validation.
- Modeling entity state changes as “new objects” when the business actually cares about continuity of identity.

## References
- [Domain model layer - entities and value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-model-layer-validations)
- [Introduction to record types in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
- [Choosing between class, struct, and record](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/choosing-between-class-record-struct)
- [Value Object](https://martinfowler.com/bliki/ValueObject.html)
