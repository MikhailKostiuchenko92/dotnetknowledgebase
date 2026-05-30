# Constructor Chaining and Static Constructors

**Category:** C# / OOP in C#
**Difficulty:** Middle
**Tags:** `constructors`, `this`, `base`, `static-constructor`, `beforefieldinit`, `type-initialization`

## Question

> How do constructor chaining and static constructors work in C#?

Also asked as:
- "What is the difference between `: this(...)` and `: base(...)`?"
- "When does a static constructor run?"
- "What is `beforefieldinit`, and why does it matter for type initialization timing?"

## Short Answer

Constructor chaining with `this(...)` lets one instance constructor reuse another constructor in the same type, while `base(...)` delegates to a base-class constructor. A static constructor initializes type-level state once, automatically, before first use of the type. If a type has no explicit static constructor, the runtime gets more freedom under `beforefieldinit` to initialize it earlier, so you should not write code that depends on overly precise timing.

## Detailed Explanation

### `this(...)` vs `base(...)`

`this(...)` calls another constructor in the same type. It is commonly used to centralize validation and keep initialization logic in one place.

`base(...)` calls a constructor on the base class. It is how a derived type ensures the base portion of the object is initialized correctly.

| Syntax | Target | Typical purpose |
|---|---|---|
| `: this(...)` | Another constructor in the same type | Reuse and reduce duplication |
| `: base(...)` | A constructor in the base type | Initialize inherited state |

The two cannot be used together on the same constructor, because a constructor initializer can target only one constructor.

### Initialization Order

For instance construction, the flow is roughly:

1. most-derived constructor is selected
2. its constructor initializer runs (`this` or `base`)
3. base-class initialization happens before derived constructor body
4. constructor bodies execute from base to derived

That ordering matters when fields, properties, and virtual calls are involved.

> **Warning:** Avoid calling overridable members from constructors. The derived object may not be fully initialized yet. This is closely related to [virtual-override-new-keywords.md](./virtual-override-new-keywords.md).

### Static Constructors

A static constructor has no parameters and no access modifier. It runs automatically once per type, and the runtime guarantees thread-safe execution.

Typical use cases:

- initialize complex static fields
- validate environment assumptions
- wire up type-level caches

If a static constructor throws, the type becomes unusable for that process and later access typically throws `TypeInitializationException`.

### `beforefieldinit`

If a type does not declare an explicit static constructor, the CLR may mark it with `beforefieldinit`. That gives the runtime flexibility to initialize static fields any time before the first static field access or instance creation that requires the type.

If you do declare an explicit static constructor, initialization timing becomes stricter: the runtime must run it immediately before first use.

Interview-safe summary: **with no explicit static constructor, initialization can happen earlier than you expect; with an explicit one, timing is more precise but still controlled by the runtime.**

### Thread Safety and Design Guidance

Static constructor execution is thread-safe by CLR contract, so you do not need to lock inside it just to protect one-time execution. But if you perform heavy work or blocking I/O there, you can delay first-use latency and make failures harder to diagnose.

Prefer simple static initialization or `Lazy<T>` when appropriate. For instance constructors, prefer chaining so that validation and required initialization live in one place.

See also [static-classes-and-members.md](./static-classes-and-members.md) and [static-members-in-generic-types.md](./static-members-in-generic-types.md).

## Code Example

```csharp
using System;

var admin = new AdminUser("mikhail@example.com", "Owner");
Console.WriteLine($"{admin.Email} / {admin.Role}");
Console.WriteLine(Configuration.InstanceId); // Triggers static initialization once.

public class User
{
    public User() : this("unknown@example.com") { }

    public User(string email)
    {
        Email = email;
    }

    public string Email { get; }
}

public class AdminUser : User
{
    public AdminUser(string email, string role) : base(email) // Calls base constructor.
    {
        Role = role;
    }

    public string Role { get; }
}

public static class Configuration
{
    static Configuration() // Runs once, automatically, before first use.
    {
        InstanceId = Guid.NewGuid();
    }

    public static Guid InstanceId { get; }
}
```

## Common Follow-up Questions

- Why can a constructor use either `this(...)` or `base(...)`, but not both?
- What problems can happen if you call virtual members from a constructor?
- How does `beforefieldinit` change static initialization timing?
- What happens when a static constructor throws an exception?
- When would `Lazy<T>` be preferable to a heavy static constructor?

## Common Mistakes / Pitfalls

- Duplicating validation logic across constructors instead of chaining with `this(...)`.
- Assuming static constructors run at application startup rather than on first type use.
- Performing expensive or failure-prone work in a static constructor.
- Relying on exact initialization timing when the type is eligible for `beforefieldinit`.
- Calling overridable members during construction before derived state exists.

## References

- [Instance constructors - C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/constructors)
- [Static Constructors (C# Programming Guide)](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-constructors)
- [See: static-classes-and-members.md](./static-classes-and-members.md)
- [See: virtual-override-new-keywords.md](./virtual-override-new-keywords.md)
- [Jon Skeet - C# and beforefieldinit](https://csharpindepth.com/articles/BeforeFieldInit)
