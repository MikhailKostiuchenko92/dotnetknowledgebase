# GC Generations: Gen0, Gen1, Gen2

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `GC generations`, `Gen0`, `Gen1`, `Gen2`, `ephemeral segment`, `promotion`, `generational hypothesis`

## Question

> What are GC generations in .NET, and how does generational garbage collection improve performance?

Also asked as:
> How does an object get promoted from Gen0 to Gen1 to Gen2?
> What is the ephemeral segment and why does its size matter?

## Short Answer

.NET GC divides the heap into three generations (0, 1, 2) based on object age. New allocations go into Gen0 — a small, frequently collected region. Objects that survive a Gen0 collection are promoted to Gen1; survivors of Gen1 go to Gen2. The core insight is the **generational hypothesis**: most objects die young, so collecting only Gen0 (cheap) handles the majority of garbage without touching the large, slower Gen2. This dramatically reduces average pause times compared to always scanning the entire heap.

## Detailed Explanation

### Generational Hypothesis

Empirically, in most object-oriented programs:
- Short-lived temporaries (LINQ results, intermediate strings, event args) die in the same method or request that created them
- Long-lived objects (caches, singletons, configuration) live for the life of the process

The GC exploits this by collecting frequently (Gen0) and cheaply, rather than scanning the whole heap every time.

### Generation Boundaries

| Generation | Typical size | Collection frequency | Contents |
|-----------|-------------|---------------------|---------|
| **Gen0** | ~256 KB (configurable) | Very frequent (hundreds/sec in hot code) | New allocations |
| **Gen1** | ~2 MB | Moderate | Gen0 survivors (buffer between Gen0 and Gen2) |
| **Gen2** | Unbounded | Infrequent | Long-lived objects, static fields, large objects |

Exact sizes depend on GC mode (workstation vs server) and memory pressure. Server GC allocates per-CPU-core heaps.

### The Allocation Pointer and Triggers

```
Gen0 segment
┌──────────────────────────────────────┐
│ [A][B][C][D][ ─── free ───          │
└──────────────────────────────────────┘
                      ↑ allocation pointer

When Gen0 is full:
 → GC triggers a Gen0 collection
 → Collect Gen0 + Gen1 = "ephemeral collection"
 → Survivors promoted to Gen1
 → If Gen1 full, triggers Gen2 collection (full/blocking)
```

### Promotion Mechanics

```
Allocation → Gen0
    │ Gen0 collection: if survived
    ▼
Gen1
    │ Gen1 collection: if survived
    ▼
Gen2  (stays here; collected only on full GC)
```

An object "survives" a collection if any root still references it during the collection.

### The Ephemeral Segment

Gen0 and Gen1 share a single **ephemeral segment** (a contiguous virtual memory range). This localisation means Gen0/Gen1 collection benefits from CPU cache warmth — the entire ephemeral segment fits in L2/L3 cache on modern hardware.

When the ephemeral segment fills up:
1. A Gen1 collection occurs (promotes Gen1 survivors to Gen2, frees dead Gen1 objects)
2. If Gen2 is needed, a full collection occurs (Stop The World or background)
3. A new ephemeral segment is allocated if needed

### Background GC (Gen2)

Gen2 collections are the most expensive (entire heap scan + compact). Background GC (enabled by default since .NET 4) allows Gen2 to be collected concurrently while the application continues running. Gen0/Gen1 can still be collected (foreground) during a background Gen2 collection.

```
Application threads:  ────▶▶▶▶▶▶▶▶▶▶▶▶▶▶▶
Background GC thread:     [Gen2 collection running concurrently]
Foreground GC:                  [Gen0 pause]   [Gen0 pause]
```

### Allocation Rate vs GC Frequency

High allocation rate → frequent Gen0 collections. The goal of allocation optimization is to **reduce allocations** (use `ArrayPool<T>`, `Span<T>`, `struct` over `class`) so Gen0 fills slowly, reducing GC pressure.

> **Rule of thumb:** If your application's Gen0 collection rate is > 10 per second, investigate allocation sources with BenchmarkDotNet's `MemoryDiagnoser` or dotnet-trace.

## Code Example

```csharp
using System.Runtime;

// Observe generation counts in action
static void PrintGCInfo(string label)
{
    Console.WriteLine($"[{label}]");
    Console.WriteLine($"  Gen0: {GC.CollectionCount(0)} collections");
    Console.WriteLine($"  Gen1: {GC.CollectionCount(1)} collections");
    Console.WriteLine($"  Gen2: {GC.CollectionCount(2)} collections");
    Console.WriteLine($"  Heap: {GC.GetTotalMemory(false) / 1024:N0} KB");
}

PrintGCInfo("Start");

// High allocation rate → many Gen0 collections
for (int i = 0; i < 100_000; i++)
    _ = new byte[256]; // small, short-lived → Gen0

PrintGCInfo("After 100k small allocs");

// Force a Gen2 collection (don't do in production)
GC.Collect(2, GCCollectionMode.Forced, blocking: true);
PrintGCInfo("After forced Gen2");

// Checking which generation an object is in
var longLived = new byte[1024];
Console.WriteLine($"Generation of longLived: {GC.GetGeneration(longLived)}"); // 0

GC.Collect(0); // Gen0 collection — longLived promoted to Gen1
Console.WriteLine($"After Gen0 collect: {GC.GetGeneration(longLived)}");      // 1

GC.Collect(1); // Gen1 collection — promoted to Gen2
Console.WriteLine($"After Gen1 collect: {GC.GetGeneration(longLived)}");      // 2

// Set GC latency mode for latency-sensitive scenarios
GCLatencyMode previous = GCSettings.LatencyMode;
GCSettings.LatencyMode = GCLatencyMode.SustainedLowLatency; // avoids Gen2 blocking
// ... latency-sensitive work ...
GCSettings.LatencyMode = previous; // always restore
```

## Common Follow-up Questions

- What is the Large Object Heap (LOH) and which generation does it belong to?
- How does Server GC divide generations across CPU cores?
- What does "finalizable objects are promoted" mean — why do they survive one extra generation?
- How do you measure the cost of Gen0 vs Gen2 collections in production?
- What is `GCSettings.LatencyMode` and when should you use `SustainedLowLatency`?
- How does the Pinned Object Heap (POH, .NET 5+) differ from the regular generational heap?

## Common Mistakes / Pitfalls

- **"Gen2 = bad, Gen0 = good"** — oversimplified. Short-lived allocations in Gen0 are cheap, but *frequent* Gen0 collections still pause the application. The goal is to reduce total allocation, not just avoid Gen2.
- **Pinning objects in Gen0** — pinning (e.g., `fixed` or `GCHandle.Pinned`) prevents compaction. Pinned objects in Gen0/Gen1 become "holes" that fragment the ephemeral segment. Prefer the Pinned Object Heap for long-lived pinned buffers.
- **Assuming `GC.GetGeneration(obj)` is cheap** — it's fine in diagnostics but has overhead; never call it on the hot path.
- **Using `GCSettings.LatencyMode = LowLatency` indefinitely** — `LowLatency` suppresses Gen2 collections; prolonged use causes heap growth and eventual OOM. Use only for short bursts (e.g., while processing a trading tick).
- **Not accounting for finalizable objects surviving an extra generation** — an object with a finalizer survives its first eligible collection and is promoted. This can unexpectedly promote objects to Gen2 and increase full GC frequency.

## References

- [Fundamentals of garbage collection — generations — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals#generations)
- [GC latency modes — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/latency)
- [Background garbage collection — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/background-gc)
- [.NET GC internals (Book of the Runtime) — GitHub dotnet/runtime](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/garbage-collection.md)
- [See also: gc-fundamentals.md](./gc-fundamentals.md) | [large-object-heap.md](./large-object-heap.md)
