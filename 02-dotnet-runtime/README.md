# .NET Runtime

> CLR, Garbage Collection, memory model, JIT/AOT, threading.

## Questions

_No questions added yet. Use the [question template](../_templates/question-template.md) to add one._

## Index

### §1 CLR Fundamentals
- [appdomain-removal.md](./appdomain-removal.md) — AppDomain in .NET Framework vs .NET Core, migration to AssemblyLoadContext
- [assembly-anatomy.md](./assembly-anatomy.md) — Assembly manifest, modules, metadata, MSIL, PE format
- [assembly-load-context-advanced.md](./assembly-load-context-advanced.md) — Collectible ALC, unloading, WeakReference monitoring, retained-root pitfalls
- [assembly-load-context-basics.md](./assembly-load-context-basics.md) — AssemblyLoadContext, isolated ALCs, plugin loading pattern
- [assembly-loading-and-binding.md](./assembly-loading-and-binding.md) — Assembly resolution rules, binding redirects, probing paths
- [clr-execution-model.md](./clr-execution-model.md) — IL → JIT → native pipeline, CLR services overview
- [clr-startup-sequence.md](./clr-startup-sequence.md) — hostfxr → hostpolicy → coreclr, startup hooks, type init
- [global-assembly-cache.md](./global-assembly-cache.md) — GAC in .NET Framework, why removed from .NET Core, side-by-side
- [managed-vs-unmanaged-code.md](./managed-vs-unmanaged-code.md) — CLR supervision, unsafe keyword, P/Invoke boundary
- [runtime-configuration.md](./runtime-configuration.md) — runtimeconfig.json, DOTNET_ env vars, AppContext switches
- [runtime-host-model.md](./runtime-host-model.md) — hostfxr C API, embedding .NET in native apps, NativeAOT shared library
- [strong-naming-and-signing.md](./strong-naming-and-signing.md) — Strong name key pairs, PublicKeyToken, Authenticode vs strong naming

### §2 Garbage Collection
- [gc-finalization.md](./gc-finalization.md) — Finalizer thread, finalization queue, F-reachable queue, resurrection, Dispose interaction
- [gc-fundamentals.md](./gc-fundamentals.md) — Mark-sweep-compact, GC roots, reachability, why not reference counting
- [gc-generations.md](./gc-generations.md) — Gen0/Gen1/Gen2, ephemeral segment, generational hypothesis, promotion
- [gc-handles.md](./gc-handles.md) — GCHandle types, interop cookies, pinned vs weak handles, leak risks
- [gc-modes.md](./gc-modes.md) — Workstation vs Server GC, background GC, container configuration
- [gc-notifications-and-monitoring.md](./gc-notifications-and-monitoring.md) — Full GC notifications, GCMemoryInfo, ETW, counters, production monitoring
- [gc-roots.md](./gc-roots.md) — Stack, static fields, GC handles, CPU registers, finalizer queue
- [gc-segments-and-regions.md](./gc-segments-and-regions.md) — Segments vs regions, reserve vs commit, .NET 6+ heap layout
- [gc-server-vs-workstation.md](./gc-server-vs-workstation.md) — Per-CPU heaps, throughput vs latency, ASP.NET Core and containers
- [idisposable-and-using.md](./idisposable-and-using.md) — IDisposable, using statement/declaration, SafeHandle, IAsyncDisposable
- [large-object-heap.md](./large-object-heap.md) — 85,000-byte threshold, fragmentation, compaction, ArrayPool mitigation
- [memory-pressure-and-gc-collect.md](./memory-pressure-and-gc-collect.md) — AddMemoryPressure, induced GC pitfalls, latency modes, NoGCRegion
- [object-pinning.md](./object-pinning.md) — `fixed` vs pinned handles, heap holes, when pinning is necessary
- [pinned-object-heap.md](./pinned-object-heap.md) — POH, pinned array allocation, long-lived I/O buffers
- [suppress-finalize.md](./suppress-finalize.md) — Why SuppressFinalize exists, Dispose pattern, SafeHandle guidance
- [weak-references.md](./weak-references.md) — WeakReference<T>, TrackResurrection, ConditionalWeakTable, caches

### §3 Memory Model & Value Types
- [arraypool-and-memorypool.md](./arraypool-and-memorypool.md) — System.Buffers ArrayPool<T> and MemoryPool<T>, renting/returning, and allocation avoidance
- [boxing-and-unboxing.md](./boxing-and-unboxing.md) — IL box/unbox instructions, implicit boxing sites, and performance impact
- [memory-layout-of-objects.md](./memory-layout-of-objects.md) — Object header, MethodTable pointer, field layout, padding, and size-measurement caveats
- [memory-t-and-imemoryowner.md](./memory-t-and-imemoryowner.md) — Memory<T>, IMemoryOwner<T>, ownership, disposal, and async-safe buffers
- [readonly-struct.md](./readonly-struct.md) — readonly struct, in parameters, and defensive-copy avoidance
- [record-structs.md](./record-structs.md) — record struct vs record class, value equality, and with expressions
- [ref-structs.md](./ref-structs.md) — stack-only ref struct rules, Span<T>, and async restrictions
- [span-t-and-memory-t.md](./span-t-and-memory-t.md) — Span<T> vs Memory<T>, slicing, ReadOnlySpan<T>, and stackalloc
- [stackalloc-and-inline-arrays.md](./stackalloc-and-inline-arrays.md) — stackalloc buffers, InlineArray, stack limits, and SkipLocalsInit
- [string-interning-and-memory.md](./string-interning-and-memory.md) — String interning, intern pool lifetime, and controlled pooling alternatives
- [struct-design-guidelines.md](./struct-design-guidelines.md) — When to use structs, the 16-byte guideline, and equality design
- [struct-layout-and-packing.md](./struct-layout-and-packing.md) — Sequential vs Explicit layout, packing, FieldOffset, and blittability
- [unsafe-code-and-pointers.md](./unsafe-code-and-pointers.md) — unsafe contexts, pointers, fixed, NativeMemory, and low-level memory access
- [value-types-vs-reference-types.md](./value-types-vs-reference-types.md) — Stack vs heap caveats, copy semantics, and struct-vs-class trade-offs

### §4 JIT & Ahead-of-Time Compilation
- [assembly-trimming.md](./assembly-trimming.md) — ILLink trimming, trim-safe patterns, reflection hazards, and NativeAOT readiness
- [code-generation-attributes.md](./code-generation-attributes.md) — MethodImplOptions, SkipLocalsInit, and practical JIT/codegen hints
- [jit-compilation-basics.md](./jit-compilation-basics.md) — RyuJIT, IL-to-native compilation, lazy method JIT, and startup trade-offs
- [jit-optimizations.md](./jit-optimizations.md) — Inlining, devirtualization, range-check elimination, loop hoisting, and SIMD-related optimizations
- [ready-to-run-overview.md](./ready-to-run-overview.md) — crossgen2, ReadyToRun images, IL fallback, composite mode, and startup trade-offs
- [tiered-compilation.md](./tiered-compilation.md) — Tier 0, Tier 1, call counting, QuickJit, and OSR
