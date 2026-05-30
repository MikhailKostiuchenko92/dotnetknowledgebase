# What Is AssemblyLoadContext and How Does It Enable Plugin Architectures?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `AssemblyLoadContext`, `ALC`, `plugin`, `isolation`, `assembly loading`

## Question

> What is `AssemblyLoadContext`, and how do you use it to build a plugin system where each plugin can have its own dependency versions?

Also asked as:
> How does `AssemblyLoadContext` replace `AppDomain` for assembly isolation in .NET Core?
> What is "collectible" `AssemblyLoadContext`, and when would you use it?

## Short Answer

`AssemblyLoadContext` (ALC) is the .NET Core mechanism for loading assemblies into isolated scopes. Each ALC has its own set of loaded assemblies; the same assembly loaded in two different ALCs produces two distinct, incompatible type identities. This enables plugin systems where different plugins can depend on different versions of the same library. A *collectible* ALC can be unloaded, freeing all associated assemblies and types from memory — a capability AppDomain offered in .NET Framework.

## Detailed Explanation

### The Problem ALCs Solve

Without isolation, loading two plugins that each depend on `Newtonsoft.Json` but different versions would load only one version (whichever loads first), potentially breaking one plugin. ALCs solve this by giving each plugin its own loading scope.

### ALC Hierarchy

```
AssemblyLoadContext.Default
├── System.Private.CoreLib
├── System.Runtime
├── MyApp.exe
└── SharedContracts.dll   ← shared between all plugins

PluginALoadContext         ← custom ALC for Plugin A
├── Newtonsoft.Json 13.0  ← plugin's private copy
└── PluginA.dll

PluginBLoadContext         ← custom ALC for Plugin B
├── Newtonsoft.Json 9.0   ← different version, isolated
└── PluginB.dll
```

`SharedContracts.dll` is intentionally loaded in the Default context so plugin types can be cast to shared interfaces without type-identity problems.

### Type Identity Rule

Types are identical only if they come from the same ALC:

```csharp
// Both ALCs load the same file
Type tA = alcA.LoadFromAssemblyPath("Plugin.dll").GetType("Plugin.Foo");
Type tB = alcB.LoadFromAssemblyPath("Plugin.dll").GetType("Plugin.Foo");

bool same = tA == tB; // false — different ALCs, different type identities
```

### Implementing a Custom ALC

```csharp
class PluginLoadContext(string pluginDir) : AssemblyLoadContext(isCollectible: true)
{
    private readonly AssemblyDependencyResolver _resolver = new(pluginDir);

    protected override Assembly? Load(AssemblyName assemblyName)
    {
        // 1. Try to resolve from the plugin's own directory
        string? path = _resolver.ResolveAssemblyToPath(assemblyName);
        if (path is not null)
            return LoadFromAssemblyPath(path);

        // 2. Fall back to Default — for shared contracts and framework assemblies
        return null; // returning null delegates to Default
    }
}
```

The key design: shared contract assemblies (interfaces, DTOs) fall through to `null`, causing the CLR to use the Default ALC's already-loaded copy. Plugin-private assemblies are loaded from the plugin directory.

### Collectible ALCs and Unloading

A collectible ALC can be garbage-collected once no references to its assemblies or types remain:

```csharp
WeakReference weakRef;
{
    var ctx = new PluginLoadContext("/plugins/MyPlugin");
    weakRef = new WeakReference(ctx);
    var asm = ctx.LoadFromAssemblyPath("/plugins/MyPlugin/MyPlugin.dll");
    var plugin = (IPlugin)Activator.CreateInstance(asm.GetType("MyPlugin.Plugin")!)!;
    plugin.Execute();
    ctx.Unload(); // signal unload; actual release is GC-driven
}
// Force GC to collect the ALC (need several cycles in practice)
for (int i = 0; i < 10 && weakRef.IsAlive; i++)
{
    GC.Collect();
    GC.WaitForPendingFinalizers();
}
Console.WriteLine($"Plugin unloaded: {!weakRef.IsAlive}");
```

> **Important:** Unloading is not synchronous. The ALC is collected only when the GC determines there are no more references — including references held by statics, thread-local storage, or pending finalizers.

### When to Use a Custom ALC

| Scenario | Use custom ALC? |
|----------|----------------|
| Plugin system with version isolation | ✅ Yes |
| Hot-reload of code at runtime | ✅ Yes (collectible) |
| Loading the same assembly in two independent copies | ✅ Yes |
| Simple dynamic `Assembly.Load` within the same app | ❌ Default ALC sufficient |
| Script engines (Roslyn scripting) | ✅ Yes, collectible |

## Code Example

```csharp
using System.Reflection;
using System.Runtime.Loader;

// Define a shared contract loaded in Default ALC
// (In a real project, this lives in a separate 'Contracts' assembly)
interface IPlugin { string Name { get; } void Run(); }

// ------ Plugin host ------
string pluginPath = Path.GetFullPath("plugins/MyPlugin/MyPlugin.dll");
var ctx = new PluginLoadContext(pluginPath, isCollectible: true);
Assembly asm = ctx.LoadFromAssemblyPath(pluginPath);

Type pluginType = asm.GetTypes().First(t => t.IsAssignableTo(typeof(IPlugin)));
IPlugin plugin = (IPlugin)Activator.CreateInstance(pluginType)!;

Console.WriteLine($"Loaded: {plugin.Name}");
plugin.Run();

ctx.Unload();

// ------ Isolated ALC implementation ------
sealed class PluginLoadContext(string pluginPath, bool isCollectible = false)
    : AssemblyLoadContext(isCollectible: isCollectible)
{
    private readonly AssemblyDependencyResolver _resolver = new(pluginPath);

    protected override Assembly? Load(AssemblyName name)
    {
        string? path = _resolver.ResolveAssemblyToPath(name);
        return path is not null ? LoadFromAssemblyPath(path) : null;
        // null → delegate to Default ALC (shared contracts + framework)
    }
}
```

## Common Follow-up Questions

- What happens if a plugin holds a static reference to one of its types — can the ALC still be collected?
- How do you share data between a plugin and the host without shared type identity issues?
- What is `AssemblyDependencyResolver` and how does it use `.deps.json`?
- What are the limitations of collectible ALCs (e.g., no `[DllImport]` in collectible assemblies)?
- How does Roslyn scripting use ALCs internally?
- How does ASP.NET Core's hot-reload feature use ALCs?

## Common Mistakes / Pitfalls

- **Loading shared contracts in the plugin ALC** — if the contract assembly is loaded in both the Default and plugin ALCs, casts across the boundary fail. Always load contracts exclusively in Default.
- **Holding strong references after `Unload()`** — any live reference to an object from a collected ALC prevents the ALC from being GC'd. Use `WeakReference` to monitor unloading.
- **Assuming `ctx.Unload()` = immediate unload** — `Unload()` is a request; actual memory release requires GC collection. Several GC cycles may be needed.
- **Forgetting native (P/Invoke) DLLs** — native DLLs loaded by a collectible ALC via `LoadUnmanagedDll` cannot be unloaded on Windows; the process must restart. This constraint makes collectible ALCs unsuitable for scenarios that load native DLLs.
- **Not using `AssemblyDependencyResolver`** — without it, transitive dependencies of the plugin won't be found, causing `FileNotFoundException` for plugin-private packages.

## References

- [AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/dependency-loading/understanding-assemblyloadcontext)
- [Using AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/dependency-loading/collectible-assemblies)
- [Creating a plugin system with AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tutorials/creating-app-with-plugin-support)
- [Collectible assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/reflection-and-codedom/collectible-assemblies)
- [AssemblyDependencyResolver — .NET API](https://learn.microsoft.com/dotnet/api/system.runtime.loader.assemblydependencyresolver)
