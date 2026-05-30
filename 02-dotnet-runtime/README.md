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
- [gc-fundamentals.md](./gc-fundamentals.md) — Mark-sweep-compact, GC roots, reachability, why not reference counting
- [gc-generations.md](./gc-generations.md) — Gen0/Gen1/Gen2, ephemeral segment, generational hypothesis, promotion
- [gc-modes.md](./gc-modes.md) — Workstation vs Server GC, background GC, container configuration
- [gc-roots.md](./gc-roots.md) — Stack, static fields, GC handles, CPU registers, finalizer queue
- [idisposable-and-using.md](./idisposable-and-using.md) — IDisposable, using statement/declaration, SafeHandle, IAsyncDisposable
- [large-object-heap.md](./large-object-heap.md) — 85,000-byte threshold, fragmentation, compaction, ArrayPool mitigation