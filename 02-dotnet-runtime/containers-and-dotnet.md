# How Do Containers Work with .NET Applications?

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟡 Middle
**Tags:** `containers`, `Docker`, `PublishContainer`, `GC`, `chiseled-images`

## Question

> What should you know about running .NET applications in containers?

Also asked as:
> How do .NET SDK container publishing and multi-stage Dockerfiles differ?
> How does the GC behave under container memory limits?

## Short Answer

.NET works well in containers, but deployment choices affect image size, startup, diagnostics, and memory behavior. You can build images with the SDK using `dotnet publish --os linux --arch x64 /t:PublishContainer` or with a multi-stage Dockerfile that compiles in an SDK image and runs in a smaller runtime image. In containerized environments, the GC should be configured with container-aware limits such as `DOTNET_GCHeapHardLimitPercent` or runtimeconfig settings, and minimal base images like chiseled Ubuntu reduce attack surface but remove tools such as a shell.

## Detailed Explanation

### Two Common Build Paths

The traditional approach is a multi-stage Dockerfile: use `mcr.microsoft.com/dotnet/sdk:8.0` to restore and publish, then copy the output into `mcr.microsoft.com/dotnet/runtime:8.0` or `mcr.microsoft.com/dotnet/aspnet:8.0`. That keeps build tooling out of the final image.

The newer SDK-integrated approach uses `Microsoft.NET.Build.Containers`, so the SDK can emit an OCI image directly with `dotnet publish --os linux --arch x64 /t:PublishContainer`. This is convenient for simple pipelines and avoids maintaining a Dockerfile when you do not need custom layering.

| Image type | Use case |
|---|---|
| `sdk` | Build and test only |
| `runtime` | Console or worker app |
| `aspnet` | ASP.NET Core app with web stack |
| Chiseled images | Minimal hardened runtime base |

### Container-Aware GC

Containers often impose memory limits lower than the host capacity. Modern .NET can respect those limits, but you should still think explicitly about GC behavior. Environment variables such as `DOTNET_GCHeapHardLimitPercent` or runtimeconfig settings like `System.GC.HeapHardLimitPercent` constrain heap growth relative to the container budget.

That matters because “works on my laptop” memory behavior can turn into OOM kills in Kubernetes if the app assumes the full host memory is available.

### Base Image Choice

`runtime:8.0` is appropriate for non-web apps, while `aspnet:8.0` includes the ASP.NET Core shared framework. Chiseled images are stripped-down Ubuntu-based images designed for minimal footprint and reduced attack surface. They are excellent for production hardening, but they intentionally omit conveniences such as a shell or package manager.

> Warning: minimal images improve security and size, but they can make live debugging harder. Plan diagnostics and health endpoints before choosing a shell-less production image.

### Practical Trade-offs

A good answer should mention that containers change not only packaging but also runtime assumptions: filesystem layout, PID 1 behavior, memory limits, and diagnostics access.

### Operational Differences from VM or Bare-Metal Hosting

Containerized apps are easier to move, but the runtime environment is tighter and more opinionated. Process shutdown may come from orchestration signals, writable storage may be ephemeral, and attaching diagnostics tools may require extra capabilities or sidecar workflows. That means production readiness in containers is not only about building the image; it is also about health probes, graceful shutdown, stdout/stderr logging, and an explicit memory budget. Strong interview answers mention those operational details, not only Dockerfile syntax. The best container image is the one your platform team can operate safely and diagnose predictably every day.
For GC trade-offs, see [gc-server-vs-workstation.md](./gc-server-vs-workstation.md). For runtime knobs, see [runtime-configuration.md](./runtime-configuration.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeSamples.Containers;

internal static class Program
{
    private static void Main()
    {
        string? gcLimit = Environment.GetEnvironmentVariable("DOTNET_GCHeapHardLimitPercent");

        Console.WriteLine($"Framework: {RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"RID: {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"Container GC hard limit %: {gcLimit ?? "not set"}");
        Console.WriteLine($"Heap bytes: {GC.GetGCMemoryInfo().HeapSizeBytes}");

        // SDK container publish:
        // dotnet publish --os linux --arch x64 /t:PublishContainer

        // Runtimeconfig alternative:
        // {
        //   "configProperties": {
        //     "System.GC.HeapHardLimitPercent": 60
        //   }
        // }
    }
}
```

## Common Follow-up Questions

- When would you choose `runtime` versus `aspnet` base images?
- What are the advantages of a multi-stage Dockerfile?
- Why do container memory limits matter to the GC?
- What are the trade-offs of chiseled images?
- When is SDK-based container publishing enough without a handwritten Dockerfile?

## Common Mistakes / Pitfalls

- Shipping production images from the `sdk` base instead of a smaller runtime base.
- Ignoring container memory limits and getting OOM kills under load.
- Assuming chiseled images behave like regular Ubuntu images with a shell and package manager.
- Treating containerization as only a packaging concern and forgetting diagnostics and health management.
- Using one image strategy for all apps instead of matching image type to workload.

## References

- [Containerize a .NET app — Microsoft Learn](https://learn.microsoft.com/dotnet/core/docker/build-container)
- [Publish .NET app as a container image — Microsoft Learn](https://learn.microsoft.com/dotnet/core/containers/sdk-publish)
- [Official .NET container images](https://learn.microsoft.com/dotnet/core/docker/container-images)
- [Runtime configuration options for GC — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)
- [Chiseled Ubuntu container images for .NET](https://learn.microsoft.com/dotnet/core/docker/container-images#ubuntu-chiseled-images)
