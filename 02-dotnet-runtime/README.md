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