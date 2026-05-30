# Target-Typed `new`

**Category:** C# / Modern C# Features
**Difficulty:** Junior
**Tags:** `target-typed-new`, `new`, `type-inference`, `var`, `readability`

## Question

> What is target-typed `new` in C#, and when does `Foo value = new();` improve readability?

Also asked as:
- "Why does `Dictionary<string, int> map = new();` compile but `var map = new();` does not?"
- "When is target-typed `new` cleaner, and when does it hide too much?"
- "How does target-typed `new` interact with long generic types and constructors with arguments?"

## Short Answer

Target-typed `new` lets you omit the type on the right-hand side when the compiler can infer it from the destination, such as `Dictionary<string, int> counts = new();`. It reduces repetition, especially with long generic names, but it still depends on a clear target type. In modern .NET 8/9 code, it is excellent when the left-hand side already communicates the type well and less helpful when the type would become hidden or ambiguous.

## Detailed Explanation

### What the compiler is inferring

With target-typed `new`, the compiler uses the expected target type from the assignment, variable declaration, return expression, argument, or member initialization context. The object created is still the explicit target type; the type name is simply omitted from the constructor call site.

| Example | Valid? | Why |
|---|---|---|
| `List<int> values = new();` | Yes | Left-hand side provides the type |
| `Widget widget = new("api");` | Yes | Target type plus constructor args are known |
| `var widget = new();` | No | No target type exists |

### Where it helps most

The biggest win is readability when the type name is already obvious and long generic nesting would otherwise repeat itself. Common examples are dictionaries, immutable object graphs, and field/property initializers.

> **Tip:** If the left-hand side already says the type clearly, target-typed `new` usually improves readability. If the reader has to hunt for the type, spell it out.

### Interaction with `var`

A common interview question is why `var map = new();` fails. `var` itself needs the right-hand side to reveal the type, while target-typed `new` needs the left-hand side to reveal the type. When both sides omit it, there is nothing to infer.

### Good vs bad use cases

Good fits:
- long generic types on the left-hand side
- field and property initializers where the declared type is visible
- object creation in obviously typed contexts

Less ideal fits:
- method calls where the parameter type is not obvious at the call site
- local code where `var` plus explicit constructor is easier to scan
- places where several overloads or conversions make the intent harder to read

Target-typed `new` pairs nicely with [collection-expressions.md](./collection-expressions.md) and [primary-constructors.md](./primary-constructors.md): all reduce ceremony, but only when type intent remains obvious.

## Code Example

```csharp
using System;
using System.Collections.Generic;

namespace Demo;

Dictionary<string, List<int>> scoresByTeam = new()
{
    ["Platform"] = new() { 90, 95 },
    ["Payments"] = new() { 88, 91 }
};

ServiceEndpoint endpoint = new("https://api.example.com", 443);

Console.WriteLine(scoresByTeam["Platform"][0]);
Console.WriteLine(endpoint);

public sealed record ServiceEndpoint(string Host, int Port);
```

## Common Follow-up Questions

- Why does target-typed `new` need an expected target type to exist?
- Why does `var value = new();` fail while `MyType value = new();` works?
- When do long generic type names make target-typed `new` especially valuable?
- When does target-typed `new` hide too much information and hurt readability?
- How is target-typed `new` related to collection expressions and other ceremony-reduction features?

## Common Mistakes / Pitfalls

- Trying to use target-typed `new` where no target type exists.
- Overusing it in call sites where the destination type is far away or unclear.
- Assuming it changes runtime behavior rather than just source-level syntax.
- Combining it with overly implicit code so readers must infer too much at once.

## References

- [Target-typed `new` - C# language proposal](https://github.com/dotnet/csharplang/blob/main/proposals/csharp-9.0/target-typed-new.md)
- [See: collection-expressions.md](./collection-expressions.md)
- [See: primary-constructors.md](./primary-constructors.md)
- [See: global-and-implicit-usings.md](./global-and-implicit-usings.md)
