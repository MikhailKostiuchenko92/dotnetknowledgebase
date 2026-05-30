# Primary Constructors

**Category:** C# / Modern C# Features
**Difficulty:** Middle
**Tags:** `primary-constructors`, `constructors`, `required`, `captures`, `csharp-12`

## Question

> What are primary constructors in C# 12, and how do they work for classes and structs?

Also asked as:
- "Do primary constructor parameters automatically become properties or fields?"
- "What does it mean for a primary constructor parameter to be captured?"
- "When are primary constructors cleaner than normal constructors, and when are they not?"

## Short Answer

Primary constructors let a class or struct declare constructor parameters right on the type declaration in C# 12. Those parameters are in scope throughout the type body, but unlike positional records, they do **not** automatically become public properties. In .NET 8/9 code, they are great for concise dependency injection or small value-like types, but they can become confusing if parameter capture hides storage or if the type needs complex validation and initialization rules.

## Detailed Explanation

### What primary constructors actually generate

A primary constructor moves the parameter list to the type declaration:

```csharp
public sealed class Worker(string name)
```

The important interview detail is that `name` is **not automatically a property** on ordinary classes or structs. It is just a parameter that is in scope across field initializers, property initializers, methods, and accessors in that type.

If you copy the value into a field or property, that storage is explicit. If you use the parameter directly inside instance members, the compiler may synthesize hidden storage so the value remains available later. That is what people mean by a parameter being *captured*.

| Pattern | Storage model | Typical readability |
|---|---|---|
| `public string Name { get; } = name;` | Explicit property backing field | Clear |
| `public string Describe() => name;` | Hidden captured storage may be synthesized | Less obvious |
| Primary ctor + many side effects | Mixed explicit and hidden state | Often hard to read |

### Captured parameters vs explicit fields

For interview-quality code, explicit state is usually easier to maintain. If a value is part of the object's long-term state, exposing that through a clearly named field or property is often better than relying on hidden capture.

> **Tip:** Use primary constructors for concise syntax, but prefer explicit fields or properties when the parameter is real object state, not just construction input.

That guidance becomes even more important in larger classes. A short service wrapper with two dependencies is a good fit; a long domain type with many invariants usually is not.

### Interaction with `required`

Primary constructors and `required` solve different problems. A primary constructor provides one construction path. `required` says certain members must be initialized by the caller unless a constructor marked with `SetsRequiredMembers` guarantees they are set.

So a type can use both:
- primary constructor for core dependencies or identity
- `required` members for additional initialization that must be provided

See [required-members.md](./required-members.md) and [init-only-properties.md](./init-only-properties.md).

### Good and bad use cases

Good fits:
- small service classes with obvious dependencies
- lightweight immutable structs and value objects
- concise infrastructure types where state maps directly from parameters

Poor fits:
- classes with many optional branches, validation rules, or multiple construction paths
- types where hidden parameter capture obscures what is stored
- APIs where classic constructors communicate intent more clearly

Primary constructors complement, not replace, topics like [constructors-chaining-and-static.md](./constructors-chaining-and-static.md), records, and `required` members.

## Code Example

```csharp
using System;

namespace Demo;

var client = new ApiClient("https://api.example.com", new ConsoleTransport())
{
    ApiKey = "secret-key" // `required` still applies even with a primary constructor.
};

Console.WriteLine(client.Describe());
Console.WriteLine(new TemperatureRange(-5, 12).Contains(3));

public sealed class ApiClient(string baseUrl, ITransport transport)
{
    private readonly ITransport _transport = transport; // Explicit storage is clearer than hidden capture.

    public Uri BaseUri { get; } = new(baseUrl);
    public required string ApiKey { get; init; }

    public string Describe()
        => $"{BaseUri.Host} via {_transport.Name}";
}

public readonly struct TemperatureRange(double min, double max)
{
    public double Min { get; } = min;
    public double Max { get; } = max;

    public bool Contains(double value)
        => value >= min && value <= max; // Uses the parameters inside an instance member.
}

public interface ITransport
{
    string Name { get; }
}

public sealed class ConsoleTransport : ITransport
{
    public string Name => "ConsoleTransport";
}
```

## Common Follow-up Questions

- How are primary constructors on classes different from positional records?
- When does the compiler synthesize hidden storage for a primary constructor parameter?
- Why can explicit fields or properties be clearer than relying on capture?
- How do primary constructors interact with `required` members and object initializers?
- When is a normal constructor or constructor chaining still the better API?

## Common Mistakes / Pitfalls

- Assuming primary constructor parameters automatically become public properties on classes.
- Overusing captured parameters so object state becomes implicit and harder to read.
- Replacing all normal constructors even when validation and branching logic become less clear.
- Forgetting that `required` members still need to be satisfied unless a constructor guarantees them.
- Treating primary constructors as a record feature clone instead of a more general syntax feature.

## References

- [Declare primary constructors for classes and structs](https://learn.microsoft.com/dotnet/csharp/whats-new/tutorials/primary-constructors)
- [required modifier - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/required)
- [See: constructors-chaining-and-static.md](./constructors-chaining-and-static.md)
- [See: init-only-properties.md](./init-only-properties.md)
- [See: required-members.md](./required-members.md)
