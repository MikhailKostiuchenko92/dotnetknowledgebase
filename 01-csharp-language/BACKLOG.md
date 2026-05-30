# 📋 C# Language — Question Backlog

Master list of planned questions for the `01-csharp-language` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add a question on `configure-await-false` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'Async / await / Tasks' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `01-csharp-language/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(csharp): add question on <topic>`

---

## Progress

**Total:** 35 / 137
**By difficulty:** 🟢 9/24 · 🟡 19/64 · 🔴 7/49

---

## 1. Type system & memory semantics

- [x] 🟢 [`value-types-vs-reference-types.md`](./value-types-vs-reference-types.md) — Stack vs heap, copy semantics, equality
- [x] 🟡 [`boxing-and-unboxing.md`](./boxing-and-unboxing.md) — When it happens, perf impact, how to avoid
- [x] 🟢 [`stack-vs-heap.md`](./stack-vs-heap.md) — What lives where, common misconceptions
- [x] 🟡 [`pass-by-value-vs-by-reference.md`](./pass-by-value-vs-by-reference.md) — `ref`, `out`, `in`; passing reference types by value
- [x] 🟡 [`ref-out-in-parameters.md`](./ref-out-in-parameters.md) — Differences, use cases, restrictions
- [x] 🔴 [`ref-struct-and-ref-fields.md`](./ref-struct-and-ref-fields.md) — `ref struct`, why `Span<T>` is one, restrictions
- [x] 🟢 [`default-keyword-and-default-values.md`](./default-keyword-and-default-values.md) — `default(T)`, `default` literal
- [x] 🟡 [`nullable-value-types.md`](./nullable-value-types.md) — `Nullable<T>`, lifting, `HasValue` vs `?`
- [x] 🟡 [`dynamic-vs-object-vs-var.md`](./dynamic-vs-object-vs-var.md) — Compile-time vs runtime resolution
- [x] 🟡 [`equality-equals-vs-reference-equals.md`](./equality-equals-vs-reference-equals.md) — `==`, `Equals`, `ReferenceEquals`, contract
- [x] 🔴 [`gethashcode-contract.md`](./gethashcode-contract.md) — Rules, common bugs, dictionary key requirements
- [x] 🟡 [`idisposable-and-using.md`](./idisposable-and-using.md) — Dispose pattern, `using` statement/declaration, `IAsyncDisposable`

## 2. Strings

- [x] 🟢 [`string-immutability.md`](./string-immutability.md) — Why strings are immutable, implications
- [x] 🟡 [`string-interning.md`](./string-interning.md) — Intern pool, `string.Intern`, pros/cons
- [x] 🟡 [`stringbuilder-vs-string-concatenation.md`](./stringbuilder-vs-string-concatenation.md) — When to use, perf benchmarks
- [x] 🟡 [`string-comparison-and-culture.md`](./string-comparison-and-culture.md) — `Ordinal` vs `Culture`, `IgnoreCase`, common bugs
- [x] 🟢 [`string-interpolation-vs-format.md`](./string-interpolation-vs-format.md) — `$""`, `string.Format`, interpolated handlers (.NET 6+)
- [x] 🔴 [`utf8-strings-and-rune.md`](./utf8-strings-and-rune.md) — `u8` literals, `Rune`, encoding gotchas

## 3. Collections & LINQ

- [x] 🟢 [`array-vs-list-vs-linkedlist.md`](./array-vs-list-vs-linkedlist.md) — When to pick which, complexity
- [x] 🟡 [`dictionary-internals.md`](./dictionary-internals.md) — Hash buckets, collisions, load factor
- [x] 🟡 [`hashset-vs-sortedset.md`](./hashset-vs-sortedset.md) — Complexity, ordering, dedupe patterns
- [x] 🟡 [`ienumerable-vs-icollection-vs-ilist.md`](./ienumerable-vs-icollection-vs-ilist.md) — Hierarchy, when to expose what
- [x] 🔴 [`ienumerable-vs-iqueryable.md`](./ienumerable-vs-iqueryable.md) — Deferred execution, expression trees, EF Core impact
- [x] 🟡 [`deferred-vs-immediate-execution.md`](./deferred-vs-immediate-execution.md) — Lazy LINQ, `ToList`/`ToArray` triggers
- [x] 🟢 [`linq-method-vs-query-syntax.md`](./linq-method-vs-query-syntax.md) — Equivalence, readability trade-offs
- [x] 🟡 [`linq-common-pitfalls.md`](./linq-common-pitfalls.md) — Multiple enumeration, side effects, captured variables
- [x] 🟢 [`select-vs-selectmany.md`](./select-vs-selectmany.md) — Projection vs flattening, examples
- [x] 🟡 [`groupby-and-tolookup.md`](./groupby-and-tolookup.md) — Differences, when to use each
- [x] 🟡 [`aggregate-and-reductions.md`](./aggregate-and-reductions.md) — `Aggregate`, `Sum`, `Min`, accumulator patterns
- [x] 🔴 [`concurrent-collections.md`](./concurrent-collections.md) — `ConcurrentDictionary`, `ConcurrentBag`, `BlockingCollection`
- [x] 🟡 [`immutablecollections.md`](./immutablecollections.md) — `ImmutableArray`, `ImmutableList`, when to use
- [x] 🟡 [`frozencollections.md`](./frozencollections.md) — `FrozenDictionary`/`FrozenSet` (.NET 8), perf use cases

## 4. Generics

- [x] 🟢 [`generics-basics.md`](./generics-basics.md) — Type parameters, why generics exist
- [x] 🟡 [`generic-constraints.md`](./generic-constraints.md) — `where T : class/struct/new()/IComparable/...`
- [x] 🔴 [`covariance-and-contravariance.md`](./covariance-and-contravariance.md) — `in`/`out`, real-world examples, array covariance
- [ ] 🟡 `generic-method-vs-generic-class.md` — When to put generics where
- [ ] 🟡 `generic-type-inference.md` — When the compiler can/can't infer
- [ ] 🔴 `static-members-in-generic-types.md` — Per-closed-type statics, generic math (`INumber<T>`)

## 5. Delegates, events, lambdas

- [ ] 🟢 `delegates-explained.md` — What they are, `Action`/`Func`/`Predicate`
- [ ] 🟡 `multicast-delegates.md` — Invocation list, return values, exceptions
- [ ] 🟡 `events-vs-delegates.md` — Why events exist, encapsulation, conventions
- [ ] 🔴 `event-memory-leaks.md` — Subscriber leaks, weak events, unsubscribe patterns
- [ ] 🟡 `lambda-expressions-and-closures.md` — Captured variables, allocation cost, bugs
- [ ] 🔴 `expression-trees.md` — `Expression<Func<T>>`, EF usage, building dynamically
- [ ] 🟢 `func-vs-action-vs-predicate.md` — When to use each, return semantics

## 6. Async / await / Tasks

- [ ] 🟡 `async-await-fundamentals.md` — State machine, continuation, what `async` does
- [ ] 🟡 `task-vs-thread.md` — Abstraction, when not to use threads directly
- [ ] 🔴 `task-vs-valuetask.md` — When `ValueTask` helps, allocation savings, restrictions
- [ ] 🔴 `configure-await-false.md` — When/why, library vs app code, .NET 6+ behavior
- [ ] 🔴 `synchronization-context.md` — ASP.NET classic vs Core, WPF/WinForms, continuations
- [ ] 🟡 `async-void-pitfalls.md` — Why to avoid, only-for-event-handlers rule
- [ ] 🔴 `deadlocks-with-result-and-wait.md` — `.Result`/`.Wait()` deadlock, how to fix
- [ ] 🟡 `cancellation-tokens.md` — Cooperative cancellation, propagation, `OperationCanceledException`
- [ ] 🟡 `task-whenall-vs-whenany.md` — Parallel awaits, exception aggregation
- [ ] 🟡 `parallel-foreach-vs-task-whenall.md` — CPU-bound vs IO-bound
- [ ] 🔴 `iasyncenumerable.md` — `await foreach`, streaming data, `ConfigureAwait` on streams
- [ ] 🔴 `task-completion-source.md` — Bridging callback APIs, `RunContinuationsAsynchronously`
- [ ] 🟡 `async-exception-handling.md` — Where exceptions surface, unawaited tasks
- [ ] 🟡 `progress-reporting-iprogress.md` — `IProgress<T>`, `Progress<T>`, threading guarantees
- [ ] 🔴 `async-streams-vs-channels.md` — `IAsyncEnumerable` vs `Channel<T>`, producer/consumer
- [ ] 🟡 `cpu-bound-vs-io-bound-async.md` — `Task.Run` rules, why not to wrap IO

## 7. Threading & concurrency

- [ ] 🟡 `thread-vs-threadpool.md` — When to create vs queue, cost of threads
- [ ] 🟡 `lock-and-monitor.md` — Reentrancy, what `lock` compiles to, what to lock on
- [ ] 🟡 `semaphoreslim-and-mutex.md` — Cross-process vs in-process, async-aware locking
- [ ] 🟡 `interlocked-operations.md` — Atomic ops, `CompareExchange` patterns
- [ ] 🔴 `volatile-and-memory-barriers.md` — Memory model, when `volatile` is/isn't enough
- [ ] 🟡 `reader-writer-lockslim.md` — When it pays off, upgradeable locks
- [ ] 🟡 `thread-safety-of-collections.md` — What's safe, what's not, bugs
- [ ] 🔴 `producer-consumer-with-channel.md` — `Channel<T>` patterns, bounded vs unbounded
- [ ] 🟡 `parallel-class-and-plinq.md` — When PLINQ helps/hurts, partitioning
- [ ] 🔴 `thread-local-storage.md` — `ThreadLocal<T>`, `AsyncLocal<T>` differences

## 8. Exceptions

- [ ] 🟢 `exception-handling-fundamentals.md` — `try/catch/finally`, exception hierarchy
- [ ] 🟡 `exception-filters-when.md` — `catch (Ex) when (...)`, stack preservation
- [ ] 🟡 `throw-vs-throw-ex.md` — Stack trace preservation, `ExceptionDispatchInfo`
- [ ] 🟡 `custom-exceptions-best-practices.md` — When to create, serialization, naming
- [ ] 🔴 `cost-of-exceptions.md` — Perf cost, control flow anti-pattern, first-chance exceptions

## 9. OOP in C#

- [ ] 🟢 `class-vs-struct.md` — When to choose which, semantic differences
- [ ] 🟡 `abstract-class-vs-interface.md` — Use cases, default interface methods (C# 8+)
- [ ] 🔴 `interface-default-implementations.md` — What's allowed, diamond problem, versioning
- [ ] 🟡 `virtual-override-new-keywords.md` — Polymorphism, hiding vs overriding
- [ ] 🟡 `sealed-classes-and-methods.md` — Perf and design reasons
- [ ] 🟢 `static-classes-and-members.md` — When to use, lifetime, testability impact
- [ ] 🟡 `extension-methods.md` — How they're resolved, pitfalls, when to avoid
- [ ] 🟡 `partial-classes-and-methods.md` — Use cases, source generators
- [ ] 🟡 `constructors-chaining-and-static.md` — `: this(...)`, `: base(...)`, static ctor timing
- [ ] 🔴 `finalizer-and-dispose-pattern.md` — When to write a finalizer, full dispose pattern

## 10. Records, structs, immutability

- [ ] 🟡 `records-vs-classes.md` — Value equality, `with` expressions, when to use
- [ ] 🟡 `record-struct-vs-record-class.md` — Differences, defaults, perf
- [ ] 🟡 `readonly-struct.md` — Defensive copies, when to use
- [ ] 🟡 `init-only-properties.md` — `init` accessors, immutability patterns
- [ ] 🟡 `with-expressions-and-non-destructive-mutation.md` — How `with` works
- [ ] 🟡 `value-equality-in-records.md` — Generated `Equals`/`GetHashCode`, customization

## 11. Pattern matching & switch

- [ ] 🟡 `pattern-matching-overview.md` — Type, property, positional, relational, list patterns
- [ ] 🟡 `switch-expressions.md` — vs switch statements, exhaustiveness
- [ ] 🟡 `property-and-positional-patterns.md` — Destructuring with `Deconstruct`
- [ ] 🔴 `list-patterns.md` — C# 11 list patterns, slicing
- [ ] 🟢 `is-vs-as-vs-cast.md` — Differences, perf, pattern variants

## 12. Nullability & null handling

- [ ] 🟡 `nullable-reference-types.md` — Annotation/warning contexts, project-level enablement
- [ ] 🟢 `null-conditional-and-coalescing.md` — `?.`, `??`, `??=` patterns
- [ ] 🟡 `null-forgiving-operator.md` — `!` operator — when justified, when a smell
- [ ] 🔴 `nullability-attributes.md` — `MaybeNull`, `NotNull`, `MemberNotNull`, etc.
- [ ] 🟡 `argument-null-validation-patterns.md` — `ArgumentNullException.ThrowIfNull`, guards
- [ ] 🔴 `nullable-in-generics.md` — `T?` for unconstrained generics, `default(T)` quirks

## 13. Iterators, `yield`, ranges

- [ ] 🟡 `yield-return-explained.md` — Compiler state machine, deferred execution
- [ ] 🟡 `custom-iterators.md` — Implementing `IEnumerable<T>`, when `yield` shines
- [ ] 🟢 `range-and-index-operators.md` — `^`, `..`, what types support them
- [ ] 🔴 `iterator-vs-async-iterator.md` — `IEnumerable<T>` vs `IAsyncEnumerable<T>`
- [ ] 🟡 `enumerator-vs-enumerable.md` — Roles, common confusion

## 14. Reflection, attributes, source generators

- [ ] 🟡 `reflection-basics.md` — `Type`, `MethodInfo`, perf cost
- [ ] 🟡 `custom-attributes.md` — Defining, reading, common framework attributes
- [ ] 🔴 `reflection-vs-source-generators.md` — Trade-offs, AOT compatibility
- [ ] 🔴 `dynamic-code-with-emit-vs-expression.md` — `Reflection.Emit`, `Expression.Compile`
- [ ] 🔴 `source-generators-intro.md` — What they are, real examples (regex, logging, json)
- [ ] 🟡 `caller-info-attributes.md` — `[CallerMemberName]`, `[CallerArgumentExpression]`

## 15. Memory & performance

- [ ] 🔴 `span-of-t.md` — What it is, why it's a `ref struct`, slicing
- [ ] 🔴 `memory-of-t.md` — vs `Span<T>`, when heap-friendliness matters
- [ ] 🔴 `stackalloc.md` — Safe `Span<T>` form, size limits
- [ ] 🔴 `arraypool-and-memorypool.md` — Renting/returning, avoiding GC pressure
- [ ] 🔴 `unsafe-and-pointers.md` — When `unsafe` is justified, `fixed` statement
- [ ] 🔴 `pinning-and-gc-handles.md` — `GCHandle`, `fixed`, interop
- [ ] 🔴 `aggressive-inlining-and-attributes.md` — `MethodImplOptions`, JIT inlining

## 16. Modern C# features (12 / 13)

- [ ] 🟡 `primary-constructors.md` — Class & struct primary ctors, capture semantics
- [ ] 🟡 `collection-expressions.md` — `[1, 2, 3]` syntax, spread operator `..`
- [ ] 🟡 `required-members.md` — `required` keyword, `SetsRequiredMembers`
- [ ] 🟢 `file-scoped-namespaces.md` — Why preferred, conversion
- [ ] 🟡 `global-and-implicit-usings.md` — `global using`, `<ImplicitUsings>` SDK behavior
- [ ] 🟢 `raw-string-literals.md` — `"""..."""`, interpolation in raw strings
- [ ] 🟢 `target-typed-new.md` — `Foo f = new();` — when it helps/hurts readability
- [ ] 🟡 `params-collections-csharp-13.md` — `params` for any collection type (C# 13)

## 17. Misc language mechanics

- [ ] 🟢 `readonly-vs-const.md` — Compile-time vs runtime, versioning gotcha
- [ ] 🟡 `static-constructor-timing.md` — `beforefieldinit`, when it runs
- [ ] 🟡 `operator-overloading.md` — When appropriate, equality operators, conversion ops
- [ ] 🟡 `implicit-vs-explicit-conversions.md` — When to define each, lossy conversions
- [ ] 🟡 `checked-and-unchecked.md` — Overflow behavior, when to use
- [ ] 🟢 `tuple-types-and-deconstruction.md` — `ValueTuple`, naming, `Deconstruct`
- [ ] 🟡 `local-functions-vs-lambdas.md` — When to prefer each, allocation differences
- [ ] 🟢 `using-aliases-and-using-static.md` — Modern uses, C# 12 alias-any-type feature

---

## Suggested learning order

If you'd rather work through this list pedagogically instead of top-to-bottom:

1. **Foundations** → §1, §2, §9
2. **Collections fluency** → §3, §4
3. **Async mastery** → §6, then §7
4. **Modern C#** → §10, §11, §12, §16
5. **Performance & internals** → §15, §14, §13
6. **Polish** → §5, §8, §17