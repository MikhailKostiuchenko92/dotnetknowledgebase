# What Are TFMs and Multi-Targeting in .NET?

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟡 Middle
**Tags:** `TFM`, `multi-targeting`, `net8.0`, `netstandard2.0`, `SupportedOSPlatform`

## Question

> What is a Target Framework Moniker, and how does multi-targeting work in .NET?

Also asked as:
> When would you target `net8.0`, `net8.0-windows`, or `netstandard2.0`?
> How do preprocessor symbols and platform analyzers help with multi-targeted libraries?

## Short Answer

A TFM (Target Framework Moniker) identifies the API surface a project compiles against, for example `net8.0`, `net8.0-windows`, or `netstandard2.0`. Multi-targeting means compiling one project for multiple TFMs by using `<TargetFrameworks>...</TargetFrameworks>`, which is common in libraries that need broad compatibility. In code, you can use symbols like `NET8_0_OR_GREATER` and platform annotations such as `[SupportedOSPlatform]` to keep platform-specific code explicit and analyzer-friendly.

## Detailed Explanation

### What a TFM Actually Means

A TFM describes the framework contract your assembly expects at compile time. `net8.0` means “compile against .NET 8 APIs.” `net8.0-windows` narrows that further by allowing Windows-only APIs. `netstandard2.0` is not a runtime; it is a compatibility surface intended mainly for reusable libraries.

That distinction matters in interviews because developers often confuse a TFM with deployment target or RID. A TFM answers *which APIs can I use?* A RID answers *where will the app run?*

### Why Multi-Target

Multi-targeting is most common in libraries. Suppose you want to support legacy .NET Framework consumers through `netstandard2.0` but also expose better implementations for modern runtimes through `net8.0`. One project can emit multiple assemblies and the SDK or NuGet will select the best match for the consuming application.

| TFM | Typical use |
|---|---|
| `net8.0` | Modern application or library targeting current .NET |
| `net8.0-windows` | App/library that needs Windows-only APIs |
| `netstandard2.0` | Library compatibility for older and broader consumers |

### Conditional Compilation and Platform Guards

When you multi-target, some code is only valid for certain TFMs. Preprocessor symbols such as `NET8_0_OR_GREATER` let you compile new implementations only where supported. For OS-specific APIs, `[SupportedOSPlatform("windows")]` and runtime guards like `OperatingSystem.IsWindows()` help analyzers prove safety.

This is better than hiding platform assumptions in comments. The compiler and analyzers can now flag incorrect calls for you.

> Warning: do not target `netstandard2.0` by habit if your consumers are already on modern .NET. It can force you to avoid better APIs and add unnecessary compatibility complexity.

### NuGet and Asset Selection

Packages can place assemblies under `lib/net8.0/`, `lib/net6.0/`, or `lib/netstandard2.0/`. NuGet chooses the nearest compatible asset for the consuming project's TFM. That is why a multi-targeted package can offer one assembly with spans, source generators, or new BCL APIs for modern runtimes while still shipping a fallback for older consumers.

### Libraries Need This More Than Apps

Applications usually know their deployment target, so they can often choose one modern TFM and keep life simple. Libraries are different because they may be consumed by many host applications with different compatibility requirements. That is why multi-targeting is usually a library strategy rather than an application strategy. Mentioning that distinction in interviews shows that you understand not just how to write the XML, but why the complexity is sometimes justified and sometimes unnecessary.

This topic also connects to deployment optimizations. Trimming and Native AOT can interact with API choices and reflection patterns, so see [assembly-trimming.md](./assembly-trimming.md) and [native-aot-overview.md](./native-aot-overview.md).

## Code Example

```csharp
using System.Runtime.Versioning;

namespace DotNetRuntimeSamples.MultiTargeting;

internal static class PlatformHelpers
{
    public static string DescribeRuntime()
    {
#if NET8_0_OR_GREATER
        return $"Running on .NET 8+ ({System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription})";
#else
        return "Running on an older target framework";
#endif
    }

    [SupportedOSPlatform("windows")]
    public static string ReadWindowsFolder()
    {
        return Environment.GetFolderPath(Environment.SpecialFolder.Windows); // Analyzer knows this is Windows-only.
    }
}

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine(PlatformHelpers.DescribeRuntime());

        if (OperatingSystem.IsWindows()) // Runtime guard matches the platform annotation.
        {
            Console.WriteLine(PlatformHelpers.ReadWindowsFolder());
        }
    }
}
```

## Common Follow-up Questions

- When is `netstandard2.0` still worth targeting?
- What is the difference between `net8.0-windows` and `net8.0` plus a runtime check?
- How does NuGet choose among `lib/net8.0/` and `lib/netstandard2.0/` assets?
- Why are analyzer-backed platform annotations better than comments?
- How does multi-targeting interact with trimming or Native AOT?

## Common Mistakes / Pitfalls

- Confusing TFMs with RIDs.
- Multi-targeting applications when only libraries need the extra compatibility surface.
- Defaulting to `netstandard2.0` and giving up modern APIs without an actual consumer need.
- Using OS-specific APIs without annotations or runtime guards.
- Forgetting that each target can compile different code paths and should be tested.

## References

- [Target frameworks in SDK-style projects — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/frameworks)
- [Target frameworks in SDK-style projects (NuGet)](https://learn.microsoft.com/nuget/create-packages/multiple-target-frameworks-project-file)
- [SupportedOSPlatformAttribute — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.versioning.supportedosplatformattribute)
- [Platform compatibility analyzer — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/analyzers/platform-compat-analyzer)
- [Preprocessor directives — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/preprocessor-directives)
