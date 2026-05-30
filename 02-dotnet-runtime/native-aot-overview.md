# What Is Native AOT in .NET?

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟡 Middle
**Tags:** `native aot`, `aot`, `publishing`, `trimming`, `source generators`

## Question

> What is Native AOT in .NET, and how is it different from normal JIT compilation?

Also asked as:
> When would you publish a .NET application with Native AOT instead of relying on the JIT?
> Compare JIT, ReadyToRun, and Native AOT in terms of startup, size, and runtime flexibility.

## Short Answer

Native AOT compiles IL to native machine code at publish time, so the application starts without running the JIT at runtime. That usually improves startup time, can reduce memory usage, and produces a self-contained native executable that doesn't ship IL in the usual way. The trade-off is flexibility: reflection-heavy code, runtime code generation, and other dynamic patterns often need redesigns or source generators.

## Detailed Explanation

### What Native AOT Changes in the Execution Model

A normal .NET application ships IL and metadata, then uses RyuJIT to compile methods to native code as they are first executed. Native AOT changes that model: publishing runs the IL Compiler (ILC) ahead of time and emits a native binary for a specific target runtime identifier (RID), so there is no general-purpose JIT compilation during startup or steady-state execution.

In practice, you enable it with `PublishAot=true` in the project file and publish for a concrete target such as `win-x64` or `linux-arm64`. Native AOT was introduced as a supported deployment model in .NET 7 and has improved in .NET 8 and .NET 9.

### Why Teams Use It

The main reason to choose Native AOT is operational efficiency:

| Benefit | Why it helps |
|---|---|
| Faster startup | The process begins in already-native code instead of waiting for cold methods to be JIT-compiled |
| Lower memory overhead | No JIT compiler needs to stay active, and less IL metadata may need to remain available |
| Small operational footprint | It combines well with trimming and single-file publishing |
| Distribution simplicity | You can ship a single native executable for the target platform |
| Reduced IL exposure | The deployed artifact is native code, not the usual IL assemblies |

This is especially attractive for short-lived CLI tools, serverless functions, utilities that must start instantly, and containerized services where cold start matters.

> Native AOT is not a universal “make it faster” switch. It usually helps startup and deployment footprint most; peak throughput may be similar to or lower than a warm JITed application depending on the workload.

### Why Reflection and Dynamic Features Become a Problem

The JIT can generate code on demand after the process has already started. Native AOT cannot do that, because the publish step must determine the code shape up front. That is why features such as runtime code generation, broad late-bound reflection, and unknown-type activation become constrained.

AOT-friendly applications replace runtime discovery with compile-time knowledge. Common examples:

- `System.Text.Json` source generation instead of reflection-based serialization metadata discovery.
- Source-generated regex instead of runtime regex compilation.
- DI registration patterns that avoid scanning unknown assemblies.
- Explicit type maps instead of “load any type by name and instantiate it”.

This is also why Native AOT is tightly related to [assembly-trimming.md](./assembly-trimming.md) and the deeper restrictions in [native-aot-constraints.md](./native-aot-constraints.md): once the linker removes unused code, only code reachable at publish time is safe to depend on.

### JIT vs R2R vs Native AOT

| Approach | When code becomes native | Startup | Runtime flexibility | Typical trade-off |
|---|---|---|---|---|
| JIT | At first execution of each method | Slowest cold start | Highest | Best compatibility and adaptive optimization |
| ReadyToRun (R2R) | Mostly at publish time, but JIT still available | Better than pure JIT | High | Good compromise; some methods still re-JIT |
| Native AOT | Entire publish output is native | Best cold start | Lowest | Strongest deployment gains, strongest compatibility constraints |

R2R is therefore a partial AOT story, while Native AOT is a full static compilation model.

### When It Is a Good Fit

Native AOT is a strong choice when the application is relatively closed-world: known entry points, known DTOs, limited plugin loading, and predictable reflection. It is a weak fit when the application behaves like a framework host, a scripting engine, or a plugin platform.

> Warning: if your architecture relies on `Assembly.Load`, runtime proxy generation, broad ORMs with heavy late-bound metadata inspection, or user-provided extension assemblies, treat Native AOT as an explicit design constraint, not a publish checkbox.

## Code Example

```csharp
// In the project file, enable Native AOT:
// <PublishAot>true</PublishAot>
// <InvariantGlobalization>true</InvariantGlobalization> // optional footprint optimization

using System.Text.Json;
using System.Text.Json.Serialization;

namespace RuntimeSamples.NativeAot;

internal sealed record WeatherForecast(string City, int TemperatureC, DateOnly Date);

[JsonSerializable(typeof(WeatherForecast))]
[JsonSerializable(typeof(WeatherForecast[]))]
internal partial class AppJsonContext : JsonSerializerContext;

internal static class Program
{
    private static void Main()
    {
        WeatherForecast[] forecasts =
        [
            new("Kyiv", 24, DateOnly.FromDateTime(DateTime.UtcNow)),
            new("Warsaw", 19, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(1)))
        ];

        // Source-generated metadata avoids reflection-heavy serializer discovery.
        string json = JsonSerializer.Serialize(forecasts, AppJsonContext.Default.WeatherForecastArray);
        Console.WriteLine(json);

        WeatherForecast[]? roundTrip = JsonSerializer.Deserialize(
            json,
            AppJsonContext.Default.WeatherForecastArray);

        Console.WriteLine($"Items deserialized: {roundTrip?.Length ?? 0}");
    }
}
```

## Common Follow-up Questions

- How is Native AOT different from ReadyToRun publishing?
- Why does trimming matter much more in Native AOT apps?
- Which reflection patterns are still safe under Native AOT?
- Why do source generators help AOT compatibility?
- Is Native AOT always faster than JIT for long-running services?

## Common Mistakes / Pitfalls

- Assuming Native AOT improves every metric; the biggest wins are usually startup and deployment characteristics, not always steady-state throughput.
- Treating `PublishAot=true` as enough without checking linker and ILC warnings.
- Using reflection-based serializers, DI scanning, or plugin loading patterns without AOT-safe alternatives.
- Forgetting that the output is target-specific and must be published for an exact RID.
- Ignoring the interaction between trimming and AOT, which can surface missing metadata only at publish time.

## References

- [Native AOT deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [Trim self-contained deployments and executables — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/trimming/trim-self-contained)
- [System.Text.Json source generation — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/source-generation)
- [Compilation config settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
