# What Is the Difference Between `dotnet build` and `dotnet publish`?

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟡 Middle
**Tags:** `dotnet-build`, `dotnet-publish`, `ReadyToRun`, `apphost`, `deployment`

## Question

> What is the difference between `dotnet build` and `dotnet publish`?

Also asked as:
> What extra artifacts does `dotnet publish` generate for deployment?
> How do publish properties such as `PublishReadyToRun`, `PublishTrimmed`, and `PublishSingleFile` affect the output folder?

## Short Answer

`dotnet build` compiles the project for development and produces normal build output under `bin\<Configuration>\<TFM>`, but it does not necessarily produce the final deployable layout. `dotnet publish` goes further by generating a deployment-ready folder, resolving runtime assets, copying configuration, producing an apphost executable when appropriate, and optionally applying features such as ReadyToRun, trimming, single-file bundling, or Native AOT. In other words, build is for compiling; publish is for shipping.

## Detailed Explanation

### `build` vs `publish`

`dotnet build` is the command you run during normal development, CI validation, or local iteration. It restores packages if needed, compiles code, runs source generators, and creates assemblies and related files that the SDK can execute locally.

`dotnet publish` includes the build step but also materializes the app as a deployment artifact. That means copying dependencies, runtime configuration, content files, and runtime-specific pieces into a coherent publish directory.

| Command | Primary goal | Typical output |
|---|---|---|
| `dotnet build` | Compile for development | `bin\Release\net8.0\` |
| `dotnet publish` | Produce deployment-ready output | `bin\Release\net8.0\publish\` or RID-specific publish folder |

### What Changes During Publish

Publishing can create an apphost executable, choose runtime-specific assets, and include self-contained runtime files if requested. In framework-dependent deployment, the output often includes `myapp.dll`, `myapp.runtimeconfig.json`, `myapp.deps.json`, and possibly an apphost executable. In self-contained deployment, the publish folder also includes the runtime, native dependencies, and other platform-specific artifacts.

The apphost is the native bootstrap executable generated for the target platform so the application can be started like a normal OS executable rather than always invoking `dotnet myapp.dll`.

### Important Publish Properties

`PublishReadyToRun=true` precompiles assemblies to improve startup or reduce some JIT work. `PublishTrimmed=true` removes unused code. `PublishSingleFile=true` bundles output into one artifact. `PublishAot=true` performs Native AOT compilation instead of standard IL + JIT deployment.

These features can be combined, but not blindly. For example, trimming and AOT require compatibility review, and ReadyToRun increases output size. Composite ReadyToRun images are another optimization variant for some scenarios.

> Warning: do not inspect only the build output and assume deployment will behave the same way. Publish-time transformations can change file layout, startup path assumptions, and compatibility characteristics.

### Practical Interview Framing

A strong answer usually says: use `build` to make code compile, use `publish` to create what you will actually deploy. Then mention that deployment mode, RID, and publish properties shape the final artifact.

### Why Teams Care in CI/CD

In CI/CD pipelines, this distinction affects artifact contracts. A build job may only prove that the code compiles and tests pass, while a publish job produces the exact payload handed to a release stage, container image, or deployment platform. When teams debug “works locally but fails in deployment,” the missing step is often that they tested build output but never inspected publish output. Calling out that difference shows you understand deployment as a packaging pipeline, not just a compiler command.

This topic connects to [self-contained-vs-framework-dependent.md](./self-contained-vs-framework-dependent.md) and [ready-to-run-overview.md](./ready-to-run-overview.md).

## Code Example

```csharp
using System.Reflection;
using System.Runtime.InteropServices;

namespace DotNetRuntimeSamples.PublishOutput;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"Framework: {RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"RID: {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"Process path: {Environment.ProcessPath}"); // Often the apphost executable in publish output.
        Console.WriteLine($"Base directory: {AppContext.BaseDirectory}"); // Useful for comparing build vs publish layouts.
        Console.WriteLine($"Entry assembly: {Assembly.GetEntryAssembly()?.Location}");

        // Example publish commands:
        // dotnet publish -c Release
        // dotnet publish -c Release -r linux-x64 --self-contained true
        // dotnet publish -c Release -r linux-x64 -p:PublishReadyToRun=true
        // dotnet publish -c Release -r linux-x64 -p:PublishTrimmed=true -p:PublishSingleFile=true
    }
}
```

## Common Follow-up Questions

- Why can `dotnet publish` produce different files than `dotnet build`?
- What is an apphost executable?
- When would you use ReadyToRun versus Native AOT?
- Why do publish properties need compatibility testing?
- How does the output differ between FDD and SCD publishes?

## Common Mistakes / Pitfalls

- Deploying plain build output and assuming it is equivalent to publish output.
- Turning on ReadyToRun, trimming, or single-file without measuring or validating behavior.
- Forgetting that RID-specific publishes can change asset selection.
- Treating the apphost as just another DLL when it is the native entry point wrapper.
- Ignoring the publish folder structure when code depends on relative file paths.

## References

- [dotnet build — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tools/dotnet-build)
- [dotnet publish — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tools/dotnet-publish)
- [ReadyToRun compilation — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [Single-file deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/single-file/)
- [Native AOT deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
