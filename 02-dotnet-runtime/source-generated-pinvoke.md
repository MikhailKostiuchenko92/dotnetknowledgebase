# Source-Generated P/Invoke in .NET

**Category:** .NET Runtime / Interop
**Difficulty:** 🔴 Senior
**Tags:** `LibraryImport`, `source-generation`, `NativeAOT`, `MarshalUsing`, `NativeMarshalling`, `interop`

## Question
> What is source-generated P/Invoke, and why was `[LibraryImport]` added?

> How is `[LibraryImport]` different from classic `[DllImport]` at runtime?

> Why is source-generated marshalling better for trimming and NativeAOT?

## Short Answer
Source-generated P/Invoke uses `[LibraryImport]` to generate interop stubs at compile time instead of relying on the older runtime marshalling path associated with `[DllImport]`. This makes the generated code more explicit, more analyzable, better for trimming and NativeAOT, and often faster because the stub is specialized for the exact signature. In newer interop code, `[LibraryImport]` plus modern marshalling attributes such as `[MarshalUsing]` and `[NativeMarshalling]` is the preferred direction.

## Detailed Explanation
### Why `[LibraryImport]` Exists
Classic `[DllImport]` is convenient, but it depends on broader runtime marshalling behavior that was designed long before trimming, AOT, and source generators became central goals. `[LibraryImport]` moves that work into compile time. A Roslyn source generator emits the actual interop stub based on your signature and attributes.

This gives the runtime less guessing to do and gives tools more visibility into what will happen.

### Advantages Over `[DllImport]`
| Aspect | `[DllImport]` | `[LibraryImport]` |
|---|---|---|
| Stub generation | Runtime-oriented | Compile-time generated |
| NativeAOT friendliness | More limited | Much better |
| Trimming clarity | Weaker | Stronger |
| Marshalling customization | Traditional attributes | Modern source-gen model |

The big interview answer is that source generation removes runtime dependency on a lot of general marshalling machinery. That is why it fits NativeAOT so much better.

### Migration Shape
A typical migration looks like this:
- replace `[DllImport]` with `[LibraryImport]`
- make the method `static partial`
- update marshalling configuration where needed
- consider moving from some `[MarshalAs]` scenarios to `[MarshalUsing]`

For custom types, `[NativeMarshalling(typeof(MyMarshaller))]` lets you plug in a source-generated custom marshaller instead of relying on runtime reflection-like behavior.

### Analyzer Support
The SDK includes analyzers that can suggest migration opportunities from `DllImport` to `LibraryImport`, especially when the signature is a good fit for source-generated interop. That is useful because not every legacy signature migrates one-for-one without thought.

### Marshalling Becomes More Explicit
This model also pushes developers toward explicit marshalling choices. Instead of leaning on broad legacy defaults, you describe the desired behavior in attributes and, when necessary, provide custom marshaller types via `[MarshalUsing]` or `[NativeMarshalling]`. That makes the generated stub easier to audit and usually easier to reason about during code review.

> **Warning:** Migration is not purely mechanical. If the old signature relied on implicit or quirky marshalling behavior, you must validate the generated stub’s behavior carefully, especially for strings, booleans, and custom structs.

### Why It Matters for AOT
Ahead-of-time compilation needs to know more at build time. Runtime-generated interop behavior can conflict with trimming or AOT because required marshalling code may not be preserved or generated in the same way. `[LibraryImport]` makes the boundary explicit enough that the toolchain can keep only what is needed.

### Practical Guidance
For new interop code on .NET 7+, prefer `[LibraryImport]` unless you have a specific reason not to. Treat migration as an opportunity to simplify signatures, make string encoding explicit, and remove unsafe implicit marshalling assumptions. That usually produces interop code that is easier to trim, review, test, and evolve.

Related: [P/Invoke Fundamentals](./pinvoke-fundamentals.md) and [Marshalling Types](./marshalling-types.md).

## Code Example
```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal static partial class NativeClock
{
    [LibraryImport("kernel32.dll", EntryPoint = "GetTickCount")]
    [return: MarshalAs(UnmanagedType.U4)] // Still supported for simple cases.
    internal static partial uint GetTickCount(); // Source generator emits the stub at build time.
}

public static class SourceGeneratedPInvokeDemo
{
    public static void Run()
    {
        var ticks = NativeClock.GetTickCount();
        Console.WriteLine($"Tick count = {ticks}");
    }
}
```

## Common Follow-up Questions
- Why is `[LibraryImport]` more compatible with NativeAOT than `[DllImport]`?
- What changes when migrating a method to `static partial`?
- When do I need `[MarshalUsing]` or `[NativeMarshalling]`?
- Are all old `[DllImport]` signatures safe to migrate automatically?
- What kinds of analyzer suggestions exist for interop modernization?

## Common Mistakes / Pitfalls
- Assuming every `[DllImport]` attribute maps mechanically to `[LibraryImport]` with no behavior changes.
- Migrating without validating string, bool, or struct marshalling details.
- Forgetting that source-generated interop methods must be `static partial`.
- Ignoring analyzer guidance and keeping implicit legacy marshalling assumptions.
- Using source-generated interop while still treating ownership and lifetime rules casually.

## References
- [LibraryImportAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.libraryimportattribute)
- [Best practices for native interoperability](https://learn.microsoft.com/dotnet/standard/native-interop/best-practices)
- [NativeMarshallingAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshalling.nativemarshallingattribute)
- [MarshalUsingAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshalling.marshalusingattribute)
