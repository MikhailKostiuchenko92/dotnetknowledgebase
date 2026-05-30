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

- [string-immutability.md](./string-immutability.md) — Why strings are immutable, allocation implications
- [string-interning.md](./string-interning.md) — Intern pool mechanics, when to use/avoid `string.Intern`
- [stringbuilder-vs-string-concatenation.md](./stringbuilder-vs-string-concatenation.md) — O(n²) vs O(n), decision guide, .NET 6+ alternatives