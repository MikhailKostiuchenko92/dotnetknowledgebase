# Required Members

**Category:** C# / Modern C# Features
**Difficulty:** Middle
**Tags:** `required`, `SetsRequiredMembers`, `init`, `records`, `object-initializers`

## Question

> What does the `required` keyword do in C#, and how does it work with object initializers, records, and constructors?

Also asked as:
- "How is `required` different from `init`?"
- "When do you need `SetsRequiredMembers`?"
- "Do required members work well with records and DTO-style models?"

## Short Answer

The `required` modifier tells the compiler that callers must initialize a member during object creation unless a constructor marked with `SetsRequiredMembers` guarantees that requirement is satisfied. It works especially well with `init` properties and records because you can keep object-initializer ergonomics while making critical members mandatory. In .NET 8/9 it is a compile-time API design feature, not a runtime validation substitute.

## Detailed Explanation

### `required` solves completeness, not immutability

A common interview trap is mixing up `required` and `init`.

- `required` means the caller must provide a value during construction.
- `init` means the value can only be assigned during initialization.

They often appear together because many models need both guarantees.

| Feature | Main purpose | Typical pairing |
|---|---|---|
| `required` | Force initialization | `init`, constructors |
| `init` | Restrict later mutation | `required`, records |
| `SetsRequiredMembers` | Tell the compiler a constructor fulfills requirements | Custom constructors |

### Object initializers and records

`required` shines with DTOs, options objects, and records because it preserves readable object initializer syntax without allowing important members to be forgotten. Positional records already cover some initialization needs through their primary constructor, but required properties are still useful for additional metadata or non-positional members.

This is closely related to [init-only-properties.md](./init-only-properties.md) and [primary-constructors.md](./primary-constructors.md).

### `SetsRequiredMembers`

Sometimes a constructor fully initializes all required members internally. In that case, mark it with `[SetsRequiredMembers]` so the compiler does not force callers to repeat that work.

The key nuance is that the attribute is a promise from the constructor author to the compiler. The compiler does not deeply verify that you actually set every required member inside the constructor.

> **Warning:** `SetsRequiredMembers` is easy to misuse. If you apply it but forget to initialize one of the required members, callers lose compiler protection and the object can still be incomplete.

### Good use cases

Good fits:
- API request/response contracts
- configuration or options models
- immutable records and value-like DTOs
- domain models where several members are mandatory but constructor overloads would be noisy

Less ideal fits:
- types with complex validation requiring a single constructor path
- mutable entities where required-at-creation does not express the true lifecycle constraints

### Runtime reality

`required` is mostly compile-time guidance. Reflection-based materialization, some serializers, and manual low-level activation paths can bypass it. That means you should still validate invariants if the object must never exist in an invalid state.

Think of `required` as improving API correctness and caller ergonomics, not replacing constructors or validation logic.

## Code Example

```csharp
using System;
using System.Diagnostics.CodeAnalysis;

namespace Demo;

var request = new CreateUserRequest
{
    Email = "mikhail@example.com",
    DisplayName = "Mikhail"
};

var admin = new Employee("owner@example.com", "Platform");

Console.WriteLine(request);
Console.WriteLine($"{admin.Email} / {admin.Department}");

public record CreateUserRequest
{
    public required string Email { get; init; }
    public required string DisplayName { get; init; }
}

public sealed class Employee
{
    [SetsRequiredMembers]
    public Employee(string email, string department)
    {
        Email = email;      // Constructor fulfills required members.
        Department = department;
    }

    public required string Email { get; init; }
    public required string Department { get; init; }
}
```

## Common Follow-up Questions

- Why do `required` and `init` solve different problems even though they are often used together?
- What promise does `SetsRequiredMembers` make to the compiler?
- Why can `required` still be bypassed by reflection or some serializers?
- When is a normal constructor better than a required-property-based API?
- How do required members interact with positional records or primary constructors?

## Common Mistakes / Pitfalls

- Treating `required` as runtime validation instead of compile-time guidance.
- Using `SetsRequiredMembers` on a constructor that does not actually set every required member.
- Assuming `required` automatically implies immutability without `init` or other restrictions.
- Adding too many required properties when a focused constructor would communicate the model better.
- Forgetting to validate invariants that must hold even when objects are created through reflection or serialization.

## References

- [required modifier - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/required)
- [SetsRequiredMembersAttribute Class](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.setsrequiredmembersattribute)
- [init - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/init)
- [See: init-only-properties.md](./init-only-properties.md)
- [See: primary-constructors.md](./primary-constructors.md)
