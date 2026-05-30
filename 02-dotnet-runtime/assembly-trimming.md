# Assembly Trimming

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟡 Middle-Senior
**Tags:** `trimming`, `ILLink`, `ILLinker`, `PublishTrimmed`, `RequiresUnreferencedCode`, `DynamicallyAccessedMembers`, `NativeAOT`

## Question

> What is assembly trimming in .NET, and why does it break some reflection-heavy code?

Also asked as:
> What does `PublishTrimmed=true` do, and how does the trimmer decide what to keep?
> How do `RequiresUnreferencedCode` and `DynamicallyAccessedMembers` help make code trim-safe?

## Short Answer

Assembly trimming uses the ILLink trimmer to remove code the publish pipeline believes is unreachable, reducing application size and often improving startup. The trimmer starts from known roots, follows static references, and removes members it cannot see being used. Reflection, dynamic loading, and string-based type activation are problematic because the required members may only be discoverable at runtime, so trim-safe libraries must annotate those requirements explicitly.

## Detailed Explanation

### What the Trimmer Does

When you publish with:

```xml
<PublishTrimmed>true</PublishTrimmed>
```

.NET runs the **ILLink** trimmer during publish. Conceptually, it performs tree-shaking on IL: it marks required entry points and reachable dependencies, then removes unused types, methods, and metadata from the final output.

| Step | What happens |
|---|---|
| Root discovery | Entry points and known framework roots are marked |
| Reachability analysis | Static references are followed transitively |
| Removal | Unreachable members are omitted from publish output |

This is why trimming can drastically reduce app size, especially in self-contained deployments.

### Why Reflection Is Hard

The trimmer is good at following **static** references. It is much weaker when your code decides what to load using strings, configuration, naming conventions, or generic patterns only known at runtime.

Examples of trim-unsafe patterns include:

- `Type.GetType("Some.Namespace.TypeName")`
- `Assembly.Load(...)` from dynamic names
- `Activator.CreateInstance(type)` when the required constructors are not statically visible
- scanning assemblies for “all implementations” via reflection

If the trimmer cannot see that a member will be needed, it may remove it. The result is a publish that works in Debug but fails after trimming.

> **Warning:** A trimmed build can fail at runtime even though the untrimmed application worked perfectly. Always test the published trimmed output, not just the source build.

### `RequiresUnreferencedCode`

`[RequiresUnreferencedCode]` marks APIs that are fundamentally unsafe for trimming. It tells callers: “this method may break when code is trimmed because it depends on members the trimmer cannot safely reason about.”

That attribute improves correctness in two ways:

1. it documents the contract, and
2. it produces analyzer warnings during build/publish.

This is especially important for library authors, because they need to communicate trimming hazards to downstream consumers.

### `DynamicallyAccessedMembers`

Sometimes reflection is necessary, but the required members are knowable if you tell the trimmer about them. That is what `[DynamicallyAccessedMembers]` does. It annotates a `Type`, string-like type name flow, or generic parameter to say which members must be preserved.

For example, if you plan to create instances via reflection, you might annotate that the target type must keep its public parameterless constructor. That allows the trimmer to keep exactly what the reflective code needs instead of disabling trimming entirely.

### Trimming and NativeAOT

Trimming and NativeAOT are related but not identical. NativeAOT goes further by compiling ahead of time into native code, but it depends on code being analyzable in many of the same ways. In practice, code that is trim-compatible is much closer to being NativeAOT-compatible.

That is why trimming work often exposes the same categories of problems: uncontrolled reflection, dynamic code generation, runtime assembly scanning, and string-based activation.

### Interview Takeaway

The best answer is: trimming removes unreachable IL based on static analysis, reflection-heavy patterns are risky because the analyzer cannot see them, `RequiresUnreferencedCode` warns callers about unsafe APIs, `DynamicallyAccessedMembers` preserves specific members needed by reflection, and trim-friendly code is a stepping stone toward NativeAOT. See [native-aot-overview.md](./native-aot-overview.md) and [jit-compilation-basics.md](./jit-compilation-basics.md).

## Code Example

```csharp
using System.Diagnostics.CodeAnalysis;

namespace RuntimeSamples;

public static class AssemblyTrimmingDemo
{
    public static void Main()
    {
        Type pluginType = typeof(SamplePlugin);
        object instance = CreateInstance(pluginType);
        Console.WriteLine(instance.GetType().Name);
    }

    public static object CreateInstance(
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicParameterlessConstructor)] Type type)
    {
        return Activator.CreateInstance(type)
            ?? throw new InvalidOperationException("Type could not be created.");
    }

    [RequiresUnreferencedCode("Scans assemblies dynamically and may break in trimmed publishes.")]
    public static Type? FindPluginByName(string fullName)
    {
        return Type.GetType(fullName);
    }
}

public sealed class SamplePlugin
{
    public SamplePlugin() { }
}
```

## Common Follow-up Questions

- Why can a trimmed build fail even when the normal Debug build succeeds?
- What kinds of reflection patterns are trim-unsafe?
- What is the purpose of `[RequiresUnreferencedCode]`?
- How does `[DynamicallyAccessedMembers]` help the trimmer keep the right metadata?
- Why is trim compatibility important for NativeAOT readiness?
- When should library authors treat trimming warnings as API-contract issues rather than local implementation details?

## Common Mistakes / Pitfalls

- Enabling `PublishTrimmed=true` and testing only untrimmed local runs.
- Using `Type.GetType(string)` or dynamic assembly scanning without preserving required members.
- Suppressing trimming warnings instead of understanding and annotating the reflective contract.
- Assuming trim-safe and NativeAOT-safe mean exactly the same thing.
- Forgetting that analyzers warn at build time, but runtime validation is still required.

## References

- [Trim self-contained deployments and executables](https://learn.microsoft.com/dotnet/core/deploying/trimming/trim-self-contained)
- [Fix warnings in trimmed apps](https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings)
- [RequiresUnreferencedCodeAttribute](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.requiresunreferencedcodeattribute)
- [DynamicallyAccessedMembersAttribute](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.dynamicallyaccessedmembersattribute)
- [Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
