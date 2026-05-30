# Reflection Basics

**Category:** C# / Reflection
**Difficulty:** Middle
**Tags:** `reflection`, `type`, `methodinfo`, `aot`

## Question
> What is reflection in .NET, and how do `Type`, `MethodInfo`, `PropertyInfo`, and `Activator.CreateInstance` fit together?
>
> How do you inspect and invoke members dynamically, and what performance trade-offs come with reflection?
>
> What changes should you keep in mind for Native AOT and trimming in .NET 8/9?

## Short Answer
Reflection lets code inspect types and members at runtime and optionally create instances or invoke members dynamically. It is powerful for frameworks, tooling, and metadata-driven behavior, but it is slower than direct code, benefits from caching, and needs extra care in trimmed or Native AOT scenarios where metadata may be removed.

## Detailed Explanation
### Core building blocks
Reflection starts with `Type`, then moves to member metadata such as `MethodInfo`, `PropertyInfo`, `FieldInfo`, and constructors.

| API | Purpose | Example use |
| --- | --- | --- |
| `Type` | Represents a runtime type | Discover members, generic arguments, base type |
| `MethodInfo` | Describes a method | Invoke or inspect parameters and return type |
| `PropertyInfo` | Describes a property | Read or write values dynamically |
| `Activator.CreateInstance` | Create an object from a `Type` | Plugin activation, generic factory fallback |

This is the foundation behind serializers, dependency injection containers, ORMs, and test frameworks.

> Tip: in interviews, separate “reading metadata” from “invoking behavior.” Reflection can do both, but invocation is usually where more cost and risk appear.

See also [Custom Attributes](./custom-attributes.md).

### Performance and caching
Reflection is not free. Looking up members repeatedly by name and invoking them dynamically is far slower than direct calls.

| Technique | Relative cost | Recommendation |
| --- | --- | --- |
| Direct call | Lowest | Prefer in hot paths |
| Cached delegate or compiled expression | Low to medium | Good optimization when dynamic behavior is needed repeatedly |
| Repeated raw reflection lookup + invoke | Highest | Avoid in tight loops |

In real systems, the standard advice is:
- Discover once
- Cache metadata or delegates
- Reuse the cached result

### AOT and trimming concerns
In .NET 8/9, trimming and Native AOT make reflection design more important. If code discovers members only by name at runtime, the linker may remove metadata or members that appear unused.

Typical mitigations include:
- Using source generators when possible
- Adding trimming annotations or linker configuration when reflection is necessary
- Avoiding “magic string” reflection in libraries intended for AOT scenarios

> Warning: reflection-heavy designs that work in CoreCLR can fail under Native AOT if required metadata is trimmed away. This is now a practical architecture concern, not just a theoretical one.

## Code Example
```csharp
using System;
using System.Reflection;

var type = typeof(User);
Console.WriteLine(type.Name);

object? instance = Activator.CreateInstance(type); // Uses the parameterless constructor.
var property = type.GetProperty(nameof(User.Name));
var method = type.GetMethod(nameof(User.Describe));

property!.SetValue(instance, "Mikhail"); // Reflection read/write on a property.
var result = method!.Invoke(instance, null);

Console.WriteLine(result);

sealed class User
{
    public string Name { get; set; } = "Unknown";

    public string Describe()
    {
        return $"User: {Name}";
    }
}
```

## Common Follow-up Questions
- When is reflection appropriate, and when is it a bad fit?
- Why should reflection metadata or delegates usually be cached?
- What is the difference between inspecting metadata and invoking members dynamically?
- Why can reflection be problematic with trimming or Native AOT?
- When should source generation be preferred over reflection?

## Common Mistakes / Pitfalls
- Using reflection repeatedly in hot paths without caching.
- Assuming member names discovered by strings are safe in trimmed or AOT builds.
- Forgetting null checks when `GetMethod` or `GetProperty` may not find a member.
- Treating `Activator.CreateInstance` as if it were as cheap as `new`.
- Reaching for reflection when a generic constraint, interface, or delegate would be simpler.

## References
- [Microsoft Docs: Reflection and attributes](https://learn.microsoft.com/dotnet/csharp/advanced-topics/reflection-and-attributes/)
- [Microsoft Docs: Type class](https://learn.microsoft.com/dotnet/api/system.type)
- [Microsoft Docs: Activator.CreateInstance](https://learn.microsoft.com/dotnet/api/system.activator.createinstance)
- [See: Custom Attributes](./custom-attributes.md)
