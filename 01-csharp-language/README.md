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
- [generics-basics.md](./generics-basics.md) — Type parameters, JIT specialization, generic classes vs methods