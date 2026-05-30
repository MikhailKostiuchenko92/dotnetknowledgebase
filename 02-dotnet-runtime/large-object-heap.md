# The Large Object Heap (LOH)

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `LOH`, `Large Object Heap`, `fragmentation`, `compaction`, `85000 bytes`, `GC`

## Question

> What is the Large Object Heap, why does it exist, and what problems can it cause in production applications?

Also asked as:
> Why are objects ≥ 85,000 bytes treated differently by the garbage collector?
> How do you diagnose and mitigate LOH fragmentation?

## Short Answer

The Large Object Heap (LOH) is a separate managed heap region for objects ≥ 85,000 bytes (primarily large arrays). Because compacting large objects is expensive (copying hundreds of megabytes takes significant time), the GC historically collected LOH without compaction — it sweeps dead objects and maintains a free-list, which fragments over time. LOH is collected only during Gen2 collections. Fragmentation and Gen2 pause times are the main production issues; mitigations include `GCSettings.LargeObjectHeapCompactionMode`, `ArrayPool<byte>`, and the Pinned Object Heap (.NET 5+).

## Detailed Explanation

### The 85,000-Byte Threshold

Objects ≥ **85,000 bytes** (82.5 KB) are allocated directly on the LOH, bypassing Gen0/Gen1:

```
Heap layout:
┌──────────────────────┐    ┌────────────────────┐
│  Small Object Heap   │    │  Large Object Heap  │
│  Gen0 | Gen1 | Gen2  │    │  (no generations)   │
└──────────────────────┘    └────────────────────┘
       < 85,000 bytes              ≥ 85,000 bytes
```

The threshold is for the object size itself — a `byte[84_999]` is on the small heap; `byte[85_000]` goes to the LOH. The threshold has been 85,000 bytes since the original .NET Framework design and has not changed.

> **Exception:** Arrays of `double` (8 bytes each) use a lower threshold of 1,000 elements (8,000 bytes) on 32-bit runtimes — this dates from pre-64-bit era alignment optimisations and is largely historical.

### Why No Compaction (Historically)

Compacting a 500 MB LOH means copying 500 MB of data and updating every reference. For latency-sensitive applications (web servers, trading systems), this pause is unacceptable. The tradeoff: tolerate fragmentation to avoid pauses.

The GC instead uses a **free-list** for LOH:

```
LOH after several alloc/free cycles:
[Obj A: 100KB][FREE: 200KB][Obj C: 50KB][FREE: 400KB][Obj E: 300KB]
```

A new allocation searches the free-list for a large enough gap. If none is found, the LOH expands.

### Problems LOH Fragmentation Causes

1. **Increased memory usage** — 400 KB free block can't service a 500 KB request; LOH grows.
2. **Allocation failures (OOM)** — even with plenty of total free memory, no single contiguous block is large enough.
3. **Gen2 collection triggers** — LOH is only collected during Gen2 (full GC); high LOH allocation rate drives frequent Gen2 collections.

### LOH Compaction (.NET 4.5.1+)

You can opt into one-time LOH compaction before the next Gen2 collection:

```csharp
GCSettings.LargeObjectHeapCompactionMode = GCLargeObjectHeapCompactionMode.CompactOnce;
GC.Collect(); // triggers Gen2 + LOH compaction
// Mode resets to Default after the collection
```

Use this sparingly — it pauses the application for the duration of compacting the LOH. It is useful after a large allocation burst (e.g., loading a large dataset into memory, then releasing it).

### Mitigations

| Strategy | Effect |
|----------|--------|
| `ArrayPool<byte>.Shared.Rent(size)` | Reuse large byte arrays instead of allocating new ones |
| `MemoryPool<byte>` | Same; allows IMemoryOwner lifecycle management |
| Reduce LOH allocation rate | Keep objects < 85 KB where possible |
| `GCSettings.LargeObjectHeapCompactionMode.CompactOnce` | Force compaction before next Gen2 |
| Pinned Object Heap (.NET 5+) | Pin buffers without LOH fragmentation overhead |

### The Pinned Object Heap (.NET 5+)

.NET 5 introduced the **Pinned Object Heap (POH)** for buffers that must be pinned (e.g., for P/Invoke or socket I/O). POH is never compacted — avoiding the disruption pinned objects cause on the regular heap — and is more efficient than LOH for these use cases. See [pinned-object-heap.md](./pinned-object-heap.md).

### Monitoring LOH

```csharp
// Check LOH size at runtime
GCMemoryInfo info = GC.GetGCMemoryInfo();
Console.WriteLine($"LOH size: {info.GenerationInfo[3].SizeAfterBytes / 1024 / 1024:N1} MB");
// Note: index 3 = LOH in .NET 5+ GenerationInfo array
```

Or use `dotnet-gcdump` + PerfView / Visual Studio heap analysis to see LOH fragmentation visually.

## Code Example

```csharp
using System.Buffers;

// ── What goes on the LOH ─────────────────────────────────────────
byte[] small    = new byte[84_999]; // < 85,000 → small object heap
byte[] large    = new byte[85_000]; // ≥ 85,000 → LOH

Console.WriteLine($"Small generation: {GC.GetGeneration(small)}"); // 0
Console.WriteLine($"Large generation: {GC.GetGeneration(large)}"); // 2 (LOH = Gen2)

// ── Mitigation: ArrayPool to avoid LOH allocation ─────────────────
// Instead of: byte[] buffer = new byte[1_000_000]; (1 MB on LOH)
byte[] rented = ArrayPool<byte>.Shared.Rent(1_000_000); // reused buffer from pool
try
{
    rented.AsSpan().Fill(0);
    // ... use buffer ...
}
finally
{
    ArrayPool<byte>.Shared.Return(rented); // return to pool — no LOH alloc
}

// ── One-time LOH compaction ────────────────────────────────────────
GCSettings.LargeObjectHeapCompactionMode =
    GCLargeObjectHeapCompactionMode.CompactOnce;
GC.Collect(2, GCCollectionMode.Forced, blocking: true);
// ⚠ Blocks application; use only after releasing a large one-time allocation burst

// ── Monitor LOH size ───────────────────────────────────────────────
GCMemoryInfo info = GC.GetGCMemoryInfo(GCKind.FullBlocking);
foreach (GCGenerationInfo gen in info.GenerationInfo)
    Console.WriteLine($"  Gen {Array.IndexOf(info.GenerationInfo, gen)}: " +
                      $"{gen.SizeAfterBytes / 1024:N0} KB after GC");
```

## Common Follow-up Questions

- How does `ArrayPool<T>` avoid LOH allocations, and what are its caveats?
- What is the Pinned Object Heap and how does it differ from the LOH?
- How do you identify which objects in your application are landing on the LOH?
- Why are `double[]` arrays with > 1,000 elements treated specially on 32-bit runtimes?
- How does streaming large data (e.g., `Stream.CopyTo`) behave differently with and without `ArrayPool`?
- What effect does `GCSettings.LargeObjectHeapCompactionMode` have on pause duration?

## Common Mistakes / Pitfalls

- **Allocating large string or byte arrays per-request in a web app** — each creates a new LOH object; at high RPS this drives frequent Gen2 collections and LOH fragmentation. Use `ArrayPool<byte>` or `PipeWriter`.
- **Forgetting that `string` can be LOH-allocated** — a string with ≥ 42,500 characters (2 bytes/char) lands on the LOH. Concatenating large strings in loops is doubly bad.
- **Using `GCSettings.LargeObjectHeapCompactionMode.CompactOnce` without `GC.Collect()`** — setting the mode alone doesn't trigger compaction; you must also trigger a Gen2 collection.
- **Assuming LOH fragmentation is always a problem** — if your application's LOH objects are all the same size (e.g., always `byte[65536]`), the free-list reuses slots effectively and fragmentation stays low.
- **Not returning `ArrayPool` buffers** — rented arrays that are never returned deplete the pool and eventually cause the pool to allocate fresh LOH buffers, defeating the purpose.

## References

- [The large object heap — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/large-object-heap)
- [GCSettings.LargeObjectHeapCompactionMode — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.gcsettings.largeobjectheapcompactionmode)
- [ArrayPool\<T\> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [Diagnosing LOH fragmentation with PerfView — .NET Blog](https://devblogs.microsoft.com/dotnet/large-object-heap-uncovered/) (verify URL)
- [See also: gc-generations.md](./gc-generations.md) | [pinned-object-heap.md](./pinned-object-heap.md)
