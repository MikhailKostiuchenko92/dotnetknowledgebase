# What Constraints Does Native AOT Introduce?

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🔴 Senior
**Tags:** `native aot`, `requiresdynamiccode`, `reflection`, `ilc`, `interop`

## Question

> What code patterns break or become risky when you publish a .NET application with Native AOT?

Also asked as:
> What does `[RequiresDynamicCode]` mean, and why does it matter for Native AOT?
> Why are reflection, dynamic loading, and COM interop problematic under Native AOT?

## Short Answer

Native AOT works best when the runtime can know the full reachable code graph at publish time. APIs marked with `[RequiresDynamicCode]`, runtime assembly loading, late-bound activation of unknown types, and many classic COM interop patterns conflict with that model because they depend on generating or discovering code after publish. The compiler surfaces these issues as ILC warnings, and the usual fix is to move from dynamic behavior to explicit type registration, source generation, or alternative deployment models.

## Detailed Explanation

### Why Native AOT Has a "Closed World" Bias

The Native AOT toolchain compiles the app ahead of time for one concrete target OS and architecture. That means the compiler must decide up front which methods, generic instantiations, metadata, and runtime helpers are needed. If your code asks the runtime to discover types or produce new executable code later, the publish step cannot always guarantee that everything required will exist in the final native image.

That is the reason many APIs are annotated with `[RequiresDynamicCode]`: they may work on the CoreCLR JIT runtime, but they fundamentally rely on capabilities that a static AOT binary may not provide.

### APIs and Patterns That Commonly Fail

| Pattern | Why it is a problem under AOT | Preferred alternative |
|---|---|---|
| `Assembly.Load(byte[])` | The code to be loaded was not part of the native image at publish time | Ship known assemblies and reference them statically, or avoid plugin-style loading |
| `Activator.CreateInstance` for unknown types | The exact constructor and metadata may not be preserved | Use explicit factories, switch expressions, or precomputed maps |
| `Reflection.Emit` / runtime proxy generation | Requires generating executable code dynamically | Use source generators or handwritten adapters |
| Broad serializer metadata discovery | Depends on reflective graph walking | Use source-generated metadata |
| Runtime regex compilation | Uses dynamic code paths | Use `[GeneratedRegex]` |

A key interview point is that Native AOT does not ban all reflection. Reflection over known, preserved types can still work. The problem is *unbounded* reflection where the compiler cannot predict what metadata or code will be needed.

> Warning: if you cannot explain where the type comes from and how it stays reachable at publish time, assume the pattern is suspicious for trimming and Native AOT.

### `[RequiresDynamicCode]` and ILC Warnings

When you call an API marked with `[RequiresDynamicCode]`, the compiler can emit warnings such as IL3050. Those warnings are design feedback, not cosmetic noise. They tell you that the call site depends on runtime behavior the AOT binary may not support.

Typical responses are:

1. Replace the API with a compile-time alternative.
2. Move the dynamic behavior behind a deployment-specific boundary.
3. Annotate your own API if it transitively requires dynamic code.
4. Suppress only after proving the call is unreachable or safe for your exact publish scenario.

The same mindset applies to ILC warnings in general: fix the root cause instead of blindly suppressing them. This topic overlaps directly with [native-aot-overview.md](./native-aot-overview.md) and [assembly-trimming.md](./assembly-trimming.md).

### Platform and Interop Constraints

Native AOT produces a native binary for a specific RID, so cross-OS publishing is not universal. A `win-x64` publish is not a portable IL app you can later run on Linux. You publish for the exact target platform and architecture, and cross-compilation depends on toolchain support being available for that pair.

P/Invoke is a good story in Native AOT because calling into native libraries matches the static model well. Managed COM interop is different. Classic built-in COM interop support is not a general Native AOT strength; on Windows, newer .NET releases add partial and source-generated COM-related scenarios, but you should not assume parity with CoreCLR's full dynamic COM behavior.

### How to Make Libraries and Apps AOT-Friendly

AOT-friendly code favors explicitness:

- Known generic types instead of open-ended runtime discovery.
- Source generators for JSON, regex, logging, marshalling, or DI-related metadata.
- Configuration objects bound to known types.
- Factories keyed by enum, string, or interface registrations created at compile time.
- Conditional features separated behind interfaces so the AOT publish excludes unsupported paths.

That design style is less magical, but it gives the toolchain enough information to emit a reliable binary.

## Code Example

```csharp
using System.Diagnostics.CodeAnalysis;

namespace RuntimeSamples.NativeAotConstraints;

internal interface IMessageHandler
{
    string Handle(string input);
}

internal sealed class EmailHandler : IMessageHandler
{
    public string Handle(string input) => $"EMAIL:{input}";
}

internal sealed class SmsHandler : IMessageHandler
{
    public string Handle(string input) => $"SMS:{input}";
}

internal static class HandlerFactory
{
    // This style is predictable for Native AOT because all concrete types are known.
    public static IMessageHandler Create(string kind) => kind.ToLowerInvariant() switch
    {
        "email" => new EmailHandler(),
        "sms" => new SmsHandler(),
        _ => throw new NotSupportedException($"Unknown handler: {kind}")
    };

    [RequiresDynamicCode("Late-bound activation may require runtime-generated code or missing metadata.")]
    public static object CreateLateBound(Type type) => Activator.CreateInstance(type)
        ?? throw new InvalidOperationException("Could not create instance.");
}

internal static class Program
{
    private static void Main()
    {
        IMessageHandler handler = HandlerFactory.Create("email");
        Console.WriteLine(handler.Handle("hello@example.com"));

        // Avoid calling CreateLateBound in a Native AOT path unless you have proven it is safe.
    }
}
```

## Common Follow-up Questions

- What is the difference between `[RequiresDynamicCode]` and `[RequiresUnreferencedCode]`?
- Can reflection ever work in a Native AOT app?
- Why is `Assembly.Load(byte[])` fundamentally incompatible with static native publishing?
- How do source generators reduce Native AOT risk?
- What kinds of ILC warnings should block a release?
- Why is P/Invoke usually okay while managed COM interop is not?

## Common Mistakes / Pitfalls

- Suppressing IL3050 or other AOT warnings without proving the path is safe.
- Assuming `Activator.CreateInstance` is always fine if the code compiles.
- Designing plugin architectures that depend on runtime assembly loading, then trying to retrofit Native AOT later.
- Forgetting that Native AOT output must target a specific RID, not a generic “any OS” package.
- Treating classic COM interop support as equivalent between CoreCLR and Native AOT.

## References

- [Native AOT deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [Fixing warnings when publishing as Native AOT — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/fixing-warnings)
- [Intrinsic APIs marked RequiresDynamicCode — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/intrinsic-requiresdynamiccode-apis)
- [IL3050 warning — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/warnings/il3050)
- [RequiresDynamicCodeAttribute API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.requiresdynamiccodeattribute)
