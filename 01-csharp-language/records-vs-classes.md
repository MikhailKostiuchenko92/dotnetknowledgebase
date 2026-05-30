# Records vs Classes

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `record`, `class`, `value-equality`, `with`, `dto`

## Question

> What is the difference between a record and a class in C#, and when should you choose one over the other?

Also asked as:
- "Why were records added if C# already had classes?"
- "What do records generate for you automatically?"
- "Are records always immutable, and are they better for DTOs and value objects?"

## Short Answer

A record is a reference type by default, just like a class, but it is optimized for data-centric modeling with compiler-generated value-based equality, friendly printing, deconstruction, and support for non-destructive mutation with `with`. A normal class is usually a better fit for identity-rich, behavior-heavy entities whose equality should not be based on all data members. Records are especially useful for DTOs, messages, and value objects, but they are not automatically the right answer for every domain type.

## Detailed Explanation

### The Core Semantic Difference

The biggest difference is not memory layout; both `record class` and `class` are reference types. The real difference is the default *semantic model*.

A normal class typically uses reference identity unless you manually override equality members. A record class comes with compiler-generated members that support value equality based on its declared data.

| Aspect | `class` | `record class` |
|---|---|---|
| Default equality | Reference equality | Value equality |
| `ToString()` | Inherited unless overridden | Generated member listing |
| `with` expression | Not built in | Built in |
| Typical use | Entities, services, behavior-rich types | DTOs, messages, value objects |

### Compiler-Generated Members

For records, the compiler can generate:

- value-based `Equals`
- `GetHashCode`
- `==` / `!=`
- `Deconstruct`
- printable `ToString()`
- support for `with` expressions

That makes records concise for data carriers. In interviews, this is usually the key point: records reduce boilerplate around data-oriented types.

### Value Equality vs Identity

If two `PersonDto` records contain the same values, they compare equal even if they are different object references. That is convenient for API contracts, immutable commands, options snapshots, and value objects.

By contrast, an ORM entity or aggregate root often should not compare equal solely because all current properties match. Identity usually comes from an `Id`, lifecycle, or persistence boundary. In those cases, a normal class is often clearer.

> **Tip:** Records shine when the *data* is the identity. Classes shine when the *object instance or lifecycle* is the identity.

### Immutability and `with`

Records encourage immutability, especially positional record classes with `init` properties, but records are not magically immutable. You can still define mutable members.

The `with` expression performs non-destructive mutation by cloning the object and changing selected members. That is very convenient for state transitions in application code.

See [init-only-properties.md](./init-only-properties.md) and [record-struct-vs-record-class.md](./record-struct-vs-record-class.md).

### DTOs and Value Objects

Common good fits for records:

- API request/response DTOs
- domain value objects
- message contracts
- projection results
- configuration snapshots

Common bad fits:

- EF Core entities with complex identity/lifecycle semantics
- large mutable stateful objects
- service classes with behavior and dependencies

### Records Are Not "Better Classes"

Records are a specialized language feature, not a universal upgrade. If your model is behavior-first or identity-first, a class is still the normal choice.

This topic also connects to [class-vs-struct.md](./class-vs-struct.md) and [value-types-vs-reference-types.md](./value-types-vs-reference-types.md).

## Code Example

```csharp
using System;

var dto1 = new PersonDto("Mikhail", 32);
var dto2 = new PersonDto("Mikhail", 32);
Console.WriteLine(dto1 == dto2); // True: value equality.

var updated = dto1 with { Age = 33 };
Console.WriteLine(updated); // PersonDto { Name = Mikhail, Age = 33 }

var entity1 = new PersonEntity("Mikhail", 32);
var entity2 = new PersonEntity("Mikhail", 32);
Console.WriteLine(entity1 == entity2); // False: reference equality.

public record PersonDto(string Name, int Age);

public class PersonEntity
{
    public PersonEntity(string name, int age)
    {
        Name = name;
        Age = age;
    }

    public string Name { get; }
    public int Age { get; private set; }
}
```

## Common Follow-up Questions

- Are records reference types or value types by default?
- What members does the compiler generate for a record?
- Why can records be a poor fit for ORM entities?
- Are records always immutable, or is that only the common style?
- How does `with` work on record classes versus record structs?

## Common Mistakes / Pitfalls

- Assuming a record is a value type just because it uses value equality.
- Using records for identity-rich entities where lifecycle matters more than current property values.
- Forgetting that mutable properties on a record weaken the safety of value-based hashing and equality.
- Treating `with` as a deep clone; it is usually a shallow copy of the object's fields.
- Assuming all serializers or frameworks treat records identically to classic classes without checking constructor/binding behavior.

## References

- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [record - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
- [See: init-only-properties.md](./init-only-properties.md)
- [See: record-struct-vs-record-class.md](./record-struct-vs-record-class.md)
- [See: class-vs-struct.md](./class-vs-struct.md)
