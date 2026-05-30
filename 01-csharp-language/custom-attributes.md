# Custom Attributes

**Category:** C# / Reflection
**Difficulty:** Middle
**Tags:** `attributes`, `reflection`, `metadata`, `attributeusage`

## Question
> What are custom attributes in C#, and how do you define and read them?
>
> How does `AttributeUsage` control where an attribute can be applied and whether it is inherited or repeated?
>
> Why are custom attribute classes commonly sealed, and how are they retrieved at runtime?

## Short Answer
Custom attributes are metadata classes derived from `System.Attribute` that you attach to code elements such as classes, methods, properties, or parameters. `AttributeUsage` defines valid targets and reuse rules, and frameworks typically read attributes through reflection to drive behavior declaratively.

## Detailed Explanation
### What a custom attribute really is
A custom attribute is not magical syntax; it is an ordinary class derived from `Attribute` that the compiler stores as metadata on a target.

| Part | Purpose |
| --- | --- |
| Attribute class | Defines the metadata shape |
| Attribute constructor | Required values |
| Settable properties | Optional named values |
| Reflection retrieval | Reads metadata at runtime |

This pattern is widely used for serialization, validation, testing, dependency injection hints, and web framework configuration.

> Tip: think of attributes as declarative metadata, not as a replacement for business logic. They describe behavior; some other code still has to read and act on them.

See [Reflection Basics](./reflection-basics.md) for the runtime inspection side.

### `AttributeUsage` and common conventions
`[AttributeUsage(...)]` controls where the attribute can appear and whether it can be applied multiple times or inherited.

| Setting | Meaning |
| --- | --- |
| `AttributeTargets.Class` / `Method` / `Property` / etc. | Valid application targets |
| `AllowMultiple = true` | Multiple instances may be attached |
| `Inherited = true` | Derived types or overriding members inherit the attribute |

A common convention is to make custom attribute classes `sealed`. That keeps metadata simple, avoids inheritance confusion, and matches the fact that most attributes represent a closed contract.

### Retrieval and trade-offs
Attributes are usually retrieved with reflection APIs such as `GetCustomAttributes`, `GetCustomAttribute`, or member-specific helper methods. Because that relies on metadata, the same trimming and Native AOT cautions from reflection apply.

> Warning: an attribute does nothing by itself. If no framework or custom code reads it, it is just passive metadata.

## Code Example
```csharp
using System;
using System.Reflection;

var type = typeof(PaymentService);
var attribute = type.GetCustomAttribute<AuditAttribute>();

Console.WriteLine(attribute?.Category);
Console.WriteLine(attribute?.Enabled);

[Audit("billing", Enabled = true)]
sealed class PaymentService
{
}

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
sealed class AuditAttribute : Attribute
{
    public AuditAttribute(string category)
    {
        Category = category;
    }

    public string Category { get; }

    public bool Enabled { get; init; }
}
```

## Common Follow-up Questions
- Why do custom attributes typically derive from `System.Attribute` and often end with `Attribute`?
- What does `AttributeUsage` control exactly?
- Why are many custom attributes marked `sealed`?
- What is the difference between constructor arguments and named properties on an attribute?
- How are attributes retrieved efficiently at runtime?

## Common Mistakes / Pitfalls
- Forgetting that an attribute is only metadata until some code reads it.
- Omitting `AttributeUsage` and leaving targets or multiplicity too loose.
- Overengineering attribute class hierarchies instead of keeping attributes simple and sealed.
- Using reflection to read attributes repeatedly without caching in hot paths.
- Putting mutable business state into attributes instead of stable metadata.

## References
- [Microsoft Docs: Creating custom attributes](https://learn.microsoft.com/dotnet/csharp/advanced-topics/reflection-and-attributes/creating-custom-attributes)
- [Microsoft Docs: AttributeUsageAttribute](https://learn.microsoft.com/dotnet/api/system.attributeusageattribute)
- [Microsoft Docs: Attribute.GetCustomAttribute](https://learn.microsoft.com/dotnet/api/system.attribute.getcustomattribute)
- [See: Reflection Basics](./reflection-basics.md)
