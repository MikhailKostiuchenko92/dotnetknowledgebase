# .NET Runtime

> CLR, Garbage Collection, memory model, JIT/AOT, threading.

## Questions

Browse the index below for available runtime questions. Use the [question template](../_templates/question-template.md) to add new ones.

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
- [jit-diagnostics.md](./jit-diagnostics.md) — JIT disassembly, IR dumps, BenchmarkDotNet, PerfView, and tracing-based inspection
- [jit-optimizations.md](./jit-optimizations.md) — Inlining, devirtualization, range-check elimination, loop hoisting, and SIMD-related optimizations
- [intrinsics-and-simd.md](./intrinsics-and-simd.md) — Vector<T>, hardware intrinsics, ISA guards, and explicit SIMD optimization
- [native-aot-constraints.md](./native-aot-constraints.md) — RequiresDynamicCode, reflection limits, interop caveats, and ILC warnings
- [native-aot-overview.md](./native-aot-overview.md) — Full static compilation, startup benefits, trimming synergy, and source-generator-friendly design
- [on-stack-replacement.md](./on-stack-replacement.md) — Loop patchpoints, Tier 0 to Tier 1 promotion, and live-frame transfer
- [pgo-and-dynamic-pgo.md](./pgo-and-dynamic-pgo.md) — Static vs dynamic PGO, profiling data, and guarded devirtualization
- [ready-to-run-overview.md](./ready-to-run-overview.md) — crossgen2, ReadyToRun images, IL fallback, composite mode, and startup trade-offs
- [tiered-compilation.md](./tiered-compilation.md) — Tier 0, Tier 1, call counting, QuickJit, and OSR

### §5 Threading Model
- [synchronization-primitives-overview.md](./synchronization-primitives-overview.md) — lock/Monitor, Mutex, SemaphoreSlim, reset events, and selection trade-offs
- [thread-vs-task.md](./thread-vs-task.md) — OS threads vs logical tasks, scheduling, and when raw Thread still matters
- [threadpool-basics.md](./threadpool-basics.md) — CLR ThreadPool basics, worker vs I/O completion threads, and starvation risks
- [threadpool-internals.md](./threadpool-internals.md) — Work-stealing queues, hill-climbing, thread injection, and backlog monitoring
- [thread-local-storage.md](./thread-local-storage.md) — `ThreadLocal<T>`, `[ThreadStatic]`, initialization traps, disposal, and thread-affine resource pitfalls
- [synchronization-context.md](./synchronization-context.md) — `SynchronizationContext`, continuation capture, UI affinity, and ASP.NET Classic vs ASP.NET Core behavior
- [semaphoreslim-and-manualresetevent.md](./semaphoreslim-and-manualresetevent.md) — `SemaphoreSlim`, `ManualResetEventSlim`, `CountdownEvent`, `AutoResetEvent`, and when each fits
- [concurrent-collections.md](./concurrent-collections.md) — `ConcurrentDictionary`, queues, stacks, bags, immutable snapshots, and `BlockingCollection`
- [channel-t.md](./channel-t.md) — `System.Threading.Channels`, bounded vs unbounded queues, backpressure, and async producer-consumer pipelines
- [reader-writer-lock.md](./reader-writer-lock.md) — `ReaderWriterLockSlim`, upgradeable reads, read-mostly workloads, and writer starvation trade-offs
- [spinlock-and-interlocked.md](./spinlock-and-interlocked.md) — `SpinLock`, `SpinWait`, CAS loops, ABA, and when spinning beats blocking
- [volatile-and-memory-barriers.md](./volatile-and-memory-barriers.md) — CPU reordering, `volatile`, `Volatile.Read/Write`, full fences, and visibility vs atomicity
- [task-parallel-library-internals.md](./task-parallel-library-internals.md) — `TaskScheduler`, continuations, task creation options, work-stealing, and `ValueTask` internals
- [parallel-and-plinq.md](./parallel-and-plinq.md) — `Parallel.For`, `Parallel.ForEachAsync`, PLINQ, ordering, and degree-of-parallelism trade-offs

### §6 Async/Await Internals
- [async-await-overview.md](./async-await-overview.md) — what `async`/`await` does, TAP, and why `await` does not create a new thread
- [task-and-valuetask.md](./task-and-valuetask.md) — `Task<T>` vs `ValueTask<T>`, allocation trade-offs, and `IValueTaskSource<T>`
- [configureawait.md](./configureawait.md) — `ConfigureAwait(false)`, context capture, library guidance, and .NET 8 options
- [async-void.md](./async-void.md) — why `async void` is dangerous, exception flow, and valid event-handler usage
- [iasyncenumerable.md](./iasyncenumerable.md) — `IAsyncEnumerable<T>`, `await foreach`, async iterators, and cancellation
- [cancellation-patterns.md](./cancellation-patterns.md) — `CancellationToken`, linked tokens, callbacks, and timeout patterns
- [task-completion-source.md](./task-completion-source.md) — `TaskCompletionSource<T>`, callback bridging, and safe continuation scheduling
- [async-streams.md](./async-streams.md) — async iterators, channel-backed streaming, backpressure, and `IAsyncDisposable`
- [task-exception-handling.md](./task-exception-handling.md) — `AggregateException`, `WhenAll`, unobserved tasks, and stack-trace preservation
- [async-state-machine.md](./async-state-machine.md) — generated `IAsyncStateMachine`, `MoveNext`, builders, and allocation behavior
- [async-context-propagation.md](./async-context-propagation.md) — `AsyncLocal<T>`, `ExecutionContext`, flow suppression, and tracing context
- [deadlock-in-async.md](./deadlock-in-async.md) — classic `.Result`/`.Wait()` deadlocks, why they happen, and how to avoid them

### §7 Exception Handling Internals
- [exception-design-guidelines.md](./exception-design-guidelines.md) — Exception hierarchy, custom exceptions, message quality, and boundary handling
- [throw-vs-rethrow.md](./throw-vs-rethrow.md) — `throw;` vs `throw ex;`, stack-trace preservation, and `ExceptionDispatchInfo`
- [clr-exception-model.md](./clr-exception-model.md) — SEH integration, heap allocation, two-pass handling, and IL clauses
- [exception-filters.md](./exception-filters.md) — `catch ... when`, first-pass filter evaluation, logging without catching, and idempotency
- [aggregate-exception.md](./aggregate-exception.md) — `AggregateException`, `Flatten()`, `Handle()`, and `Task.WhenAll` behavior
- [exception-performance.md](./exception-performance.md) — Throw cost, hot-path guidance, `TryXxx`, results, and throw helpers
- [structured-exception-handling.md](./structured-exception-handling.md) — Windows SEH, corrupted-state exceptions, and `AccessViolationException`
- [stack-overflow-and-oom.md](./stack-overflow-and-oom.md) — `StackOverflowException`, `OutOfMemoryException`, and mitigation strategies

### §8 Interop & P/Invoke
- [pinvoke-fundamentals.md](./pinvoke-fundamentals.md) — `DllImport`, `LibraryImport`, entry points, calling conventions, and `NativeLibrary`
- [marshalling-types.md](./marshalling-types.md) — Blittable vs non-blittable types, strings, arrays, and custom marshalling
- [safehandle.md](./safehandle.md) — `SafeHandle`, critical finalization, ownership, and `DangerousGetHandle()`
- [com-interop.md](./com-interop.md) — COM basics, RCW/CCW, apartments, explicit release, and source-generated COM
- [unsafe-and-fixed-context.md](./unsafe-and-fixed-context.md) — `fixed`, pinning, arrays, strings, and `GCHandle` trade-offs
- [function-pointers-in-csharp.md](./function-pointers-in-csharp.md) — `delegate*`, unmanaged call conventions, and `SuppressGCTransition`
- [source-generated-pinvoke.md](./source-generated-pinvoke.md) — compile-time P/Invoke stubs, AOT safety, and migration from `DllImport`
- [native-memory-management.md](./native-memory-management.md) — `NativeMemory`, HGlobal/CoTaskMem, span reinterpretation, and ownership
