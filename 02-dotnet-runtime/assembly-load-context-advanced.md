# Advanced AssemblyLoadContext: Collectibility, Unloading, and Dependency Isolation

**Category:** .NET Runtime / CLR
**Difficulty:** 🔴 Senior
**Tags:** `AssemblyLoadContext`, `collectible`, `unloading`, `plugin`, `dependency isolation`, `WeakReference`

## Question

> What are collectible `AssemblyLoadContext`s, and what are the constraints and pitfalls of using them for hot-reload or plugin scenarios?

Also asked as:
> Why does an `AssemblyLoadContext.Unload()` call not immediately release memory?
> What prevents a collectible ALC from being garbage-collected even after `Unload()` is called?

## Short Answer

A collectible `AssemblyLoadContext` (`isCollectible: true`) can be unloaded, allowing the CLR to reclaim the memory occupied by its assemblies, types, and JIT-compiled code. `Unload()` is merely a signal — the ALC is released when the GC determines no references to any of its types or instances remain. The most common trap is retaining references via statics, thread-local storage, reflection caches, or event handler delegates, which silently prevent collection and cause memory leaks.

## Detailed Explanation

### Collectible vs Non-Collectible ALCs

| Aspect | Non-collectible (default) | Collectible |
|--------|--------------------------|-------------|
| Created with | `new AssemblyLoadContext("name")` | `new AssemblyLoadContext("name", isCollectible: true)` |
| Can call `Unload()` | ❌ Throws `InvalidOperationException` | ✅ Yes |
| Memory released | Only on process exit | On GC after all references dropped |
| P/Invoke (native DLLs) | ✅ Allowed | ❌ Not allowed — OS cannot unload native DLLs on demand |
| `[DllImport]` static methods | ✅ Allowed | ❌ Throws on definition |
| Performance overhead | Lower | Slightly higher (weaker roots for types) |

### What Holds References (Blocks Unload)

After `ctx.Unload()`, the ALC is collected only when these are gone:

1. **Static fields** in types from the ALC — most common leak. `static` fields on a type keep the type alive, which keeps the ALC alive.
2. **Delegate references** — event handlers that capture plugin objects hold the type alive via the delegate's target.
3. **Thread-local storage** — `[ThreadStatic]` or `ThreadLocal<T>` referencing plugin types.
4. **Cached reflection objects** — `MethodInfo`, `Type`, `PropertyInfo` objects stored outside the ALC.
5. **`async` continuations** — tasks awaiting completion with captured state from the plugin.
6. **GC handles** — `GCHandle.Alloc` for objects in the ALC without corresponding `GCHandle.Free`.

### Diagnosing a Leaked ALC

Use `WeakReference` to monitor whether the ALC was collected:

```csharp
WeakReference<AssemblyLoadContext> weakCtx;

void LoadAndUnload()
{
    var ctx = new PluginLoadContext("/plugins/A.dll");
    weakCtx = new WeakReference<AssemblyLoadContext>(ctx);
    // ... use plugin ...
    ctx.Unload();
}

LoadAndUnload();

// Force multiple GC cycles (required — the ALC may need several passes)
for (int i = 0; i < 10; i++)
{
    GC.Collect();
    GC.WaitForPendingFinalizers();
}

if (weakCtx.TryGetTarget(out _))
    Console.WriteLine("⚠ ALC still alive — check for retained references");
else
    Console.WriteLine("✅ ALC successfully collected");
```

> Run `LoadAndUnload()` in a separate method so the JIT doesn't keep local variables alive via register references — a subtle but real issue in Debug builds.

### The Weaver Pattern (Safe Cross-ALC Communication)

Share only interfaces defined in the Default ALC; never share concrete types from the plugin ALC:

```
Default ALC
  └── IPlugin.dll  (interface only — never collectible)

PluginALC (collectible)
  └── PluginA.dll  implements IPlugin
```

Cast to `IPlugin` once; store only the interface reference. Dropping the interface reference allows the ALC to be collected.

### Reflection Caches Are a Hidden Trap

```csharp
// Bug: storing Type from a collectible ALC prevents collection
private static readonly Dictionary<string, Type> _typeCache = new();

void RegisterPlugin(Assembly asm)
{
    foreach (Type t in asm.GetExportedTypes())
        _typeCache[t.Name] = t;   // ← holds the Type → holds the ALC
}
```

Fix: clear `_typeCache` entries before calling `ctx.Unload()`.

### Native DLL Constraint

Collectible ALCs cannot define P/Invoke methods. If a plugin needs native interop, move the native layer to a non-collectible intermediary assembly, or accept that the native DLL will remain loaded (pin it in a non-collectible ALC).

```csharp
// This throws InvalidOperationException for a collectible ALC:
// [DllImport("native.dll")] static extern int NativeCall();
```

## Code Example

```csharp
using System.Runtime.Loader;
using System.Reflection;

interface IPlugin { void Run(); }

// Safe hot-reload loop
WeakReference? weakAlc = null;

for (int reload = 0; reload < 3; reload++)
{
    // Verify previous ALC was collected
    if (weakAlc is not null)
    {
        for (int gc = 0; gc < 8 && weakAlc.IsAlive; gc++)
        {
            GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced);
            GC.WaitForPendingFinalizers();
        }
        Console.WriteLine($"Reload {reload}: previous ALC alive={weakAlc.IsAlive}");
    }

    // Load in an isolated method so locals are out of scope before GC
    IPlugin plugin = LoadPlugin(out weakAlc);
    plugin.Run();
}

static IPlugin LoadPlugin(out WeakReference alcRef)
{
    var ctx = new AssemblyLoadContext($"Plugin-{Guid.NewGuid():N}", isCollectible: true);
    alcRef = new WeakReference(ctx);

    Assembly asm = ctx.LoadFromAssemblyPath(
        Path.GetFullPath("SamplePlugin/SamplePlugin.dll"));

    Type t = asm.GetType("SamplePlugin.SamplePlugin")
        ?? throw new InvalidOperationException("Type not found");

    IPlugin plugin = (IPlugin)Activator.CreateInstance(t)!;
    ctx.Unload(); // signal — not immediate

    return plugin; // ← returning instance keeps ALC alive until caller drops it
}
```

## Common Follow-up Questions

- How do you hot-reload a plugin without restarting the host process?
- What is the relationship between `WeakReference<T>` and GC finalizers in the unload cycle?
- How do ASP.NET Core's hot-reload (`dotnet watch`) and Razor hot-reload use ALCs internally?
- What GC mode (Server vs Workstation) affects ALC unload timing?
- Is there a way to force synchronous unloading of an ALC?
- How does `AssemblyLoadContext.Unloading` event help with cleanup?

## Common Mistakes / Pitfalls

- **Not calling `LoadAndUnload()` in a separate stack frame** — in Debug builds, the JIT may keep local variables alive in registers longer than expected, preventing ALC collection. Always isolate the load/use cycle in a separate method.
- **Subscribing to `AppDomain.CurrentDomain.AssemblyResolve` inside a collectible ALC** — the event fires via the AppDomain, which is in the Default scope; the handler closure captures the plugin's ALC, preventing collection.
- **Holding `Type` or `MethodInfo` objects outside the ALC** — these are rooted in the type metadata, which is rooted in the assembly, which holds the ALC alive.
- **Using `GC.Collect()` only once** — the ALC is typically at Gen2; it requires at least one Gen2 collection. `GCCollectionMode.Forced` with `GC.MaxGeneration` and `WaitForPendingFinalizers` is the reliable pattern.
- **Defining P/Invoke in a collectible ALC** — this throws `InvalidOperationException`. The restriction exists because the OS has no reliable way to unload native DLLs mid-process.

## References

- [Collectible assemblies for dynamic type generation — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/reflection-and-codedom/collectible-assemblies)
- [Unloadability in .NET Core 3.0 — .NET Blog](https://devblogs.microsoft.com/dotnet/assembly-unloadability-in-net-core-3-0/)
- [AssemblyLoadContext.Unload — .NET API](https://learn.microsoft.com/dotnet/api/system.runtime.loader.assemblyloadcontext.unload)
- [Plugin system with AssemblyLoadContext — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tutorials/creating-app-with-plugin-support)
- [See also: assembly-load-context-basics.md](./assembly-load-context-basics.md)
