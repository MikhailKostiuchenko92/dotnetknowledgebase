# How Do You Configure the .NET Runtime?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `runtimeconfig.json`, `DOTNET_`, `AppContext`, `GC`, `environment variables`, `runtime options`

## Question

> How can you configure the .NET runtime — the GC, thread pool, JIT, and other CLR settings — at both the application level and the machine level?

Also asked as:
> What is `runtimeconfig.json` and what can you control with it?
> What are `DOTNET_` environment variables and which ones should every developer know?

## Short Answer

The .NET runtime is configured through three layered mechanisms: `runtimeconfig.json` (ship-time configuration embedded in the build), environment variables prefixed `DOTNET_` or `COMPLUS_` (override at deployment time), and `AppContext` switches (programmatic feature flags at startup). These control GC mode, thread pool sizing, JIT behaviour, tiered compilation, globalization, and more. Environment variables take precedence over `runtimeconfig.json` values.

## Detailed Explanation

### The Three Configuration Layers

| Layer | File / API | Precedence | Scope |
|-------|-----------|-----------|-------|
| `runtimeconfig.json` | `MyApp.runtimeconfig.json` | Lowest | Per-app, shipped with app |
| Environment variables | `DOTNET_GCHeapHardLimit`, etc. | Middle | Per-process or machine |
| `AppContext` switches | `AppContext.SetSwitch(...)` | Highest (code wins) | Per-process, set in code |

### `runtimeconfig.json` Structure

The SDK generates this file automatically from `<RuntimeHostConfigurationOption>` MSBuild properties or `runtimeconfig.template.json`:

```json
{
  "configProperties": {
    "System.GC.Server": true,
    "System.GC.HeapHardLimit": 1073741824,
    "System.Threading.ThreadPool.MinThreads": 4,
    "System.Threading.ThreadPool.MaxThreads": 100,
    "System.Runtime.TieredCompilation": true,
    "System.Globalization.Invariant": false
  }
}
```

Alternatively, set via MSBuild in the `.csproj`:

```xml
<RuntimeHostConfigurationOption Include="System.GC.Server" Value="true" Trim="true" />
```

### Key Configuration Categories

#### Garbage Collector

| Property / Env var | Effect |
|-------------------|--------|
| `System.GC.Server` / `DOTNET_GCServer` | `true` = Server GC (one heap per CPU core), `false` = Workstation GC |
| `System.GC.Concurrent` | `false` disables background GC (usually keep `true`) |
| `System.GC.HeapHardLimit` | Max managed heap bytes (hard cap; OOM if exceeded) |
| `System.GC.HeapHardLimitPercent` | HeapHardLimit as % of container memory (useful in containers) |
| `DOTNET_GCHeapHardLimitPercent` | Same via env var |
| `System.GC.HighMemoryPercent` | % of physical memory that triggers aggressive GC |

#### Thread Pool

| Property | Effect |
|----------|--------|
| `System.Threading.ThreadPool.MinThreads` | Minimum worker thread count |
| `System.Threading.ThreadPool.MaxThreads` | Maximum worker thread count |
| `System.Threading.ThreadPool.MinIOCompletionThreads` | Min I/O completion port threads |

#### JIT / Compilation

| Property | Effect |
|----------|--------|
| `System.Runtime.TieredCompilation` | Enable/disable tiered JIT (default: `true` in .NET 6+) |
| `System.Runtime.TieredCompilation.QuickJit` | Allow Tier 0 quick JIT (default: `true`) |
| `System.Runtime.TieredCompilation.QuickJitForLoops` | Quick JIT for methods with loops |
| `DOTNET_JitDisasm` | Method name pattern to dump JIT assembly output |

#### Globalization

| Property | Effect |
|----------|--------|
| `System.Globalization.Invariant` | `true` removes ICU dependency; smaller, but no locale-aware formatting |
| `System.Globalization.UseNls` | Use Windows NLS instead of ICU (Windows only) |

### Environment Variables

`DOTNET_` is the modern prefix (introduced .NET 6); `COMPLUS_` still works for backwards compatibility:

```bash
# Enable Server GC
DOTNET_GCServer=1

# Restrict heap to 512 MB (useful in containers)
DOTNET_GCHeapHardLimitPercent=50

# Thread pool tuning (rarely needed; let hill-climbing algorithm work)
DOTNET_ThreadPool_ForceMinWorkerThreads=8

# Debugging: log assembly loading
DOTNET_DIAG_DEFAULT_LOADER_TRACE=1
```

### `AppContext` Switches

Boolean feature flags flipped at startup (typically in `Program.cs` before any framework code runs):

```csharp
AppContext.SetSwitch("System.Net.Http.UseSocketsHttpHandler", true);
AppContext.SetSwitch("Switch.System.Threading.UseNetCoreTimer", false);

// Libraries check these via:
if (AppContext.TryGetSwitch("MyLibrary.FeatureX", out bool enabled) && enabled)
    // use feature X
```

> **Container best practice:** In containers, always set `DOTNET_GCHeapHardLimitPercent` (e.g., 75) to prevent the GC from thinking it has unlimited memory. Without it, the GC may see the host machine's RAM, not the container's cgroup limit.

## Code Example

```csharp
// Read effective configuration at runtime
bool isServerGC = System.Runtime.GCSettings.IsServerGC;
Console.WriteLine($"Server GC: {isServerGC}");

// GC memory info
GCMemoryInfo memInfo = GC.GetGCMemoryInfo();
Console.WriteLine($"Heap size limit: {memInfo.TotalAvailableMemoryBytes / 1024 / 1024} MB");
Console.WriteLine($"Memory load: {memInfo.MemoryLoadBytes / 1024 / 1024} MB");

// AppContext switch
AppContext.SetSwitch("System.Net.SocketsHttpHandler.Http3Support", true);
if (AppContext.TryGetSwitch("System.Net.SocketsHttpHandler.Http3Support", out bool http3))
    Console.WriteLine($"HTTP/3 switch: {http3}");

// Thread pool current settings
ThreadPool.GetMinThreads(out int minWorkers, out int minIO);
ThreadPool.GetMaxThreads(out int maxWorkers, out int maxIO);
Console.WriteLine($"ThreadPool: min={minWorkers}/{minIO}, max={maxWorkers}/{maxIO}");
```

```json
// runtimeconfig.template.json (placed in project root, merged into generated runtimeconfig.json)
{
  "configProperties": {
    "System.GC.Server": true,
    "System.GC.HeapHardLimitPercent": 75,
    "System.Threading.ThreadPool.MinThreads": 16
  }
}
```

## Common Follow-up Questions

- How does the runtime pick between Server and Workstation GC in a container environment?
- What is `DOTNET_DIAG_DEFAULT_LOADER_TRACE` and how do you use it to debug assembly-loading issues?
- How do `AppContext` switches interact with library code that checks them?
- What is the difference between `runtimeconfig.json` and `appsettings.json`?
- How do you set runtime config options for the test host in `dotnet test`?
- What GC tuning should you do for an ASP.NET Core app running in a 512 MB Docker container?

## Common Mistakes / Pitfalls

- **Forgetting container memory limits** — without `System.GC.HeapHardLimitPercent`, Server GC sees the host's total RAM and can OOM the container by allocating beyond the cgroup limit.
- **Using `COMPLUS_` prefix in new code** — it still works but `DOTNET_` is the correct modern prefix; some tools and dashboards look only for `DOTNET_` variables.
- **Setting `GC.Collect()` instead of configuring via runtimeconfig** — calling `GC.Collect()` repeatedly is a code smell; tuning GC via config is almost always better.
- **Confusing `runtimeconfig.json` with `appsettings.json`** — `runtimeconfig.json` is read by the CLR host before the app starts; `appsettings.json` is read by `IConfiguration` inside the app.
- **Setting `System.GC.Server=true` in a single-threaded / low-memory environment** — Server GC allocates one heap per CPU core; this wastes memory on small or heavily loaded machines.

## References

- [.NET runtime configuration settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/)
- [GC configuration settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)
- [Thread pool configuration settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/threading)
- [Configure .NET in containers — Microsoft Learn](https://learn.microsoft.com/dotnet/core/docker/configure-container)
- [AppContext.SetSwitch — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.appcontext.setswitch)
