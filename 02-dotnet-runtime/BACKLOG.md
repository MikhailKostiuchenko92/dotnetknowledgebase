# 📋 .NET Runtime — Question Backlog

Master list of planned questions for the `02-dotnet-runtime` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add a dotnet-runtime question on `gc-generations` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'Garbage Collection' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `02-dotnet-runtime/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(dotnet-runtime): add question on <topic>`

---

## Progress

**Total:** 82 / 112
**By difficulty:** 🟢 17/24 · 🟡 41/56 · 🔴 24/32

---

## §1 CLR Fundamentals (12 questions)

- [x] 🟢 [`clr-execution-model.md`](./clr-execution-model.md) — What is the CLR? IL → JIT → native execution pipeline, managed execution overview
- [x] 🟢 [`managed-vs-unmanaged-code.md`](./managed-vs-unmanaged-code.md) — Managed vs unmanaged distinction, CIL, type-safe verifiable code, unsafe keyword
- [x] 🟢 [`assembly-anatomy.md`](./assembly-anatomy.md) — Assembly manifest, modules, metadata, MSIL, PE format overview
- [x] 🟢 [`global-assembly-cache.md`](./global-assembly-cache.md) — GAC in .NET Framework, why it was removed in .NET Core, side-by-side versioning
- [x] 🟡 [`assembly-loading-and-binding.md`](./assembly-loading-and-binding.md) — Assembly resolution rules, binding redirects, load contexts, probing
- [x] 🟡 [`assembly-load-context-basics.md`](./assembly-load-context-basics.md) — AssemblyLoadContext, default/isolated ALCs, plugin loading pattern
- [x] 🟡 [`appdomain-removal.md`](./appdomain-removal.md) — AppDomain in .NET Framework vs .NET Core, migration to AssemblyLoadContext, process isolation
- [x] 🟡 [`runtime-configuration.md`](./runtime-configuration.md) — runtimeconfig.json, DOTNET_ environment variables, AppContext switches, runtime options
- [x] 🟡 [`strong-naming-and-signing.md`](./strong-naming-and-signing.md) — Strong name key pairs, why strong names matter, partial trust removal, Authenticode
- [x] 🟡 [`clr-startup-sequence.md`](./clr-startup-sequence.md) — hostfxr → hostpolicy → coreclr, host models, startup hooks, runtime initialization
- [x] 🔴 [`assembly-load-context-advanced.md`](./assembly-load-context-advanced.md) — ALC collectibility, unloading assemblies, Weaver pattern, dependency isolation pitfalls
- [x] 🔴 [`runtime-host-model.md`](./runtime-host-model.md) — Custom hosting API, embedding .NET in native apps, IJsRuntime, .NET for mobile

---

## §2 Garbage Collection (16 questions)

- [x] 🟢 [`gc-fundamentals.md`](./gc-fundamentals.md) — Mark-sweep-compact algorithm, GC roots, object reachability, managed heap overview
- [x] 🟢 [`idisposable-and-using.md`](./idisposable-and-using.md) — IDisposable pattern, using statement/declaration, deterministic cleanup vs GC finalization
- [x] 🟢 [`gc-roots.md`](./gc-roots.md) — What counts as a GC root: stack, static fields, GC handles, CPU registers, finalizer queue
- [x] 🟡 [`gc-generations.md`](./gc-generations.md) — Gen0/Gen1/Gen2, ephemeral segment, generational hypothesis, promotion mechanics
- [x] 🟡 [`large-object-heap.md`](./large-object-heap.md) — 85 000 byte threshold, LOH fragmentation, LOH compaction (.NET 4.5.1+, .NET Core switch)
- [x] 🟡 [`gc-modes.md`](./gc-modes.md) — Workstation vs Server GC, concurrent vs background GC, when each applies
- [x] 🟡 [`gc-server-vs-workstation.md`](./gc-server-vs-workstation.md) — Per-CPU heap model, heap count, throughput vs latency, container-aware defaults
- [x] 🟡 [`gc-finalization.md`](./gc-finalization.md) — Finalizer thread, finalization queue, F-reachable queue, two-phase collection, resurrection
- [x] 🟡 [`weak-references.md`](./weak-references.md) — WeakReference<T>, short vs long weak refs, cache use case, ConditionalWeakTable
- [x] 🟡 [`suppress-finalize.md`](./suppress-finalize.md) — GC.SuppressFinalize, Dispose + finalizer pattern, SafeHandle as better alternative
- [x] 🟡 [`memory-pressure-and-gc-collect.md`](./memory-pressure-and-gc-collect.md) — AddMemoryPressure, induced GC pitfalls, latency modes, NoGCRegion
- [x] 🔴 [`gc-handles.md`](./gc-handles.md) — GCHandle types, use cases, interop cookies, leaks from not freeing handles
- [x] 🔴 [`object-pinning.md`](./object-pinning.md) — `fixed` vs pinned handles, compaction holes, pinning trade-offs, zero-overhead access
- [x] 🔴 [`pinned-object-heap.md`](./pinned-object-heap.md) — POH in .NET 5+, pinned array allocation, long-lived I/O buffer use cases
- [x] 🔴 [`gc-segments-and-regions.md`](./gc-segments-and-regions.md) — Segment-based GC vs regions, commit vs reserve, .NET 6+ region model
- [x] 🔴 [`gc-notifications-and-monitoring.md`](./gc-notifications-and-monitoring.md) — Full GC notifications, GCMemoryInfo, ETW, counters, monitoring

---

## §3 Memory Model & Value Types (14 questions)

- [x] 🟢 [value-types-vs-reference-types.md](./value-types-vs-reference-types.md) — Stack vs heap allocation, copy semantics, struct vs class decision guide
- [x] 🟢 [boxing-and-unboxing.md](./boxing-and-unboxing.md) — IL box/unbox instructions, interface boxing, performance impact, avoiding with generics
- [x] 🟢 [readonly-struct.md](./readonly-struct.md) — readonly struct keyword, in parameters, defensive copy elimination, guidelines
- [x] 🟡 [struct-design-guidelines.md](./struct-design-guidelines.md) — When to use struct, immutability, 16-byte guideline, IEquatable\<T\> implementation
- [x] 🟡 [ref-structs.md](./ref-structs.md) — ref struct constraints, stack-only types, Span\<T\> as ref struct, async restriction
- [x] 🟡 [span-t-and-memory-t.md](./span-t-and-memory-t.md) — Span\<T\> vs Memory\<T\> vs ReadOnlySpan\<T\>, slicing without allocation, stackalloc spans
- [x] 🟡 [arraypool-and-memorypool.md](./arraypool-and-memorypool.md) — System.Buffers ArrayPool\<T\>, MemoryPool\<T\>, renting/returning, allocation avoidance
- [x] 🟡 [record-structs.md](./record-structs.md) — record struct vs record class, value equality, with-expressions, positional syntax
- [x] 🟡 [memory-t-and-imemoryowner.md](./memory-t-and-imemoryowner.md) — IMemoryOwner\<T\>, MemoryPool\<T\>, ownership and lifetime, pipeline buffers
- [x] 🟡 [string-interning-and-memory.md](./string-interning-and-memory.md) — String.Intern, string pool, string.IsInterned, when it helps vs hurts
- [x] 🔴 `memory-layout-of-objects.md` — Object header, sync block index, MethodTable pointer, field layout, EEClass
- [x] 🔴 `struct-layout-and-packing.md` — StructLayoutAttribute, LayoutKind.Explicit/Sequential, FieldOffset, packing, blittability
- [x] 🔴 `stackalloc-and-inline-arrays.md` — stackalloc with Span\<T\>, stack overflow risk, inline arrays (C# 12), SkipLocalsInit
- [x] 🔴 `unsafe-code-and-pointers.md` — unsafe context, fixed keyword, pointer arithmetic, Unsafe class, NativeMemory (.NET 6+)

---

## §4 JIT & Ahead-of-Time Compilation (12 questions)

- [x] 🟢 `jit-compilation-basics.md` — RyuJIT, IL → native, lazy compilation per method, code quality vs startup trade-off
- [x] 🟢 `ready-to-run-overview.md` — R2R images, crossgen2, partial AOT for startup, fallback to JIT, PublishReadyToRun
- [x] 🟡 `tiered-compilation.md` — Tier 0 / Tier 1, call counting, on-stack replacement (OSR), QuickJit, warm-up cost
- [x] 🟡 `jit-optimizations.md` — Inlining, loop unrolling, devirtualization, range-check elimination, dead-code elimination
- [x] 🟡 `code-generation-attributes.md` — MethodImplOptions.AggressiveInlining/NoInlining/NoOptimization, SkipLocalsInit, AggressiveOptimization
- [x] 🟡 `assembly-trimming.md` — ILLink linker, PublishTrimmed, RequiresUnreferencedCode, trim-unsafe patterns, analyzer
- [x] 🟡 [native-aot-overview.md](./native-aot-overview.md) — Full static compilation, no JIT at runtime, reflection limitations, size/startup benefits
- [x] 🔴 [native-aot-constraints.md](./native-aot-constraints.md) — RequiresDynamicCode, source-generated JSON/regex, COM not supported, cross-OS publish
- [x] 🔴 [on-stack-replacement.md](./on-stack-replacement.md) — OSR internals, loop hot path promotion to Tier 1, .NET 7+ counter-based triggers
- [x] 🔴 [pgo-and-dynamic-pgo.md](./pgo-and-dynamic-pgo.md) — Profile-guided optimization, instrumented Tier 1, class-hierarchy probes, Guarded Devirt
- [x] 🔴 [intrinsics-and-simd.md](./intrinsics-and-simd.md) — System.Runtime.Intrinsics, Vector128/256/512\<T\>, Vector\<T\>, AdvSimd, hardware guards
- [x] 🔴 [jit-diagnostics.md](./jit-diagnostics.md) — DOTNET_JitDisasm, DOTNET_JitDump, BenchmarkDotNet disassembler, PerfView JIT events

---

## §5 Threading Model (14 questions)

- [x] 🟢 [thread-vs-task.md](./thread-vs-task.md) — OS thread vs Task (TPL), Thread class usage, when to ever use raw Thread
- [x] 🟢 [threadpool-basics.md](./threadpool-basics.md) — CLR ThreadPool, QueueUserWorkItem, I/O completion port threads, min/max thread counts
- [x] 🟢 [synchronization-primitives-overview.md](./synchronization-primitives-overview.md) — lock, Monitor, Mutex, Semaphore — what each is and when to pick it
- [x] 🟡 [threadpool-internals.md](./threadpool-internals.md) — Work-stealing deques, local vs global queue, hill-climbing algorithm, thread injection
- [ ] 🟡 `thread-local-storage.md` — ThreadLocal\<T\>, [ThreadStatic], differences, when to use, thread-affine resources
- [ ] 🟡 `synchronization-context.md` — What SynchronizationContext does, ASP.NET Classic vs Core vs WinForms vs null
- [ ] 🟡 `semaphoreslim-and-manualresetevent.md` — SemaphoreSlim (async-compatible), ManualResetEventSlim, CountdownEvent
- [ ] 🟡 `concurrent-collections.md` — ConcurrentDictionary, ConcurrentQueue, ConcurrentBag, ConcurrentStack — internals and gotchas
- [ ] 🟡 `channel-t.md` — System.Threading.Channels, BoundedChannel vs UnboundedChannel, producer-consumer pattern
- [ ] 🟡 `reader-writer-lock.md` — ReaderWriterLockSlim, upgradeable read lock, lock convoy, read-heavy workloads
- [ ] 🔴 `spinlock-and-interlocked.md` — SpinLock, SpinWait, Interlocked CAS, ABA problem, when spinning beats blocking
- [ ] 🔴 `volatile-and-memory-barriers.md` — volatile keyword, Thread.MemoryBarrier, Volatile.Read/Write, CPU reordering
- [ ] 🔴 `task-parallel-library-internals.md` — TaskScheduler, work-stealing, continuation chaining, TaskCreationOptions
- [ ] 🔴 `parallel-and-plinq.md` — Parallel.For/ForEach partitioning, PLINQ AsParallel, degree of parallelism, ordering cost

---

## §6 Async/Await Internals (12 questions)

- [x] 🟢 [async-await-overview.md](./async-await-overview.md) — What async/await does, Task-based async pattern, no new thread misconception
- [x] 🟢 [task-and-valuetask.md](./task-and-valuetask.md) — Task\<T\> vs ValueTask\<T\>, allocation trade-offs, when ValueTask is appropriate
- [x] 🟡 [configureawait.md](./configureawait.md) — ConfigureAwait(false), SynchronizationContext capture, library code rule, .NET 5+ Console behavior
- [x] 🟡 [async-void.md](./async-void.md) — Why async void is dangerous, unhandled exceptions, fire-and-forget pattern, event handlers
- [x] 🟡 [iasyncenumerable.md](./iasyncenumerable.md) — IAsyncEnumerable\<T\>, await foreach, async yield return, cancellation with WithCancellation
- [x] 🟡 [cancellation-patterns.md](./cancellation-patterns.md) — CancellationToken design, CancellationTokenSource, linked tokens, cooperative cancellation
- [x] 🟡 [task-completion-source.md](./task-completion-source.md) — TaskCompletionSource\<T\>, bridging callbacks to tasks, SetResult/TrySetResult
- [x] 🟡 [async-streams.md](./async-streams.md) — Async iterators, IAsyncEnumerable\<T\> producer, channel-based streaming, backpressure
- [x] 🟡 [task-exception-handling.md](./task-exception-handling.md) — AggregateException unwrapping, UnobservedTaskException, await vs .Result, WhenAll failure
- [x] 🔴 [async-state-machine.md](./async-state-machine.md) — Compiler-generated IAsyncStateMachine, MoveNext, state fields, heap allocation per await
- [x] 🔴 [async-context-propagation.md](./async-context-propagation.md) — AsyncLocal\<T\>, ExecutionContext, flow suppression, logical call context
- [x] 🔴 [deadlock-in-async.md](./deadlock-in-async.md) — Classic .Result/.Wait() deadlock, why it happens, ConfigureAwait, async-all-the-way rule

---

## §7 Exception Handling Internals (8 questions)

- [ ] 🟢 `exception-design-guidelines.md` — Exception hierarchy, custom exception classes, message quality, when to catch vs rethrow
- [ ] 🟢 `throw-vs-rethrow.md` — throw ex (resets stack trace) vs throw (preserves), ExceptionDispatchInfo.Capture
- [ ] 🟡 `clr-exception-model.md` — SEH under the hood, exception objects on heap, two-pass handling (filter then handle)
- [ ] 🟡 `exception-filters.md` — when clause in catch, IL filter blocks, logging without catching, idempotent filters
- [ ] 🟡 `aggregate-exception.md` — AggregateException, Flatten(), Handle(), Parallel/WhenAll context, async unwrapping
- [ ] 🟡 `exception-performance.md` — Cost of throw/catch, Result\<T\> pattern, throw helper static methods, hot path avoidance
- [ ] 🔴 `structured-exception-handling.md` — Windows SEH, hardware exceptions, AccessViolationException, HandleProcessCorruptedStateExceptions
- [ ] 🔴 `stack-overflow-and-oom.md` — StackOverflowException (non-catchable), OutOfMemoryException, environment limits, process exit

---

## §8 Interop & P/Invoke (8 questions)

- [ ] 🟢 `pinvoke-fundamentals.md` — DllImport attribute, platform invoke mechanics, entry point resolution, calling conventions
- [ ] 🟡 `marshalling-types.md` — Blittable vs non-blittable types, MarshalAs, string marshalling (ANSI/Unicode/UTF8), arrays
- [ ] 🟡 `safehandle.md` — SafeHandle\<T\> hierarchy, CriticalFinalizerObject, reliable cleanup, vs raw IntPtr
- [ ] 🟡 `com-interop.md` — RCW/CCW, ComImport, IUnknown AddRef/Release, COM apartments, Marshal.ReleaseComObject
- [ ] 🟡 `unsafe-and-fixed-context.md` — unsafe keyword, fixed statement, pointer types, pinning for P/Invoke
- [ ] 🔴 `libraryimport-and-source-gen.md` — LibraryImport (.NET 7+), source-generated marshalling, why it's better than DllImport
- [ ] 🔴 `native-aot-interop.md` — UnmanagedCallersOnly, C-callable export, embedding .NET in native apps, NativeAOT limitations
- [ ] 🔴 `comwrappers-api.md` — ComWrappers (.NET 5+), source-generated COM (.NET 8+), replacing built-in COM interop

---

## §9 Diagnostics & Performance Tooling (10 questions)

- [ ] 🟢 `dotnet-diagnostics-tools.md` — dotnet-counters, dotnet-trace, dotnet-dump, dotnet-gcdump, dotnet-monitor overview
- [ ] 🟢 `benchmarkdotnet-basics.md` — BenchmarkDotNet setup, [Benchmark], MemoryDiagnoser, Job configs, how to interpret results
- [ ] 🟡 `eventsource-and-etw.md` — EventSource, EventListener, ETW providers, semantic logging, well-known .NET providers
- [ ] 🟡 `activity-and-opentelemetry.md` — Activity/ActivitySource, DiagnosticSource, OTel .NET SDK, W3C TraceContext
- [ ] 🟡 `dotnet-metrics.md` — System.Diagnostics.Metrics, Meter/Counter/Histogram, IMeterFactory (.NET 8), Prometheus export
- [ ] 🟡 `gc-diagnostics.md` — GC ETW events, dotnet-gcdump, heap dump analysis, GCMemoryInfo, Gen2 fragmentation
- [ ] 🟡 `loggermessage-source-gen.md` — LoggerMessage.Define vs source-gen [LoggerMessage], zero-allocation logging, performance
- [ ] 🔴 `jit-diagnostics-deep.md` — DOTNET_JitDisasm, DOTNET_JitDump, PerfView JIT events, inlining decisions, BenchmarkDotNet disasm
- [ ] 🔴 `profiling-approaches.md` — Sampling vs instrumentation profiling, VS Profiler, dotTrace, async call stacks, wall time vs CPU
- [ ] 🔴 `production-diagnostics.md` — Dump collection (createdump, procdump), EventPipe, live counters, .NET Monitor sidecar

---

## §10 Runtime Deployment & Configuration (6 questions)

- [ ] 🟢 `dotnet-versioning-model.md` — SemVer in .NET, TFM (net8.0, net9.0), RID catalog, version compatibility rules
- [ ] 🟢 `self-contained-vs-framework-dependent.md` — FDD vs SCD deployment, side-by-side installs, trimming applicability, size trade-offs
- [ ] 🟡 `single-file-apps.md` — PublishSingleFile, extraction behavior, native binaries bundling, debugging single-file
- [ ] 🟡 `cross-platform-considerations.md` — RuntimeInformation, OSPlatform guards, path separator, P/Invoke on Linux/macOS
- [ ] 🟡 `globalization-modes.md` — ICU vs NLS, invariant globalization mode (DOTNET_SYSTEM_GLOBALIZATION_INVARIANT), WASM impact
- [ ] 🔴 `trimming-and-aot-compatibility.md` — RequiresUnreferencedCode, RequiresDynamicCode, trim analyzers, making libraries trim-safe
