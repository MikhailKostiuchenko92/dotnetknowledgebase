# What Is a Runtime Identifier and How Does the RID Graph Work?

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟡 Middle
**Tags:** `RID`, `NuGet`, `RuntimeIdentifier`, `runtime-assets`, `deployment`

## Question

> What is a Runtime Identifier in .NET, and why does it matter for publishing and NuGet package resolution?

Also asked as:
> How does the RID graph fallback chain work?
> What is the difference between a portable RID like `linux` and a specific RID like `linux-x64`?

## Short Answer

A RID (Runtime Identifier) describes the target OS and architecture, such as `win-x64`, `linux-arm64`, or `osx-x64`. .NET uses the RID to choose runtime-specific assets during publish and package restore, and the RID graph defines fallback chains when an exact match is unavailable. Portable RIDs are broader but less specific, while architecture-specific RIDs are necessary when native binaries depend on a concrete target.

## Detailed Explanation

### What a RID Represents

A TFM such as `net8.0` says which .NET API surface your app targets. A RID answers a different question: *where will it run?* That includes the operating system and usually the architecture, for example `linux-x64` or `win-arm64`.

You need a RID whenever the build or publish must pick runtime-specific assets: native libraries, self-contained runtime packs, apphosts, or platform-specific publish output.

### The RID Graph and Fallback

The RID graph is a fallback model. If an exact match is not available, NuGet and the SDK can walk upward to less specific RIDs.

| Requested RID | Possible fallback chain |
|---|---|
| `linux-x64` | `linux-x64` → `linux` → `unix` → `any` |
| `win-arm64` | `win-arm64` → `win` → `any` |
| `osx-x64` | `osx-x64` → `osx` → `unix` → `any` |

That means a package author can ship native assets under `runtimes/linux-x64/native/` for a specific build or use broader folders when one asset works for multiple environments.

### NuGet Asset Selection

NuGet uses TFMs and RIDs together. A package may expose managed assemblies under `lib/net8.0/` and native assets under `runtimes/win-x64/native/`. Restore and publish combine that information to choose the most compatible set.

Portable RIDs such as `linux` are useful when the asset is not architecture-specific or when the goal is broad compatibility. Specific RIDs such as `linux-x64` are better when the binary truly depends on architecture or ABI details.

> Warning: a RID is not the same thing as a TFM. `net8.0-windows` expresses API availability at compile time; `win-x64` expresses runtime target at deploy time.

### Runtime Inspection and Practical Use

At runtime, `RuntimeInformation.RuntimeIdentifier` tells you what the current process is actually running on. That can be useful for diagnostics or conditional behavior, though most platform decisions should ideally happen at publish time rather than by branching at runtime.

### What Package Authors Should Remember

If you publish NuGet packages with native dependencies, the RID layout becomes part of your package design. Assets under `runtimes/` should be organized so the most specific binaries win, while still allowing sensible fallback when one binary can cover multiple targets. The goal is to let restore pick the narrowest compatible asset automatically. Interviewers like to hear that RIDs are not only an app-publish concern; they also shape how native interop libraries are packaged and consumed. It is also why incorrect RID folders can produce confusing “works on one agent, fails on another” restore behavior.

A good interview answer also connects RIDs to deployment modes: framework-dependent apps may not need an explicit RID, while self-contained publishes always do. For that broader picture, see [self-contained-vs-framework-dependent.md](./self-contained-vs-framework-dependent.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeSamples.Rids;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"Current RID: {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"OS: {RuntimeInformation.OSDescription}");
        Console.WriteLine($"Architecture: {RuntimeInformation.ProcessArchitecture}");

        if (OperatingSystem.IsWindows())
        {
            Console.WriteLine("Likely publishing target example: win-x64 or win-arm64.");
        }
        else if (OperatingSystem.IsLinux())
        {
            Console.WriteLine("Likely publishing target example: linux-x64 or linux-arm64.");
        }

        // NuGet chooses native assets from package folders such as:
        // runtimes/win-x64/native/
        // runtimes/linux-arm64/native/
    }
}
```

## Common Follow-up Questions

- Why does self-contained publishing require a RID?
- How does the RID graph help when a package lacks an exact runtime asset?
- What is the difference between `net8.0-windows` and `win-x64`?
- When should a package author use portable versus architecture-specific RIDs?
- Can `RuntimeInformation.RuntimeIdentifier` replace proper publish-time targeting?

## Common Mistakes / Pitfalls

- Mixing up TFMs and RIDs as if they solve the same problem.
- Publishing self-contained output without specifying the correct target RID.
- Assuming any Linux native asset works on every Linux architecture.
- Overusing runtime detection instead of publishing the right artifact for the target.
- Forgetting that package native assets live under `runtimes/`, not ordinary `lib/` folders.

## References

- [RID catalog — Microsoft Learn](https://learn.microsoft.com/dotnet/core/rid-catalog)
- [RuntimeInformation.RuntimeIdentifier — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.runtimeinformation.runtimeidentifier)
- [NuGet package asset selection](https://learn.microsoft.com/nuget/create-packages/native-files-in-net-packages)
- [Target frameworks in SDK-style projects — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/frameworks)
- [Deploy .NET apps — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/)
