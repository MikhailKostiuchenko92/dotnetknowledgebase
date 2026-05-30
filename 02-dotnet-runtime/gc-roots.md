# What Is a GC Root?

**Category:** .NET Runtime / GC
**Difficulty:** 🟢 Junior
**Tags:** `GC roots`, `garbage collection`, `reachability`, `stack`, `static fields`, `GC handles`

## Question

> What is a GC root, and what kinds of GC roots does the .NET runtime recognise?

Also asked as:
> Why does setting a local variable to `null` not always immediately make an object eligible for collection?
> How can an object appear to be unreachable in code but still not be collected?

## Short Answer

A GC root is any reference that the garbage collector treats as unconditionally alive — a starting point for the reachability trace. Objects reachable (directly or transitively) from any root survive collection; everything else is garbage. .NET recognises five root categories: stack variables and CPU registers, static fields, GC handles (including finalizer queue entries), thread-local storage, and interop handles. If a root you didn't intend (e.g., a forgotten static cache) keeps an object reachable, it will never be collected.

## Detailed Explanation

### The Five Root Categories

#### 1. Stack Variables and CPU Registers

Local variables in active method frames on the call stack are roots. The JIT reports their locations to the GC via "GC info" embedded alongside the compiled code.

```csharp
void ProcessOrder()
{
    var order = new Order(); // 'order' is a root — lives as long as frame is active
    order.Process();
    // After this return, 'order' is no longer a root → eligible for collection
}
```

**Subtle point:** Even after the last *use* of a variable, the JIT may keep it alive until the method returns (especially in Debug builds). In Release + tiered compilation, the JIT may shorten the lifetime to the last use.

#### 2. CPU Registers

When the JIT enregisters an object reference (keeps it in a CPU register rather than on the stack), that register is a root. The JIT's "safe points" and GC info tables tell the GC which registers hold live object references at each potential GC pause point.

#### 3. Static Fields

Any `static` field in any loaded type is a root — it lives for the lifetime of the AppDomain (effectively, the process). This is the most common source of inadvertent long-lived roots:

```csharp
public class Cache
{
    // 'static' makes this a GC root — everything reachable from _items
    // will never be collected as long as Cache type is loaded
    private static readonly List<object> _items = new();
}
```

#### 4. GC Handles

`GCHandle.Alloc(obj)` creates a GC handle — an explicit root registered with the runtime. The GC won't collect the object until `handle.Free()` is called:

| GC Handle type | Behaviour |
|---------------|----------|
| `Normal` | Prevents collection — strong root |
| `Pinned` | Prevents collection AND compaction (object can't move) |
| `Weak` | Does NOT prevent collection — tracks "is still alive?" |
| `WeakTrackResurrection` | Stays alive even through finalization |

#### 5. Finalizer Queue

Objects with finalizers (`~MyClass()`) are placed on the finalizer queue when they would otherwise be collected. The finalizer queue itself holds a reference — a weak-ish root that keeps the object alive through one extra GC cycle to let the finalizer run. This means finalizable objects always survive at least one additional GC collection.

```
Normal GC:  [Object becomes unreachable] → moved to finalizer queue → still "alive"
Next GC:    [Finalizer runs] → object moved to F-reachable queue → Dispose called
Next GC:    [Object truly freed]
```

### Why `= null` Doesn't Always Help Immediately

```csharp
void Foo()
{
    var bigArray = new byte[100_000_000]; // 100 MB on the heap
    // ... use bigArray ...
    bigArray = null!; // removes the local root

    // But if the JIT kept 'bigArray' alive in a register at this GC safe point,
    // the object may still not be collected until the method returns.
    DoLongWork(); // potential GC collection point during this call
}
```

In Release mode, the JIT is smart about this. In Debug mode, variables often live until the end of the method. If precise lifetime matters, call `GC.KeepAlive(bigArray)` at the exact point you're done, or move allocation to a separate method.

### Diagnosing Retained Roots

Use `dotnet-gcdump` to capture a heap dump, then analyse with:
- **Visual Studio / JetBrains Rider** — object reference roots view
- **PerfView** — heap analysis, root path tracing
- **dotnet-monitor** / `dotnet dump analyze` + `dumpheap`, `gcroot` commands

```bash
dotnet-gcdump collect -p <PID> --output heap.gcdump
# Open heap.gcdump in Visual Studio or PerfView
```

## Code Example

```csharp
// Demonstrate different root types

// Root type 1: local variable (stack root)
var temporary = new byte[1024];
// ... use temporary ...
// After method returns, 'temporary' is no longer a root

// Root type 2: static field (long-lived root — watch out!)
static List<byte[]>? _globalCache;

void Register(byte[] data)
{
    _globalCache ??= new List<byte[]>();
    _globalCache.Add(data); // data is now reachable from a static root → never collected
}

// Root type 3: GC handle (explicit root)
var important = new byte[512];
GCHandle handle = GCHandle.Alloc(important); // pins in memory conceptually (Normal type)
// important won't be collected until:
handle.Free(); // explicit release

// Root type 4: finalizer queue
class FinalizableObject
{
    ~FinalizableObject()
    {
        // The GC does NOT collect this object in the first pass it's unreachable.
        // It is promoted to the finalizer queue and collected one GC cycle later.
        Console.WriteLine("Finalizer ran");
    }
}

var obj = new FinalizableObject();
obj = null!;          // no more managed references
GC.Collect();         // first collect: moves to finalizer queue — still alive!
GC.WaitForPendingFinalizers(); // finalizer runs
GC.Collect();         // second collect: now truly freed
```

## Common Follow-up Questions

- How does the JIT report which local variables are alive at each GC safe point?
- What is an "interior pointer" and how does it complicate GC root scanning?
- How do `WeakReference<T>` and `WeakReference` help with caches without causing leaks?
- What is the finalization queue, and what is the F-reachable queue?
- How can a `static` event handler cause a memory leak (the lapsed listener problem)?
- How does `GC.KeepAlive` work and when should it be used?

## Common Mistakes / Pitfalls

- **Static event subscription without unsubscription** — if a long-lived object (publisher) holds an event delegate pointing to a short-lived subscriber, the subscriber becomes reachable from a static root and leaks.
- **Caching `Type`, `MethodInfo`, or `Assembly` objects in static dictionaries** — these are lightweight but if the key is a type from a collectible `AssemblyLoadContext`, the ALC can never be collected.
- **Assuming Debug and Release builds have the same GC root lifetime** — Debug builds keep local variables alive until end of scope; Release builds shorten lifetimes to last use.
- **Using `GCHandle.Alloc` without `GCHandle.Free`** — `GCHandle` is an unmanaged resource; not calling `Free` permanently pins the object and leaks the handle.
- **Expecting `GC.Collect` to always free recently nulled objects** — finalizable objects survive the first collection and only free after the finalizer runs + a second collection.

## References

- [Fundamentals of garbage collection — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
- [GCHandle — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandle)
- [GC roots and reachability — .NET runtime Book of the Runtime](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/garbage-collection.md)
- [Memory leak debugging with dotnet-gcdump — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-gcdump)
- [See also: gc-fundamentals.md](./gc-fundamentals.md)
