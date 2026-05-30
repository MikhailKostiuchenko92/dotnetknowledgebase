# How Does .NET Resolve and Load Assemblies at Runtime?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `assembly loading`, `binding`, `AssemblyLoadContext`, `probing`, `fusion`

## Question

> How does the .NET runtime resolve and load assemblies when your application runs? What happens when the same assembly is referenced with different versions?

Also asked as:
> What is the assembly probing process?
> How do binding redirects work, and why are they needed?

## Short Answer

When the CLR needs an assembly, it asks the current `AssemblyLoadContext` (ALC) to resolve it. The default ALC searches the application's base directory and sub-directories listed in `runtimeconfig.json` / `deps.json`, then falls back to the shared framework store. In .NET Framework, binding redirects in `app.config` could redirect a request for version X to version Y; in .NET Core, the equivalent is `rollForward` policy in `runtimeconfig.json`. If resolution fails, a `FileNotFoundException` or `FileLoadException` is thrown.

## Detailed Explanation

### Resolution Order in .NET Core / .NET 5+

The `AssemblyLoadContext.Default` uses this sequence for a given `AssemblyName`:

1. **Already loaded?** — check the ALC's internal table; return cached assembly if present
2. **`AppContext.BaseDirectory`** — look for `<name>.dll` in the app's root folder
3. **`deps.json` probing paths** — SDK-generated file lists all NuGet package assets and their relative paths
4. **Shared framework** — check `Microsoft.NETCore.App` / `Microsoft.AspNetCore.App` stores
5. **`Resolving` event** — if all else fails, fire `AssemblyLoadContext.Default.Resolving` for custom resolution
6. **Fail** — `FileNotFoundException`

```
Request for: Newtonsoft.Json, Version=13.0.0.0
    │
    ├─ Already in ALC? → return cached
    ├─ AppBase dir?    → MyApp/Newtonsoft.Json.dll  ✓ found → load
    ├─ deps.json?      → lists package asset path    ✓ found → load
    ├─ Shared store?   → not a framework assembly   ✗
    └─ Resolving event → custom handler              ✗
         ↓
    FileNotFoundException
```

### Binding Redirects (.NET Framework)

In .NET Framework, if App A references `Newtonsoft.Json 9.0` and Library B references `Newtonsoft.Json 13.0`, the CLR's "Fusion" binder would normally load both, causing two type identities for the same types — leading to runtime cast failures.

The fix was a binding redirect in `app.config`:

```xml
<assemblyBinding>
  <dependentAssembly>
    <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" />
    <bindingRedirect oldVersion="0.0.0.0-12.0.0.0" newVersion="13.0.0.0" />
  </dependentAssembly>
</assemblyBinding>
```

This redirects any request for versions 0–12 to version 13.

### Roll-Forward Policy (.NET Core)

.NET Core doesn't have binding redirects. Instead, `runtimeconfig.json` has a `rollForward` policy controlling which installed runtime version an app uses:

| Policy | Meaning |
|--------|---------|
| `patch` | Latest patch of same major.minor |
| `minor` (default) | Latest minor of same major |
| `major` | Latest major installed |
| `disable` | Exact version only; fail if not present |
| `latestMajor` | Latest installed runtime |

For library assembly version mismatches, NuGet handles unification at build time by selecting a single version for the dependency graph.

### Custom Assembly Resolution

For plugin systems or dynamic loading, attach to the `Resolving` event:

```csharp
AssemblyLoadContext.Default.Resolving += (context, name) =>
{
    string path = Path.Combine("/plugins", $"{name.Name}.dll");
    return File.Exists(path) ? context.LoadFromAssemblyPath(path) : null;
};
```

Or use a custom `AssemblyLoadContext` for full isolation (see [assembly-load-context-basics.md](./assembly-load-context-basics.md)).

### The Type Identity Problem

The CLR considers two types identical only if:
1. Same full name
2. Loaded by the **same** `AssemblyLoadContext`

If the same assembly is loaded by two different ALCs, their types are **distinct** — you can't cast between them. This is a common pitfall in plugin architectures.

> **Debugging tip:** Enable assembly binding logging with `DOTNET_DIAG_DEFAULT_LOADER_TRACE=1` or attach a `Resolving` event to log where each assembly is found.

## Code Example

```csharp
using System.Reflection;

// Inspect what's loaded in the default context
foreach (Assembly a in AppDomain.CurrentDomain.GetAssemblies())
    Console.WriteLine($"{a.GetName().Name,-40} {a.GetName().Version}");

// Manually load an assembly from a path
Assembly plugin = Assembly.LoadFrom("/path/to/Plugin.dll");
// ⚠ LoadFrom uses a different context than LoadFile — prefer AssemblyLoadContext

// Custom resolving for assemblies not on the probing path
AssemblyLoadContext.Default.Resolving += (ctx, name) =>
{
    Console.WriteLine($"Resolving: {name.FullName}");
    return null; // let default logic proceed
};

// Check if an assembly is already loaded (avoid double-loading)
AssemblyName target = new("Newtonsoft.Json");
Assembly? existing = AppDomain.CurrentDomain
    .GetAssemblies()
    .FirstOrDefault(a => a.GetName().Name == target.Name);

Console.WriteLine(existing is not null
    ? $"Already loaded: {existing.Location}"
    : "Not yet loaded");
```

## Common Follow-up Questions

- What is `AssemblyLoadContext` and how does it enable true assembly isolation?
- What is the difference between `Assembly.Load`, `Assembly.LoadFrom`, and `Assembly.LoadFile`?
- How do you implement a plugin system that can load and **unload** assemblies?
- What happens when two plugins depend on different versions of the same NuGet package?
- What does `deps.json` contain and how does the runtime use it?
- How do you debug an assembly binding failure (`FileNotFoundException` on a library that clearly exists)?

## Common Mistakes / Pitfalls

- **Using `Assembly.LoadFrom` in a plugin system** — `LoadFrom` uses a "LoadFrom context" that bypasses the default ALC; you can end up with two type identities for the same type.
- **Ignoring `AssemblyLoadContext` isolation** — types from different ALCs are incompatible even if from the same assembly file. Always share interfaces via a neutral "contracts" assembly loaded in the default context.
- **Relying on `AppDomain.GetAssemblies()` to detect all loaded assemblies** — assemblies loaded in isolated ALCs are not visible in the AppDomain list unless they explicitly surface there.
- **Binding redirects in .NET Core** — `app.config` binding redirects are silently ignored in .NET Core. Use NuGet dependency resolution instead.
- **Not handling the `Resolving` event** — without a fallback, missing assemblies produce cryptic `FileNotFoundException` messages that can be hard to diagnose in production.

## References

- [How the runtime locates assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/deployment/how-the-runtime-locates-assemblies)
- [AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/dependency-loading/understanding-assemblyloadcontext)
- [.NET dependency loading — Microsoft Learn](https://learn.microsoft.com/dotnet/core/dependency-loading/default-probing)
- [Runtime roll-forward policy — Microsoft Learn](https://learn.microsoft.com/dotnet/core/versions/selection)
- [Creating a plugin system with AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tutorials/creating-app-with-plugin-support)
