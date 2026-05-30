# What Happens When a .NET Application Starts?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `CLR startup`, `hostfxr`, `coreclr`, `Program.cs`, `type initialization`, `startup hooks`

## Question

> Walk me through the sequence of events from the moment you run `dotnet MyApp.dll` to the first line of code in `Main` executing.

Also asked as:
> What is `hostfxr` and what role does it play in .NET startup?
> What are startup hooks and when would you use them?

## Short Answer

Running `dotnet MyApp.dll` invokes the `dotnet` host, which loads `hostfxr.dll` to resolve runtime configuration, then `hostpolicy.dll` to select the correct CLR version, and finally `coreclr.dll` (the actual .NET runtime). The CLR initialises the GC, thread pool, and type system, creates a default AppDomain, resolves and loads the entry-point assembly, resolves startup hooks, runs type initializers, and then calls `Main`. The whole process from process creation to `Main` is typically under 100 ms for a simple app on a warm machine.

## Detailed Explanation

### The Host Layer Stack

```
OS: CreateProcess("dotnet.exe MyApp.dll")
    │
    ▼
dotnet.exe (the "muxer" / multi-purpose host)
    │  reads MyApp.runtimeconfig.json
    │  loads hostfxr.dll  (version resolver)
    │
    ▼
hostfxr.dll
    │  selects .NET runtime version (rollForward policy)
    │  loads hostpolicy.dll from the selected runtime store
    │
    ▼
hostpolicy.dll
    │  resolves deps.json  (NuGet asset paths, TPA list)
    │  loads coreclr.dll (the actual CLR)
    │
    ▼
coreclr.dll  ← the Common Language Runtime
    │  initialises GC, thread pool, type system
    │  executes startup hooks
    │  loads and JITs entry-point assembly
    │
    ▼
Program.Main / top-level statements
```

### Why Three Layers?

This layered design lets the host be upgraded independently of the runtime:
- `dotnet.exe` (muxer) is installed once; it can load any runtime version
- `hostfxr` is per-runtime; selecting the right version is its sole job
- `hostpolicy` is per-app; it carries app-specific configuration (TPA list, deps.json)

### What `coreclr` Initialises at Startup

1. **Garbage Collector** — decides Server vs Workstation mode from config; reserves virtual memory for the managed heap
2. **Thread Pool** — creates minimum worker threads (configurable); I/O completion port threads (Windows) or epoll/kqueue threads (Linux/macOS)
3. **Type System** — loads `System.Private.CoreLib` (the corlib); initialises built-in types (Object, ValueType, etc.)
4. **Assembly Load Context** — creates the `Default` ALC; loads the "Trusted Platform Assemblies" (framework DLLs listed by hostpolicy)
5. **Entry Assembly** — loads the app's entry-point assembly; locates the `[EntryPoint]` method token
6. **Type Initializers (`.cctor`)** — the CLR runs static constructors of types that are accessed before `Main`; this is often where "startup" slowness hides

### Startup Hooks

A startup hook is a class in a separate assembly that runs *before* `Main`, injected via environment variable:

```bash
DOTNET_STARTUP_HOOKS=/path/to/StartupHook.dll
```

```csharp
// StartupHook.dll — must be exactly this class name and method signature
internal class StartupHook
{
    public static void Initialize()
    {
        // Runs before Main — instrument, patch, or configure the runtime
        Console.WriteLine("Startup hook running!");
    }
}
```

Use cases: APM agent injection (Datadog, OpenTelemetry auto-instrumentation), test hooks, diagnostic patching.

### ReadyToRun and Startup Performance

`PublishReadyToRun=true` (R2R) pre-compiles IL → native code at publish time using `crossgen2`. The CLR loads the pre-compiled native code directly without JIT on startup, dramatically reducing time-to-first-request. If no R2R image is found, it falls back to JIT.

### Measuring Startup Time

```bash
# Time to first output
time dotnet run --project MyApp

# More detailed: trace startup phases
DOTNET_PerfMapEnabled=1
dotnet-trace collect -p <PID> --clreventlevel info -- dotnet MyApp.dll
```

### Single-File Apps

With `PublishSingleFile=true`, all assemblies are bundled into a single native binary. On first run, the host extracts the bundle to a temp directory (unless `EnableCompressionInSingleFile` is false and assemblies are memory-mapped directly). Subsequent runs reuse the extracted directory.

## Code Example

```csharp
// Demonstrates when type initializers run (affects startup)
using System.Diagnostics;

var sw = Stopwatch.StartNew();

// This static constructor runs lazily on first use of HeavyClass,
// NOT necessarily at startup — unless the JIT/CLR decides otherwise
_ = HeavyClass.Instance;

Console.WriteLine($"Startup + first use: {sw.ElapsedMilliseconds} ms");

class HeavyClass
{
    // Static constructor — runs before any member of this class is accessed
    static HeavyClass()
    {
        Thread.Sleep(100); // simulate heavy init
        Console.WriteLine("  HeavyClass .cctor ran");
    }

    public static HeavyClass Instance { get; } = new();
}
```

```bash
# View effective runtimeconfig after hostfxr resolution
cat MyApp.runtimeconfig.dev.json  # generated only in Debug builds

# Set a startup hook (must be exact class/method name in the DLL)
export DOTNET_STARTUP_HOOKS=/opt/hooks/MyHook.dll
dotnet MyApp.dll
```

## Common Follow-up Questions

- What is the difference between `dotnet.exe` (muxer), `apphost.exe`, and `singlefilehost.exe`?
- How does the CLR decide between Server and Workstation GC at startup?
- What is the Trusted Platform Assemblies (TPA) list and how is it built?
- How do you reduce cold-start latency in an ASP.NET Core app or Lambda function?
- What is `DOTNET_STARTUP_HOOKS` used for in APM agents like Datadog or Elastic?
- How does .NET MAUI / mobile differ in startup sequence compared to desktop .NET?

## Common Mistakes / Pitfalls

- **Heavy static constructors slowing startup** — static constructors (`.cctor`) that do I/O, parse config, or spin up connections run synchronously before any member is accessed. Move heavy init to `Lazy<T>` or explicit `Initialize()` calls.
- **Assuming `Main` is the first thing that runs** — startup hooks (`DOTNET_STARTUP_HOOKS`) and global type initializers can run before `Main`.
- **Not using R2R for startup-sensitive applications** — without `PublishReadyToRun`, methods are JIT-compiled on first call; this causes spiky latency for the first few hundred requests.
- **Forgetting single-file extraction** — `PublishSingleFile` apps extract to disk on first run; the extract directory path (often temp) must be writable and is not cleaned up automatically.
- **Misunderstanding `dotnet.exe` vs `apphost.exe`** — published apps with `UseAppHost=true` (default) produce a platform-native host (`MyApp.exe`); `dotnet MyApp.dll` uses the muxer. They both go through the same `hostfxr` → `coreclr` pipeline.

## References

- [.NET host architecture — Microsoft Learn](https://learn.microsoft.com/dotnet/core/hosting/)
- [Write a custom .NET host — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tutorials/netcore-hosting)
- [Startup hooks — .NET runtime GitHub](https://github.com/dotnet/runtime/blob/main/docs/design/features/host-startup-hook.md)
- [ReadyToRun compilation — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [Diagnosing .NET startup performance — Andrew Lock's blog](https://andrewlock.net/exploring-the-dotnet-8-preview-avoiding-startup-delays-in-asp-net-core/) (verify URL)
