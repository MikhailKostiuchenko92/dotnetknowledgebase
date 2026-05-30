# Self-Contained vs Framework-Dependent Deployment in .NET

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟢 Junior
**Tags:** `deployment`, `self-contained`, `framework-dependent`, `single-file`, `RID`

## Question

> What is the difference between framework-dependent and self-contained deployment in .NET?

Also asked as:
> When would you publish a .NET app as self-contained instead of relying on the machine's runtime?
> How do `PublishSingleFile`, trimming, and Native AOT relate to deployment size and startup?

## Short Answer

A framework-dependent deployment (FDD) ships your app and expects a compatible .NET runtime to already exist on the target machine, so the output is smaller and usually launched with `dotnet myapp.dll`. A self-contained deployment (SCD) bundles the runtime with the application, so it is larger but can run on a machine without a preinstalled runtime and often produces a platform-specific executable. Features such as `PublishSingleFile`, `PublishTrimmed`, and `PublishAot` build on those deployment modes to trade portability, size, startup time, and compatibility.

## Detailed Explanation

### Framework-Dependent Deployment (FDD)

FDD is the default for many internal apps and services. The publish output contains your app assemblies and configuration, but not the full runtime. The machine must already have a suitable shared framework installed. That makes deployment artifacts much smaller and patching the runtime centrally much easier.

The trade-off is operational dependency: if the runtime is missing or incompatible, the app will not start.

### Self-Contained Deployment (SCD)

SCD bundles the application together with the .NET runtime for a specific Runtime Identifier (RID) such as `win-x64` or `linux-arm64`. The result is larger, but it removes the requirement to preinstall .NET on the target. That is valuable for desktop distribution, locked-down servers, and predictable packaging.

| Mode | Pros | Cons |
|---|---|---|
| FDD | Small output, centralized runtime servicing | Requires runtime on machine |
| SCD | No runtime prerequisite, predictable environment | Larger publish size, per-RID builds |

### Single File, Trimming, and AOT

`PublishSingleFile=true` bundles publish output into one deployable file. That improves packaging simplicity, though some combinations of native libraries, extraction behavior, and startup policies still need careful testing. In modern .NET, pure managed content can often run directly from the bundle, but some assets may still extract to a cache or temp location depending on what the app contains.

`PublishTrimmed=true` removes unused code discovered by the trimmer, reducing size. `PublishAot=true` goes further by compiling ahead of time to native code for even smaller startup cost and different runtime characteristics. These features are powerful, but they can break reflection-heavy libraries unless the app is annotated correctly.

> Warning: do not turn on trimming or Native AOT just because they sound faster. Validate library compatibility, reflection usage, serializers, and source-generated alternatives first.

### Choosing in Practice

A simple rule of thumb is:

- Use FDD for servers where the runtime is managed centrally.
- Use SCD when you need a sealed artifact with no runtime prerequisite.
- Add single-file packaging when delivery simplicity matters.
- Add trimming or AOT only after compatibility review and measurement.

### Servicing and Security Trade-offs

Deployment mode also changes how runtime patches reach production. With FDD, a patched machine runtime can benefit multiple apps at once, which is attractive in centrally managed fleets. With SCD, each application carries its own runtime, so upgrading means republishing the app with a newer runtime version. That gives more isolation and predictability, but it also makes patch hygiene the application's responsibility. In other words, SCD reduces machine prerequisites while increasing artifact ownership.

This topic connects directly to [native-aot-overview.md](./native-aot-overview.md).

## Code Example

```csharp
using System.Reflection;
using System.Runtime.InteropServices;

namespace DotNetRuntimeSamples.DeploymentModes;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"Framework: {RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"RID: {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"Process path: {Environment.ProcessPath}"); // In SCD, this is often the platform-specific executable.
        Console.WriteLine($"Base directory: {AppContext.BaseDirectory}");
        Console.WriteLine($"Assembly location: {Assembly.GetExecutingAssembly().Location}"); // May differ in single-file scenarios.

        // Typical publish commands:
        // dotnet publish -c Release                       // FDD
        // dotnet publish -c Release -r win-x64 --self-contained true
        // dotnet publish -c Release -r linux-x64 -p:PublishSingleFile=true
        // dotnet publish -c Release -r linux-x64 -p:PublishTrimmed=true -p:PublishAot=true
    }
}
```

## Common Follow-up Questions

- Why does SCD require a RID while FDD often does not?
- What problems can trimming introduce in reflection-heavy apps?
- Does single-file always mean zero extraction on startup?
- When is Native AOT a better fit than regular JIT publishing?
- How do security patching and runtime servicing differ between FDD and SCD?

## Common Mistakes / Pitfalls

- Assuming SCD is always better because it is more portable.
- Turning on trimming without testing serializers, DI, reflection, or plugin loading.
- Forgetting that every SCD publish is platform-specific.
- Treating single-file as purely a packaging choice when it can affect file access assumptions.
- Using FDD on machines where runtime installation is not controlled.

## References

- [Deploy .NET apps — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/)
- [Single-file deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/single-file/)
- [Trim self-contained deployments — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/trimming/trim-self-contained)
- [Native AOT deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [RID catalog — Microsoft Learn](https://learn.microsoft.com/dotnet/core/rid-catalog)
