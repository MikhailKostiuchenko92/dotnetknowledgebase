# How Does .NET Garbage Collection Work?

**Category:** .NET Runtime / GC
**Difficulty:** 🟢 Junior
**Tags:** `garbage collection`, `GC`, `mark-sweep-compact`, `roots`, `managed heap`

## Question

> How does the .NET garbage collector work? Explain the mark, sweep, and compact phases.

Also asked as:
> What is a GC root, and how does the GC determine which objects are alive?
> Why doesn't .NET use reference counting like some other runtimes?

## Short Answer

The .NET GC is a tracing garbage collector that uses a mark-sweep-compact algorithm. It starts from GC roots (stack variables, static fields, GC handles, finalizer queue) and traces all reachable objects, marking them alive. Objects not marked are considered dead. The GC then compacts the heap by moving live objects together, eliminating fragmentation and updating all references. This is more efficient than reference counting for cyclic graphs and avoids the overhead of maintaining reference counts on every assignment.

## Detailed Explanation

### The Managed Heap

When you write `new Foo()`, the CLR allocates memory on the managed heap by simply bumping an allocation pointer (much faster than `malloc`):

```
Managed Heap
┌──────────────────────────────────────────────────┐
│ [Object A][Object B][Object C][free space ──────▶│
└──────────────────────────────────────────────────┘
                              ↑ allocation pointer
```

This "bump-pointer" allocation is O(1) and very cache-friendly — much faster than native `malloc` for most workloads.

### GC Roots

The GC starts tracing from **roots** — known references that are always considered alive:

| Root type | Example |
|-----------|---------|
| **Stack variables** | Local variables in active method frames |
| **CPU registers** | JIT-enregistered object references |
| **Static fields** | `static Foo _instance` |
| **GC Handles** | `GCHandle.Alloc(obj)`, finalizer queue entries |
| **Finalizer queue** | Objects with finalizers not yet called |

> **Key insight:** If no root (directly or transitively) references an object, that object is unreachable and eligible for collection — even if the object references itself (circular reference). This is why .NET GC handles cycles correctly, unlike reference counting.

### The Three Phases

#### 1. Mark

The GC suspends all managed threads (a "Stop The World" pause — mitigated by background GC), then traces the reference graph from every root:

```
Roots → A → B → D  (all reachable — marked alive)
      → C           (reachable — marked alive)
              E     (unreachable — will be collected)
```

#### 2. Sweep (Identify Garbage)

Any object not marked is garbage. The GC identifies the spans of dead memory.

#### 3. Compact

The GC moves live objects together to eliminate holes, and updates all pointers that referenced moved objects:

```
Before compact: [A][  dead  ][B][D][ dead ][C][free]
After compact:  [A][B][D][C][ free                 ]
                              ↑ allocation pointer reset
```

Compaction is what makes bump-pointer allocation sustainable — it periodically resets the allocation pointer and reclaims fragmented space.

### Why Not Reference Counting?

| Concern | Reference Counting | Tracing GC |
|---------|-------------------|-----------|
| Cycles | ❌ Leaks without special cycle detection | ✅ Handles naturally |
| Write overhead | ❌ Every assignment touches ref count (cache miss) | ✅ Assignment is a single store |
| Pause pattern | Incremental (predictable) | Batched (generational, background) |
| Throughput | Lower (constant overhead) | Higher (infrequent bulk work) |
| Deterministic destroy | ✅ Immediate | ❌ Non-deterministic (use `IDisposable`) |

.NET made the throughput tradeoff consciously: server workloads benefit more from cheap assignments than from deterministic destroy.

### The Generational Hypothesis

In practice, most objects die young (temporaries, intermediate results). .NET exploits this with generational GC — covered in [gc-generations.md](./gc-generations.md).

### Background GC

In concurrent/background GC mode (default since .NET 4), Gen2 collections happen concurrently with application threads, reducing pause times. Gen0/Gen1 collections still require short pauses.

## Code Example

```csharp
// Demonstrate GC fundamentals

// Allocation — fast bump-pointer on the managed heap
var list = new List<byte[]>();

for (int i = 0; i < 100; i++)
    list.Add(new byte[1000]); // 100 KB total

// Remove references — objects become eligible for collection
list.Clear();
list = null!;

// Force a collection to demonstrate (don't do this in production!)
long before = GC.GetTotalMemory(false);
GC.Collect();               // triggers Gen0+Gen1+Gen2 collection
GC.WaitForPendingFinalizers();
long after = GC.GetTotalMemory(true);

Console.WriteLine($"Freed: {(before - after) / 1024} KB");

// GC.GetGCMemoryInfo — better API for monitoring (no forced collection)
GCMemoryInfo info = GC.GetGCMemoryInfo();
Console.WriteLine($"Heap size:        {info.HeapSizeBytes / 1024:N0} KB");
Console.WriteLine($"Memory load:      {info.MemoryLoadBytes / 1024:N0} KB");
Console.WriteLine($"Available memory: {info.TotalAvailableMemoryBytes / 1024 / 1024:N0} MB");

// Checking if an object is still alive (for diagnostics only)
WeakReference<byte[]> weak = new(new byte[1000]);
GC.Collect();
Console.WriteLine($"Still alive: {weak.TryGetTarget(out _)}"); // likely false
```

## Common Follow-up Questions

- What are the GC generations (Gen0, Gen1, Gen2), and how does promotion work?
- What is the Large Object Heap (LOH) and why is it collected differently?
- What is the difference between workstation and server GC modes?
- How does background GC reduce pause times?
- What is finalization, and why is `IDisposable` preferred over finalizers?
- How do GC roots in CPU registers prevent the CLR from collecting apparently-unreachable objects?

## Common Mistakes / Pitfalls

- **Calling `GC.Collect()` in production code** — forcing GC defeats generational optimization and can dramatically increase pause times. Only valid in benchmarks or after one-time large deallocation events.
- **Assuming `= null` immediately frees memory** — setting a reference to `null` makes the object *eligible* for collection; the actual memory is freed during the next GC pass.
- **Circular references causing leaks** — .NET GC handles cycles correctly. Circular references only leak if they are still reachable from a root (e.g., a cache or static field).
- **Confusing GC with `IDisposable`** — GC manages memory. `IDisposable` manages *unmanaged resources* (file handles, sockets, DB connections). Don't rely on GC to close resources; always use `using`.
- **Not understanding that `GC.WaitForPendingFinalizers()` doesn't mean all memory is freed** — finalizers may allocate new objects or extend object lifetimes (resurrection), requiring a second GC pass.

## References

- [Fundamentals of garbage collection — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
- [GC overview — .NET runtime GitHub](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/garbage-collection.md)
- [Garbage collection and performance — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/performance)
- [Pro .NET Memory Management — Konrad Kokosa](https://prodotnetmemory.com) (verify URL)
- [See also: gc-generations.md](./gc-generations.md)
