# Source Generators Intro

**Category:** C# / Source Generators
**Difficulty:** Senior
**Tags:** `source-generators`, `iincrementalgenerator`, `roslyn`, `generatedregex`, `system-text-json`

## Question
> What are source generators in C#, and how do they work in the Roslyn compilation pipeline?
>
> What is an `IIncrementalGenerator`, what does `SyntaxProvider` do, and where do source generators show up in real .NET 8/9 code?
>
> How do generators report diagnostics, and why are they increasingly important for AOT-friendly libraries?

## Short Answer
A source generator is a Roslyn component that runs during compilation, inspects syntax or symbols, and emits additional C# source that is compiled into the project. In modern code you usually implement `IIncrementalGenerator`, which lets Roslyn cache work and rerun only affected steps. Source generators are common in .NET 8/9 for `GeneratedRegex`, `System.Text.Json` source generation, and `LoggerMessage`, because they remove repetitive boilerplate and replace runtime reflection with compile-time generated code.

## Detailed Explanation
### Where generators run
A source generator is not part of your application runtime. It runs inside the compiler while the project is being built. It can inspect syntax trees, semantic models, additional files, analyzer config options, and project references, then output new `.g.cs` files.

That distinction matters: generators cannot look at runtime values, database state, or HTTP responses. They only see compile-time inputs.

| Stage | What happens |
| --- | --- |
| Parse | Roslyn builds syntax trees |
| Analyze | Generators inspect syntax/symbols |
| Generate | Generators emit C# source |
| Compile | Original + generated code compile together |

> Tip: think of a generator as a compile-time code factory, not as a runtime plug-in.

### `IIncrementalGenerator` and `SyntaxProvider`
Older generators used `ISourceGenerator`, which works but can be wasteful because it tends to recompute everything. In modern .NET, `IIncrementalGenerator` is the preferred model. It creates a pipeline of transformations where Roslyn can cache intermediate values.

A common starting point is `SyntaxProvider`, which filters syntax nodes cheaply and then optionally upgrades them to semantic information. For example, a generator may first find all partial classes with a target attribute, then resolve symbols, then emit code only for those symbols.

| API | Purpose |
| --- | --- |
| `IIncrementalGenerator` | Preferred incremental generator contract |
| `SyntaxProvider` | Efficiently filters candidate syntax nodes |
| `Combine` / `Collect` | Joins and batches incremental inputs |
| `RegisterSourceOutput` | Emits source or diagnostics |

Incremental design is important because generator performance directly affects build performance. A generator that scans everything on every keystroke becomes a productivity problem.

### Real BCL examples and diagnostics
The .NET ecosystem uses generators in places where runtime reflection used to be common:

| Feature | Why a generator helps |
| --- | --- |
| `GeneratedRegex` | Emits a specialized regex implementation instead of parsing the pattern at runtime |
| `System.Text.Json` source generation | Produces serialization metadata for trimming and Native AOT |
| `LoggerMessage` | Generates efficient logging methods and avoids repeated message-template parsing |

Generators can also report diagnostics, much like analyzers. That means they can fail fast when the user writes an invalid attribute usage or incomplete partial type declaration.

> Warning: generators should produce clear diagnostics and predictable output. A generator that silently emits surprising code is harder to trust than a little handwritten boilerplate.

See [reflection-vs-source-generators.md](./reflection-vs-source-generators.md) for architectural trade-offs, [partial-classes-and-methods.md](./partial-classes-and-methods.md) for the partial-type angle, and [custom-attributes.md](./custom-attributes.md) for common metadata-based triggers.

## Code Example
```csharp
using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

Console.WriteLine(GeneratedPatterns.OrderCodeRegex().IsMatch("ORD-2024"));

var order = new Order(7, "keyboard");
string json = JsonSerializer.Serialize(order, AppJsonContext.Default.Order);
Console.WriteLine(json);

public sealed record Order(int Id, string Product);

public static partial class GeneratedPatterns
{
    // `GeneratedRegex` is backed by a source generator in modern .NET.
    [GeneratedRegex(@"^ORD-\d{4}$")]
    public static partial Regex OrderCodeRegex();
}

// System.Text.Json source generation emits serialization metadata at build time.
[JsonSerializable(typeof(Order))]
internal partial class AppJsonContext : JsonSerializerContext
{
}
```

## Common Follow-up Questions
- Why is `IIncrementalGenerator` preferred over `ISourceGenerator` today?
- What is the role of `SyntaxProvider` in generator performance?
- Why do source generators help with trimming and Native AOT?
- What kinds of diagnostics should a good generator report?
- Why do many generators require user code to be `partial`?

## Common Mistakes / Pitfalls
- Thinking a generator can inspect runtime data instead of only compile-time inputs.
- Writing a generator that scans the full compilation every time instead of using incremental pipelines.
- Emitting unreadable or unstable generated code without helpful diagnostics.
- Treating source generators as analyzers only; they can add code, not just warnings.
- Forgetting that generated code becomes part of the public build output and should be versioned carefully.

## References
- [Microsoft Docs: Source generators overview](https://learn.microsoft.com/dotnet/csharp/roslyn-sdk/source-generators-overview)
- [Microsoft Docs: Regular expression source generators](https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-source-generators)
- [Microsoft Docs: Compile-time logging source generation](https://learn.microsoft.com/dotnet/core/extensions/logger-message-generator)
- [Microsoft Docs: System.Text.Json source generation](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/source-generation)
- [See: Reflection vs Source Generators](./reflection-vs-source-generators.md)
