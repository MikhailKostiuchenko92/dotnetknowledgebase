# Reflection vs Source Generators

**Category:** C# / Reflection / Source Generators
**Difficulty:** Senior
**Tags:** `reflection`, `source-generators`, `aot`, `trimming`, `incremental-generator`

## Question
> When should you use runtime reflection versus source generators in modern .NET?
>
> How do reflection-heavy designs compare with compile-time generated code in performance, trimming, and Native AOT scenarios?
>
> What changes when you move from classic reflection to incremental source generators in .NET 8/9?

## Short Answer
Reflection discovers metadata and behavior at runtime, so it is flexible and great for plug-ins, tooling, and truly dynamic scenarios. Source generators move work to build time, which usually improves startup, reduces allocations, and is much friendlier to trimming and Native AOT, but they add build complexity and only help when the shape of the problem is known at compile time. In modern .NET, reflection is still valid, but source generation is usually the better choice for hot paths, serializers, logging, and AOT-oriented libraries.

## Detailed Explanation
### Runtime discovery vs compile-time generation
Reflection means your program inspects metadata at runtime by walking `Type`, `MethodInfo`, `PropertyInfo`, and custom attributes. That is powerful because the code does not need to know all participating types at build time. A dependency injection container, test runner, or plug-in loader can discover types dynamically after deployment.

Source generators work very differently. A Roslyn generator runs during compilation, inspects syntax and symbols, and emits ordinary C# source before your app is built. The generated code then compiles like handwritten code. That means there is no metadata walk at startup for the generated scenario.

| Concern | Reflection | Source generators |
| --- | --- | --- |
| When work happens | Runtime | Compile time |
| Needs metadata at runtime | Usually yes | Usually much less |
| Handles unknown plug-ins loaded later | Excellent | Poor |
| Hot-path performance | Usually worse unless cached | Usually better |
| Native AOT / trimming | Riskier | Usually better |
| Build complexity | Low | Higher |

See [Reflection Basics](./reflection-basics.md) and [Custom Attributes](./custom-attributes.md) for the metadata side of the story.

> Tip: a good interview answer is not “source generators replace reflection.” The stronger answer is “source generators replace reflection when the input shape is known at build time.”

### Performance, startup, and AOT trade-offs
Reflection has two costs: discovery cost and late-bound execution cost. Looking up members by name, reading attributes repeatedly, and invoking members through `MethodInfo.Invoke` all add overhead compared with direct calls. You can reduce that cost with caching or compiled delegates, but the runtime still needs metadata to be present.

That becomes important in .NET 8/9 trimmed and Native AOT apps. If code only reaches members through strings or reflection, the linker may remove those members unless you preserve them explicitly. Reflection is therefore not just a performance question anymore; it is also a deployability question.

Source generators fit well here because they emit strongly typed code that references real members directly. The linker can see those references. That is why source generation is now common in features such as `GeneratedRegex`, `System.Text.Json` source generation, and `LoggerMessage`.

| Scenario | Better fit |
| --- | --- |
| JSON serialization in a trimmed or AOT app | Source generator |
| Regex used repeatedly in a hot path | Source generator |
| Discovering user plug-ins from external assemblies | Reflection |
| Inspecting custom attributes in tooling | Reflection |
| Runtime code that depends on types not known during build | Reflection |

### Incremental generators and practical guidance
Modern generators should usually implement `IIncrementalGenerator`, not the older `ISourceGenerator`. Incremental generators let Roslyn cache intermediate steps so only affected inputs are recomputed. That matters in large solutions, because a poorly designed classic generator can slow builds dramatically.

A practical rule set for .NET 8/9 is:
1. Use reflection when the system is genuinely dynamic.
2. Use source generation when you repeatedly do predictable work that could be emitted once.
3. Prefer generators for libraries that want trimming and Native AOT compatibility.
4. Do not introduce a generator if a simple generic, interface, or handwritten registration is clearer.

> Warning: source generators improve runtime behavior, but they move complexity into the build. If diagnostics, generated source quality, and debugging experience are poor, the team may lose more in maintainability than it gains in speed.

For generator internals, see [Source Generators Intro](./source-generators-intro.md). For a related runtime-code-generation comparison, see [dynamic-code-with-emit-vs-expression.md](./dynamic-code-with-emit-vs-expression.md).

## Code Example
```csharp
using System;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;

var order = new Order(42, "coffee", 12.50m);

Console.WriteLine("Reflection output:");
foreach (PropertyInfo property in typeof(Order).GetProperties())
{
    // Reflection discovers metadata at runtime.
    Console.WriteLine($"{property.Name} = {property.GetValue(order)}");
}

Console.WriteLine();
Console.WriteLine("System.Text.Json source-generated output:");

// This path uses compile-time generated serialization metadata.
string json = JsonSerializer.Serialize(order, OrderJsonContext.Default.Order);
Console.WriteLine(json);

public sealed record Order(int Id, string Product, decimal Price);

[JsonSerializable(typeof(Order))]
internal partial class OrderJsonContext : JsonSerializerContext
{
}
```

## Common Follow-up Questions
- Why is reflection harder to use safely in trimmed or Native AOT applications?
- When does caching make reflection acceptable even in production code?
- What problem do incremental generators solve compared with classic source generators?
- Why are `GeneratedRegex` and `System.Text.Json` source generation good showcase examples?
- When is runtime discovery still a better design than compile-time generation?

## Common Mistakes / Pitfalls
- Claiming that source generators can replace plug-in discovery when types are only known after deployment.
- Using reflection repeatedly in hot paths without caching metadata or delegates.
- Treating source generators as “free” and ignoring build-time cost and debugging complexity.
- Forgetting that generators emit code at compile time, so they cannot inspect runtime data.
- Shipping reflection-based libraries into Native AOT scenarios without trimming annotations or an alternate path.

## References
- [Microsoft Docs: Reflection and attributes](https://learn.microsoft.com/dotnet/csharp/advanced-topics/reflection-and-attributes/)
- [Microsoft Docs: Source generators overview](https://learn.microsoft.com/dotnet/csharp/roslyn-sdk/source-generators-overview)
- [Microsoft Docs: System.Text.Json source generation](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/source-generation)
- [See: Reflection Basics](./reflection-basics.md)
- [See: Source Generators Intro](./source-generators-intro.md)
