# Source Generators in Design

**Category:** OOP & Design / Compile-Time Design
**Difficulty:** 🔴 Senior
**Tags:** `source-generators`, `code-generation`, `reflection`, `roslyn`

## Question
> How do source generators influence .NET design, especially as an alternative to reflection and magic strings, and what kinds of patterns do they enable?

## Short Answer
Source generators move part of your design from runtime discovery to compile-time code generation. Instead of scanning assemblies with reflection or relying on string keys, you can generate strongly typed code such as registries, serializers, log methods, option validators, and mapping glue during the build. The benefit is better startup performance, stronger typing, and clearer contracts, but the trade-off is more build-time complexity and tooling overhead.

## Detailed Explanation
### What source generators change
A source generator is a Roslyn compiler extension that inspects the user’s code during compilation and emits additional C# source files. Those generated files become part of the same compilation, which means the compiler, IDE, analyzers, and debugger all see them as real code.

That changes design choices. Many frameworks historically used reflection to discover handlers, endpoints, DTO metadata, or logging templates at runtime. Reflection is flexible, but it adds startup cost, can hide failures until production, and often encourages string-based conventions. Source generators let you keep the convenience of automated wiring while shifting the work to build time.

| Approach | Discovery time | Strengths | Weaknesses |
|---|---|---|---|
| Reflection | Runtime | Dynamic and flexible | Startup cost, hidden failures, trimming/AOT pain |
| Hand-written code | Compile time | Explicit and debuggable | Boilerplate and duplication |
| Source generation | Compile time | Strong typing with reduced boilerplate | More tooling and generator complexity |

### Reflection replacement and magic-string reduction
The design benefit is not just speed. Generated code can eliminate entire classes of errors. Instead of writing `"OrderCreated"`, a generator can emit a strongly typed constant or registry entry. Instead of discovering validators or handlers by scanning assemblies, a generator can produce a direct registration list. Instead of runtime expression parsing, it can emit a switch, lookup table, or typed helper.

This matters even more in native AOT and trimming scenarios. Heavy reflection can break if metadata is removed, while generated code is explicit and linker-friendly.

Common real-world examples in .NET include `System.Text.Json` source generation, `LoggerMessage` source generation for high-performance logging, and compile-time options validation. In all three cases, the framework replaces runtime work or string-based patterns with generated, typed code.

> Warning: Source generators do not eliminate design thinking. They can generate bad abstractions just as efficiently as good ones, and debugging generator output can be harder than debugging hand-written code.

### Patterns source generators enable
Source generators are a great fit for registry, factory, adapter, and facade patterns where the repetitive part is mechanical. For example, a generator can emit a message-type registry, a strongly typed route catalog, a mapper skeleton, or a client wrapper derived from annotated interfaces.

They also enable “convention with verification.” You can keep attribute-based configuration, but instead of deferring errors to runtime, the generator can emit diagnostics during build if the annotations are invalid.

### Trade-offs and when not to use them
The trade-off is complexity. A generator adds another moving part to the build, makes local debugging more advanced, and can increase solution complexity for the team. It is also the wrong tool when the problem is small, highly dynamic, or changes based on plugins loaded after startup.

Use source generators when the structure is known at compile time, the generated code is predictable, and you care about startup cost, trimming, AOT friendliness, or removal of magic strings. Do not reach for them just to avoid writing fifty lines of ordinary code.

## Code Example
```csharp
using System;

namespace InterviewExamples;

[AttributeUsage(AttributeTargets.Class)]
public sealed class MessageNameAttribute(string value) : Attribute
{
    public string Value { get; } = value;
}

[MessageName("order-created")]
public sealed record OrderCreated(Guid OrderId);

public static partial class MessageCatalog
{
    // Imagine the members below were emitted by a source generator at build time.
    public const string OrderCreated = "order-created";

    public static string GetName<T>() => typeof(T) == typeof(OrderCreated)
        ? OrderCreated
        : throw new InvalidOperationException($"No generated name for {typeof(T).Name}.");
}

internal static class Program
{
    private static void Main()
    {
        var eventName = MessageCatalog.GetName<OrderCreated>(); // No magic string in calling code.
        Console.WriteLine(eventName);
    }
}
```

## Common Follow-up Questions
- How do source generators differ from reflection at runtime?
- Why are source generators attractive for trimming and native AOT?
- What is the difference between classic and incremental source generators?
- Which design problems are a good fit for source generation, and which are not?
- How do generators surface errors to developers during the build?

## Common Mistakes / Pitfalls
- Using a source generator for problems that are simpler to solve with ordinary code.
- Assuming generated code is automatically easier to maintain than reflection-based code.
- Hiding important behavior in generated output without documenting what gets produced.
- Forgetting that plugin-style runtime discovery may still require reflection or manual registration.
- Treating source generation as a silver bullet for performance without measuring actual startup costs.

## References
- [Source generators overview - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/source-generators-overview)
- [Introducing C# Source Generators - .NET Blog](https://devblogs.microsoft.com/dotnet/introducing-c-source-generators/)
- [How to use source generation in System.Text.Json | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation)
- [High-performance logging in .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/high-performance-logging)
- [Compile-time options validation source generation - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-validation-generator)
