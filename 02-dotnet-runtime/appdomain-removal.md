# What Happened to AppDomain in .NET Core?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `AppDomain`, `AssemblyLoadContext`, `.NET Core`, `isolation`, `migration`

## Question

> AppDomain was the main isolation mechanism in .NET Framework. What happened to it in .NET Core, and what should you use instead?

Also asked as:
> Why can't you create new AppDomains in .NET Core?
> How do you migrate .NET Framework code that relied on AppDomain isolation to .NET Core?

## Short Answer

.NET Core supports only a single AppDomain per process. The multi-AppDomain APIs (`AppDomain.CreateDomain`, `AppDomain.Unload`) throw `PlatformNotSupportedException`. The two main use cases for AppDomains — assembly isolation and assembly unloading — are now served by `AssemblyLoadContext`. For true process isolation, you should use separate OS processes (e.g., `Process.Start`) or out-of-process communication (named pipes, gRPC).

## Detailed Explanation

### What AppDomain Did in .NET Framework

An `AppDomain` was a lightweight isolation boundary within a single process:

| Feature | How AppDomain provided it |
|---------|--------------------------|
| Assembly isolation | Each AppDomain had its own loaded assembly set |
| Object isolation | Cross-domain object access required marshalling (`MarshalByRefObject`) |
| Security isolation | Each domain had its own `CAS` (Code Access Security) policy |
| Fault isolation | An unhandled exception in one domain *theoretically* didn't crash others |
| Unloading | `AppDomain.Unload()` released all assemblies in that domain |

### Why .NET Core Dropped Multi-AppDomain Support

1. **Complexity without real process isolation** — AppDomains were *not* as isolated as separate processes. A native (unmanaged) crash in one domain crashed the whole process. The isolation was CLR-layer only.

2. **Performance overhead** — Every cross-domain call required marshalling through `MarshalByRefObject`, which was slow and complicated.

3. **Code Access Security was removed** — CAS was the main security use case for AppDomains. Without CAS, the security rationale evaporated.

4. **`AssemblyLoadContext` is a better tool** for assembly isolation — it's simpler, more explicit, and supports collectible (unloadable) assemblies without the full AppDomain machinery.

5. **True isolation = separate process** — The .NET team's position is: if you need hard fault isolation, use separate OS processes. The OS process boundary is the right abstraction.

### What Still Works in .NET Core

The `AppDomain` class is present but most of it is a stub:

| API | Status in .NET Core |
|-----|---------------------|
| `AppDomain.CurrentDomain` | ✅ Works — returns the single domain |
| `AppDomain.GetAssemblies()` | ✅ Works |
| `AppDomain.UnhandledException` | ✅ Works |
| `AppDomain.CreateDomain(...)` | ❌ Throws `PlatformNotSupportedException` |
| `AppDomain.Unload(domain)` | ❌ Throws `PlatformNotSupportedException` |
| `AppDomain.ExecuteAssembly(...)` | ❌ Throws on some overloads |
| `MarshalByRefObject` remoting | ❌ Removed; use gRPC, pipes, or `Process` |

### Migration Guide

| .NET Framework pattern | .NET Core replacement |
|-----------------------|----------------------|
| `AppDomain.CreateDomain` for plugin isolation | Custom `AssemblyLoadContext` |
| `AppDomain.Unload` to release plugin | Collectible `AssemblyLoadContext` + GC |
| `AppDomain.ExecuteAssembly` | `Assembly.LoadFrom` + reflection, or `dotnet run` |
| Cross-domain `MarshalByRefObject` | `System.IO.Pipes`, gRPC, `IPC Channel` |
| `AppDomain.UnhandledException` for global error handling | `AppDomain.CurrentDomain.UnhandledException` ✅ still works |

### Process Isolation as the Modern Approach

For workloads that require hard isolation (e.g., running untrusted code), the modern pattern is a separate process:

```csharp
// Isolated worker process pattern
var worker = new Process
{
    StartInfo = new ProcessStartInfo("dotnet", "Plugin.Worker.dll")
    {
        RedirectStandardInput = true,
        RedirectStandardOutput = true,
        UseShellExecute = false
    }
};
worker.Start();
// Communicate via stdin/stdout, named pipe, or gRPC
```

.NET's `Worker Service` template and frameworks like `Microsoft.Extensions.Hosting` make out-of-process plugin hosts straightforward.

## Code Example

```csharp
using System.Runtime.Loader;

// ── What still works ────────────────────────────────────────────
AppDomain current = AppDomain.CurrentDomain;
Console.WriteLine(current.FriendlyName);   // process name
Console.WriteLine(current.BaseDirectory);  // app base dir

// Global unhandled exception handler — still works
AppDomain.CurrentDomain.UnhandledException += (_, e) =>
    Console.Error.WriteLine($"Fatal: {e.ExceptionObject}");

// ── What throws PlatformNotSupportedException ───────────────────
try
{
    AppDomain isolated = AppDomain.CreateDomain("IsolatedDomain"); // ❌ throws
}
catch (PlatformNotSupportedException ex)
{
    Console.WriteLine($"Expected: {ex.Message}");
}

// ── The replacement: AssemblyLoadContext ────────────────────────
var ctx = new AssemblyLoadContext("PluginContext", isCollectible: true);
Assembly plugin = ctx.LoadFromAssemblyPath("/plugins/MyPlugin.dll");
// ... use plugin ...
ctx.Unload(); // equivalent to AppDomain.Unload in .NET Framework
```

## Common Follow-up Questions

- What is `AssemblyLoadContext` and how does collectibility work?
- If `AppDomain` isolation is gone, how do you safely run untrusted code in .NET Core?
- What happened to `MarshalByRefObject` and .NET Remoting?
- Can you use .NET Native or NativeAOT in the context of plugin loading?
- How does the `IsolatedStorage` API relate to AppDomain removal?
- What is `AppContext` and how is it different from `AppDomain`?

## Common Mistakes / Pitfalls

- **Calling `AppDomain.CreateDomain` in a .NET Core library** — this causes a `PlatformNotSupportedException` at runtime, not compile time. Add `#if NETFRAMEWORK` guards when writing multi-targeting libraries.
- **Assuming `AppDomain.CurrentDomain.GetAssemblies()` returns all loaded assemblies** — assemblies loaded into non-default ALCs are not returned by this API.
- **Using `MarshalByRefObject` for cross-"domain" communication** — .NET Remoting infrastructure is completely removed. Replace with `System.IO.Pipes`, gRPC, or message queues.
- **Relying on AppDomain to catch `ThreadAbortException`** — `Thread.Abort` is also removed in .NET Core. Use `CancellationToken` for cooperative cancellation.
- **Not realising `AppContext` is a different type** — `AppContext` is a lightweight context bag (`AppContext.SetSwitch`, `AppContext.TryGetSwitch`) unrelated to `AppDomain`.

## References

- [AppDomain — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.appdomain)
- [.NET Core application deployment and AppDomain — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/)
- [Porting from .NET Framework to .NET Core — AppDomain section — Microsoft Learn](https://learn.microsoft.com/dotnet/core/porting/)
- [AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/dependency-loading/understanding-assemblyloadcontext)
- [Remoting is not available in .NET Core — GitHub dotnet/runtime](https://github.com/dotnet/runtime/issues/21793) (verify URL)
