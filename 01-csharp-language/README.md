# C# Language

> Language features: async/await, generics, delegates, records, LINQ, pattern matching.

## Questions

See the [BACKLOG.md](./BACKLOG.md) for the full list of planned questions and current progress.

## Index

### Type System & Memory Semantics

- [boxing-and-unboxing.md](./boxing-and-unboxing.md) — When boxing occurs, performance impact, how to avoid
- [default-keyword-and-default-values.md](./default-keyword-and-default-values.md) — `default(T)`, `default` literal, struct zeroing
- [dynamic-vs-object-vs-var.md](./dynamic-vs-object-vs-var.md) — Compile-time inference vs base type vs DLR dispatch
- [equality-equals-vs-reference-equals.md](./equality-equals-vs-reference-equals.md) — `==`, `Equals`, `ReferenceEquals`, IEquatable contract
- [gethashcode-contract.md](./gethashcode-contract.md) — Three-rule contract, mutable-key bugs, `HashCode.Combine`
- [idisposable-and-using.md](./idisposable-and-using.md) — Dispose pattern, `using` declaration, `IAsyncDisposable`
- [nullable-value-types.md](./nullable-value-types.md) — `Nullable<T>`, lifting, `HasValue`, boxing behavior
- [pass-by-value-vs-by-reference.md](./pass-by-value-vs-by-reference.md) — `ref`, `out`, `in`; reference types passed by value
- [ref-out-in-parameters.md](./ref-out-in-parameters.md) — Differences, use cases, restrictions of `ref`/`out`/`in`
- [ref-struct-and-ref-fields.md](./ref-struct-and-ref-fields.md) — `ref struct`, `Span<T>`, `ref` fields (C# 11), escape restrictions
- [stack-vs-heap.md](./stack-vs-heap.md) — What lives where, common misconceptions
- [value-types-vs-reference-types.md](./value-types-vs-reference-types.md) — Copy semantics, equality, choosing struct vs class

### Strings

- [string-comparison-and-culture.md](./string-comparison-and-culture.md) — Ordinal vs Cultural, Turkish-I problem, `StringComparer`
- [string-immutability.md](./string-immutability.md) — Why strings are immutable, allocation implications
- [string-interning.md](./string-interning.md) — Intern pool mechanics, when to use/avoid `string.Intern`
- [string-interpolation-vs-format.md](./string-interpolation-vs-format.md) — `$""`, `string.Format`, interpolated handlers (.NET 6+)
- [stringbuilder-vs-string-concatenation.md](./stringbuilder-vs-string-concatenation.md) — O(n²) vs O(n), decision guide, .NET 6+ alternatives
- [utf8-strings-and-rune.md](./utf8-strings-and-rune.md) — `u8` literals, `Rune`, surrogate pairs, encoding gotchas

### Collections & LINQ

- [aggregate-and-reductions.md](./aggregate-and-reductions.md) — `Aggregate`, fold/reduce, `MinBy`/`MaxBy`, accumulator patterns
- [array-vs-list-vs-linkedlist.md](./array-vs-list-vs-linkedlist.md) — Complexity, cache locality, when to pick each
- [concurrent-collections.md](./concurrent-collections.md) — `ConcurrentDictionary`, `ConcurrentQueue`, `BlockingCollection`, lock-striping
- [deferred-vs-immediate-execution.md](./deferred-vs-immediate-execution.md) — Lazy LINQ, materialization triggers, multiple enumeration
- [dictionary-internals.md](./dictionary-internals.md) — Hash buckets, collision chaining, load factor, rehashing
- [groupby-and-tolookup.md](./groupby-and-tolookup.md) — Deferred vs immediate grouping, `IGrouping`, O(1) key lookup
- [hashset-vs-sortedset.md](./hashset-vs-sortedset.md) — O(1) vs O(log n), set operations, `GetViewBetween`
- [ienumerable-vs-icollection-vs-ilist.md](./ienumerable-vs-icollection-vs-ilist.md) — Interface hierarchy, read-only counterparts, API design
- [ienumerable-vs-iqueryable.md](./ienumerable-vs-iqueryable.md) — Expression trees, EF Core client vs server evaluation
- [frozencollections.md](./frozencollections.md) — `FrozenDictionary`/`FrozenSet` (.NET 8), perfect hash, startup lookup
- [immutablecollections.md](./immutablecollections.md) — `ImmutableArray` vs `ImmutableList`, structural sharing, thread safety
- [linq-common-pitfalls.md](./linq-common-pitfalls.md) — Multiple enumeration, closure capture, side effects, N+1
- [linq-method-vs-query-syntax.md](./linq-method-vs-query-syntax.md) — Compiler equivalence, method-only operators, `let` clause
- [select-vs-selectmany.md](./select-vs-selectmany.md) — One-to-one projection vs one-to-many flattening

### Generics

- [covariance-and-contravariance.md](./covariance-and-contravariance.md) — `in`/`out`, variance rules, array covariance danger
- [generic-constraints.md](./generic-constraints.md) — `where` clauses, `struct`/`class`/`new()`/interface constraints
- [generic-method-vs-generic-class.md](./generic-method-vs-generic-class.md) — When to make a method vs class generic, type parameter scope
- [generic-type-inference.md](./generic-type-inference.md) — Compiler inference rules, return-type limits, partial inference
- [generics-basics.md](./generics-basics.md) — Type parameters, JIT specialization, generic classes vs methods
- [static-members-in-generic-types.md](./static-members-in-generic-types.md) — Per-closed-type statics, static abstract members, generic math

### Delegates, Events & Lambdas

- [delegates-explained.md](./delegates-explained.md) — `Action`/`Func`/`Predicate`, delegate as object, method groups
- [event-memory-leaks.md](./event-memory-leaks.md) — Subscriber leaks, weak events, explicit unsubscription patterns
- [events-vs-delegates.md](./events-vs-delegates.md) — `event` access restrictions, add/remove accessors, conventions
- [expression-trees.md](./expression-trees.md) — `Expression<Func<T>>`, AST nodes, EF Core translation, dynamic build
### Async / Await / Tasks

- [async-await-fundamentals.md](./async-await-fundamentals.md) — State machine lowering, `await` suspension, synchronous fast path
- [async-exception-handling.md](./async-exception-handling.md) — Faulted tasks, `AggregateException`, unawaited tasks, `UnobservedTaskException`
- [async-streams-vs-channels.md](./async-streams-vs-channels.md) — Pull vs push, multi-producer/consumer, back-pressure, `BoundedChannelOptions`
- [async-void-pitfalls.md](./async-void-pitfalls.md) — `async void` exception behavior, event-handler only rule, fire-and-forget alternatives
- [cancellation-tokens.md](./cancellation-tokens.md) — Cooperative cancellation, `CancellationTokenSource`, linked tokens, `OperationCanceledException`
- [configure-await-false.md](./configure-await-false.md) — Context capture, deadlock prevention, library vs app code, .NET 8 options
- [cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md) — CPU-bound vs I/O-bound work, `Task.Run` rules, and thread pool impact
- [deadlocks-with-result-and-wait.md](./deadlocks-with-result-and-wait.md) — Step-by-step deadlock anatomy, `Task.Run` bridge, safe `.Result` scenarios
- [iasyncenumerable.md](./iasyncenumerable.md) — `await foreach`, streaming, `[EnumeratorCancellation]`, `ConfigureAwait`
- [parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md) — CPU vs I/O bound, `Parallel.ForEachAsync` (.NET 6+), throttling
- [progress-reporting-iprogress.md](./progress-reporting-iprogress.md) — `IProgress<T>`, `Progress<T>` SC marshalling, null-safe pattern
- [synchronization-context.md](./synchronization-context.md) — WPF/WinForms/ASP.NET Classic/Core behavior, `AsyncLocal` vs SC
- [task-completion-source.md](./task-completion-source.md) — Callback bridge, `RunContinuationsAsynchronously`, async gate pattern
- [task-vs-thread.md](./task-vs-thread.md) — Thread pool vs raw thread, when to use `new Thread`, `LongRunning`
- [task-vs-valuetask.md](./task-vs-valuetask.md) — Synchronous fast path, allocation savings, single-await rule
- [task-whenall-vs-whenany.md](./task-whenall-vs-whenany.md) — Parallel fan-out, exception aggregation, timeout pattern
- [lambda-expressions-and-closures.md](./lambda-expressions-and-closures.md) — Closure class generation, loop-variable bug, `static` lambda
- [multicast-delegates.md](./multicast-delegates.md) — Invocation list, return value discard, exception isolation

### Threading & Concurrency

- [interlocked-operations.md](./interlocked-operations.md) — Atomic increments, compare-and-swap loops, and simple lock-free updates
- [lock-and-monitor.md](./lock-and-monitor.md) — How `lock` maps to `Monitor`, reentrancy, and safe lock objects
- [parallel-class-and-plinq.md](./parallel-class-and-plinq.md) — Data parallelism with `Parallel` APIs, PLINQ, partitioning, and trade-offs
- [producer-consumer-with-channel.md](./producer-consumer-with-channel.md) — Async producer-consumer pipelines with bounded/unbounded channels and back-pressure
- [reader-writer-lockslim.md](./reader-writer-lockslim.md) — Read-heavy synchronization, upgradeable reads, and when it pays off
- [semaphoreslim-and-mutex.md](./semaphoreslim-and-mutex.md) — Async-aware throttling vs cross-process mutual exclusion
- [thread-local-storage.md](./thread-local-storage.md) — `ThreadLocal<T>` for per-thread data vs `AsyncLocal<T>` for ambient async context
- [thread-safety-of-collections.md](./thread-safety-of-collections.md) — Which collection types are safe to share and the common `List<T>`/`Dictionary<TKey,TValue>` races
- [thread-vs-threadpool.md](./thread-vs-threadpool.md) — Dedicated threads vs pooled work items, cost, and API choices
- [volatile-and-memory-barriers.md](./volatile-and-memory-barriers.md) — Visibility, reordering, acquire/release semantics, and when `volatile` is not enough

### Exceptions

- [cost-of-exceptions.md](./cost-of-exceptions.md) — Why throwing is expensive, first-chance exceptions, and why exceptions are not for normal control flow
- [custom-exceptions-best-practices.md](./custom-exceptions-best-practices.md) — When custom exceptions make sense, naming, constructors, and modern .NET guidance
- [exception-filters-when.md](./exception-filters-when.md) — `catch (...) when (...)`, pre-unwind filtering, and cleaner selective handling
- [exception-handling-fundamentals.md](./exception-handling-fundamentals.md) — `try`/`catch`/`finally`, exception hierarchy, and when broad catches are appropriate
- [throw-vs-throw-ex.md](./throw-vs-throw-ex.md) — Stack trace preservation, proper rethrowing, and `ExceptionDispatchInfo`

### OOP in C#

- [abstract-class-vs-interface.md](./abstract-class-vs-interface.md) — Shared implementation vs capability contracts, and where default interface members fit
- [class-vs-struct.md](./class-vs-struct.md) — Value vs reference semantics, boxing, and why small immutable structs work best
- [constructors-chaining-and-static.md](./constructors-chaining-and-static.md) — `this(...)`, `base(...)`, static constructor timing, and `beforefieldinit`
- [extension-methods.md](./extension-methods.md) — How extension methods are resolved, namespace scope, and when instance methods win
- [finalizer-and-dispose-pattern.md](./finalizer-and-dispose-pattern.md) — Finalizers, deterministic cleanup, `GC.SuppressFinalize`, and `SafeHandle`
- [interface-default-implementations.md](./interface-default-implementations.md) — Allowed members, versioning benefits, dispatch rules, and diamond-style conflicts
- [partial-classes-and-methods.md](./partial-classes-and-methods.md) — Generated code, source generators, and partial-method hooks
- [sealed-classes-and-methods.md](./sealed-classes-and-methods.md) — Preventing inheritance, `sealed override`, and design/perf trade-offs
- [static-classes-and-members.md](./static-classes-and-members.md) — Utility types, static field lifetime, static local functions, and testability concerns
- [virtual-override-new-keywords.md](./virtual-override-new-keywords.md) — Runtime polymorphism, hiding vs overriding, `base`, and `sealed override`

### Records, Structs & Immutability

- [init-only-properties.md](./init-only-properties.md) — `init`, `required`, object initialization, and immutable models
- [readonly-struct.md](./readonly-struct.md) — Immutability contracts, defensive copies, and `in` parameters
- [record-struct-vs-record-class.md](./record-struct-vs-record-class.md) — Value vs reference record semantics, copying, boxing, and defaults
- [records-vs-classes.md](./records-vs-classes.md) — Value equality, compiler-generated members, `with`, and DTO/value-object use cases
- [value-equality-in-records.md](./value-equality-in-records.md) — Generated equality members, runtime-type checks, and customization guidance
- [with-expressions-and-non-destructive-mutation.md](./with-expressions-and-non-destructive-mutation.md) — `with` copying mechanics, non-destructive updates, and shallow-copy caveats

### Pattern Matching & Switch

- [is-vs-as-vs-cast.md](./is-vs-as-vs-cast.md) — Type checks, safe casts, exception behavior, and `is T value`
- [list-patterns.md](./list-patterns.md) — C# 11+ sequence shape matching, slices, and switch-based routing
- [pattern-matching-overview.md](./pattern-matching-overview.md) — Constant, type, relational, logical, property, positional, and list patterns
- [property-and-positional-patterns.md](./property-and-positional-patterns.md) — Named-member matching, `Deconstruct`, nesting, and composition
- [switch-expressions.md](./switch-expressions.md) — Value-oriented branching, arm ordering, guards, and exhaustiveness

### Nullability & Null Handling

- [null-conditional-and-coalescing.md](./null-conditional-and-coalescing.md) — `?.`, `?[]`, `??`, `??=`, short-circuiting, and defaults
- [null-forgiving-operator.md](./null-forgiving-operator.md) — What postfix `!` changes, justified uses, and common smells
- [nullable-reference-types.md](./nullable-reference-types.md) — NRT annotations, warning contexts, flow analysis, and migration
- [nullable-value-types.md](./nullable-value-types.md) — `Nullable<T>`, lifting, `HasValue`, boxing behavior

### Reflection, Attributes & Source Generators

- [caller-info-attributes.md](./caller-info-attributes.md) — Caller metadata injection, `CallerArgumentExpression`, and diagnostics helpers
- [custom-attributes.md](./custom-attributes.md) — Defining metadata, `AttributeUsage`, and runtime retrieval
- [dynamic-code-with-emit-vs-expression.md](./dynamic-code-with-emit-vs-expression.md) — `Reflection.Emit`, expression compilation, and AOT/runtime-codegen trade-offs
- [reflection-basics.md](./reflection-basics.md) — `Type`, `MethodInfo`, `PropertyInfo`, activation, and AOT concerns
- [reflection-vs-source-generators.md](./reflection-vs-source-generators.md) — Runtime metadata vs compile-time generation, trimming, and Native AOT trade-offs
- [source-generators-intro.md](./source-generators-intro.md) — `IIncrementalGenerator`, `SyntaxProvider`, diagnostics, and BCL examples

### Memory & Performance

- [aggressive-inlining-and-attributes.md](./aggressive-inlining-and-attributes.md) — `MethodImpl` hints, `SkipLocalsInit`, and when low-level codegen tuning is justified
- [arraypool-and-memorypool.md](./arraypool-and-memorypool.md) — Renting/returning buffers, ownership, and reducing GC pressure
- [memory-of-t.md](./memory-of-t.md) — Heap-friendly buffer slices, async boundaries, and `.Span` usage rules
- [pinning-and-gc-handles.md](./pinning-and-gc-handles.md) — `fixed`, `GCHandle`, fragmentation, and interop lifetime trade-offs
- [span-of-t.md](./span-of-t.md) — `Span<T>`, slicing, `ReadOnlySpan<T>`, and zero-copy parsing
- [stackalloc.md](./stackalloc.md) — Stack allocation with spans, hot-path buffers, and size limits
- [unsafe-and-pointers.md](./unsafe-and-pointers.md) — `unsafe`, pointers, `fixed`, and when low-level code is justified

### Modern C# Features

- [collection-expressions.md](./collection-expressions.md) — C# 12 bracket syntax, spread elements, target typing, and custom builders
- [file-scoped-namespaces.md](./file-scoped-namespaces.md) — Flatter namespace syntax, one-namespace-per-file rules, and `.editorconfig` enforcement
- [global-and-implicit-usings.md](./global-and-implicit-usings.md) — `global using`, SDK-generated imports, and project-level control
- [params-collections-csharp-13.md](./params-collections-csharp-13.md) — C# 13 `params` on collection types, call-site lowering, and API design trade-offs
- [primary-constructors.md](./primary-constructors.md) — C# 12 constructor syntax, capture semantics, and good fit vs overuse
- [raw-string-literals.md](./raw-string-literals.md) — Triple-quoted strings, interpolation, indentation stripping, and JSON/SQL scenarios
- [required-members.md](./required-members.md) — `required`, `SetsRequiredMembers`, and object initialization contracts
- [target-typed-new.md](./target-typed-new.md) — Omitting repeated type names when the target type is already clear

### Misc Language Mechanics

- [checked-and-unchecked.md](./checked-and-unchecked.md) — Overflow behavior, `OverflowException`, and when checked arithmetic is worth the safety
- [implicit-vs-explicit-conversions.md](./implicit-vs-explicit-conversions.md) — Safe vs lossy conversions, casts, and checked conversion operators
- [local-functions-vs-lambdas.md](./local-functions-vs-lambdas.md) — Recursion, captures, iterator helpers, and allocation trade-offs
- [operator-overloading.md](./operator-overloading.md) — Natural operators, equality pairs, and conversion-operator design
- [readonly-vs-const.md](./readonly-vs-const.md) — Compile-time constants, runtime immutability, `static readonly`, and versioning gotchas
- [static-constructor-timing.md](./static-constructor-timing.md) — `beforefieldinit`, explicit static constructors, and one-time thread-safe initialization
- [tuple-types-and-deconstruction.md](./tuple-types-and-deconstruction.md) — `ValueTuple`, named elements, custom `Deconstruct`, and when to prefer a real type
- [using-aliases-and-using-static.md](./using-aliases-and-using-static.md) — Alias-any-type in C# 12, `using static`, and readability trade-offs
