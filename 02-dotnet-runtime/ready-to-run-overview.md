# ReadyToRun Overview

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟢 Middle
**Tags:** `ReadyToRun`, `R2R`, `crossgen2`, `startup`, `publish`, `composite`, `RID`

## Question

> What is ReadyToRun in .NET, and when would you use it?

Also asked as:
> How does `PublishReadyToRun=true` improve startup?
> If assemblies already contain native code, why can the runtime still fall back to JIT?

## Short Answer

ReadyToRun (R2R) is a deployment mode where assemblies are published with native code produced ahead of time, usually by `crossgen2`, while still keeping IL inside the assembly as a fallback. That often improves startup because fewer methods need first-use JIT compilation, but it increases publish size and usually does not beat fully optimized JIT code for long-running hot paths. R2R is best when startup matters more than package size and you still want the flexibility of the normal .NET runtime.

## Detailed Explanation

### What R2R Actually Produces

A normal .NET assembly contains IL and metadata. When you publish with:

```xml
<PublishReadyToRun>true</PublishReadyToRun>
```

or pass `-p:PublishReadyToRun=true`, the SDK invokes **crossgen2** to precompile methods into native code for a specific target runtime identifier (RID) such as `win-x64` or `linux-arm64`.

The resulting R2R image still contains IL. That matters because the runtime can fall back to the IL version if the precompiled native code is missing, not applicable, or a better runtime-specific choice is needed.

### Why Startup Improves

Without R2R, the first execution of each method typically pays JIT cost. With R2R, many methods already have native code available, so startup and first-request latency often improve.

| Deployment mode | Startup behavior |
|---|---|
| Normal JIT | Native code produced lazily at runtime |
| ReadyToRun | Many methods already precompiled |
| NativeAOT | Application published as native ahead of time |

R2R is especially useful for CLI tools, desktop apps, serverless functions, and services where cold start matters.

### Why R2R Does Not Eliminate the JIT

A common misconception is that R2R means “no JIT.” In reality, R2R and JIT often cooperate.

Reasons the runtime can still JIT include:

- a method was not precompiled
- generics or runtime context require specialized code
- the precompiled body is less suitable than a runtime-generated one
- certain dynamic scenarios are only resolved at runtime

So the correct mental model is: **R2R reduces JIT work; it does not necessarily remove it.** That is why it differs from NativeAOT.

### Trade-off: Startup vs File Size and Peak Throughput

R2R improves startup by moving part of the compilation cost from runtime to publish time, but there is no free lunch.

| Benefit | Cost |
|---|---|
| Faster startup / lower first-hit latency | Larger published assemblies |
| Less early JIT work | Longer publish time |
| Good deployment flexibility | Hot code may still be re-JITed for better optimization |

In some long-running workloads, the JIT can eventually produce better machine code because it knows more about the actual environment and execution profile. That is why R2R is usually a startup optimization, not a universal performance win.

> **Warning:** Always benchmark your actual deployment scenario. R2R helps many apps, but the gain varies widely by workload size, dependency graph, and cold-start profile.

### Composite ReadyToRun

For multi-assembly applications, **composite R2R** can compile multiple assemblies together. That gives cross-assembly optimization opportunities and can improve startup further, especially for self-contained deployments with many dependencies.

The trade-off is even bigger output and more complex publishing. Composite mode is a tuning option, not a default you should enable blindly.

### RID and Portability Limitations

R2R output is target-specific. A `win-x64` R2R binary is not the same as `linux-x64` or `win-arm64`. If the target RID changes, you need a different publish output.

This is an important interview point: R2R is ahead-of-time for a **specific environment**, while ordinary IL assemblies remain broadly portable across supported runtimes.

### Interview Takeaway

The best short explanation is: ReadyToRun uses crossgen2 to embed precompiled native code into assemblies for a target RID, keeps IL for fallback, usually improves startup, increases file size, and still allows the runtime to JIT when needed. See [jit-compilation-basics.md](./jit-compilation-basics.md) and [native-aot-overview.md](./native-aot-overview.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace RuntimeSamples;

public static class ReadyToRunDemo
{
    public static void Main()
    {
        Console.WriteLine($"Framework: {RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"RID target at publish time matters for R2R output.");
        Console.WriteLine("Publish command example:");
        Console.WriteLine("dotnet publish -c Release -r win-x64 -p:PublishReadyToRun=true");
        Console.WriteLine("Composite example:");
        Console.WriteLine("dotnet publish -c Release -r win-x64 -p:PublishReadyToRun=true -p:PublishReadyToRunComposite=true");
    }
}
```

## Common Follow-up Questions

- Why does ReadyToRun still keep IL in the assembly?
- How is R2R different from NativeAOT?
- Why can a ReadyToRun application still trigger JIT compilation?
- What is composite ReadyToRun and when might it help?
- Why does the target RID matter for R2R publishing?

## Common Mistakes / Pitfalls

- Assuming R2R means the JIT is completely unused at runtime.
- Enabling R2R without measuring cold-start benefit versus package-size growth.
- Forgetting that R2R output is RID-specific.
- Expecting R2R to always outperform optimized Tier 1 JIT code in long-running workloads.
- Using composite R2R by default without checking deployment size and publish-time cost.

## References

- [ReadyToRun deployment overview](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [crossgen2 overview in dotnet/runtime](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/crossgen2-overview.md)
- [Compilation runtime configuration options for .NET](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
- [Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [dotnet publish command](https://learn.microsoft.com/dotnet/core/tools/dotnet-publish)
