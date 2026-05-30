# Frozen Collections

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `FrozenDictionary`, `FrozenSet`, `read-only`, `performance`, `.NET 8`, `lookup`

## Question

> What are `FrozenDictionary<TKey, TValue>` and `FrozenSet<T>` introduced in .NET 8? When should you use them instead of `Dictionary<TKey, TValue>` or `ImmutableDictionary<TKey, TValue>`?

Additional phrasings:
- *"Why is `FrozenDictionary` faster than `Dictionary` for reads?"*
- *"What is the trade-off between construction cost and lookup speed in frozen collections?"*

## Short Answer

`FrozenDictionary<TKey, TValue>` and `FrozenSet<T>` (in `System.Collections.Frozen`, .NET 8+) are read-only collections optimized for **repeated, high-frequency lookups** on data that is set up once and never changes. They spend extra time at construction to analyze key distribution and pick an optimal internal layout (e.g., a minimal perfect hash or a length-bucketed lookup for strings), then deliver faster `ContainsKey`/`TryGetValue` than `Dictionary<K,V>` at runtime. Use them for static configuration, lookup tables, and caches built once at startup.

## Detailed Explanation

### The Problem They Solve

A regular `Dictionary<K,V>` is optimized for the general case: efficient inserts, deletes, and lookups at any time. When a dictionary is built **once** (at startup, from config, from a database query) and then only read for the lifetime of the application, it carries unnecessary overhead:

- The hash bucket structure is sized for load-factor management.
- Every lookup does modulo arithmetic + equality check chain.
- The backing arrays are general-purpose sized.

If you know upfront that the data is fixed, you can invest more time at construction to build a more optimal lookup structure.

### How Frozen Collections Achieve Speed

At construction time (`.ToFrozenDictionary()` / `.ToFrozenSet()`), the implementation:

1. **Analyzes key distribution.** For small collections (< ~10 items), it may use a linear scan — simpler and cache-friendly.
2. **Selects an optimal strategy.** For `string` keys, it can use a **length-based lookup** (first check key length, then compare only keys of that length) or a **minimal perfect hash** function specific to this exact set of keys.
3. **Lays out data for cache efficiency.** Keys and values are stored contiguously in arrays optimized for read access, not for insertion.

The result: **`ContainsKey` and `TryGetValue` are measurably faster** than `Dictionary<K,V>` for many workloads (often 30–200% depending on key type, count, and access pattern). Construction is slower — sometimes significantly — but this cost is paid once.

### `FrozenDictionary<TKey, TValue>`

```csharp
FrozenDictionary<string, int> frozen = new Dictionary<string, int>
{
    ["one"] = 1, ["two"] = 2, ["three"] = 3
}.ToFrozenDictionary(StringComparer.OrdinalIgnoreCase);
```

Properties:
- **Read-only** — no `Add`, `Remove`, `Clear`.
- **Implements `IReadOnlyDictionary<K,V>`** — compatible with existing APIs.
- **`Count` is O(1).**
- **`TryGetValue` / `ContainsKey` are optimized** for the specific key set.

### `FrozenSet<T>`

```csharp
FrozenSet<string> keywords = new[] { "if", "else", "for", "while", "return" }
    .ToFrozenSet(StringComparer.Ordinal);

Console.WriteLine(keywords.Contains("for")); // optimized lookup
```

### Comparison Table

| Collection | Reads | Writes | Construction | Thread-safe reads |
|---|---|---|---|---|
| `Dictionary<K,V>` | O(1) avg | O(1) amortized | O(n) | ❌ No |
| `ImmutableDictionary<K,V>` | O(log n) | O(log n) new version | O(n log n) | ✅ Yes |
| `FrozenDictionary<K,V>` | **O(1) optimized** | ❌ Not supported | O(n) + analysis | ✅ Yes |
| `ReadOnlyDictionary<K,V>` | O(1) | ❌ Not supported | O(1) wrapper | ❌ No (wraps mutable) |

### When to Use Which

| Scenario | Best choice |
|---|---|
| General-purpose mutable dictionary | `Dictionary<K,V>` |
| Shared state updated concurrently | `ConcurrentDictionary<K,V>` |
| Versioned/persistent dictionary | `ImmutableDictionary<K,V>` |
| Read-only, built at startup, high-frequency lookup | **`FrozenDictionary<K,V>`** |
| Read-only wrapper around existing dict | `ReadOnlyDictionary<K,V>` |

### Practical Use Cases

- **HTTP routing tables** — route patterns are fixed at startup; requests look them up thousands of times per second.
- **Config/feature flag lookups** — keys are loaded once, read on every request.
- **Tokenizer keyword sets** — a compiler or parser's reserved-word set.
- **Static enum-to-display-name maps** — built once from reflection, read in every render cycle.
- **CORS, auth policy, middleware config** — ASP.NET Core internals use frozen collections for exactly this.

### The Builder API

For constructing incrementally before freezing:

```csharp
var dict = new Dictionary<string, int>();
// ... populate ...
FrozenDictionary<string, int> frozen = dict.ToFrozenDictionary();
```

There is no explicit builder type — the LINQ-style `.ToFrozenDictionary()` / `.ToFrozenSet()` extension methods handle construction.

[See: immutablecollections.md](./immutablecollections.md) for comparison with immutable collections.
[See: dictionary-internals.md](./dictionary-internals.md) for how regular `Dictionary` works.

## Code Example

```csharp
using System.Collections.Frozen;
using System.Collections.Generic;

// === FrozenDictionary: build once at startup ===
static readonly FrozenDictionary<string, int> HttpStatusCodes =
    new Dictionary<string, int>
    {
        ["OK"]                  = 200,
        ["Created"]             = 201,
        ["BadRequest"]          = 400,
        ["Unauthorized"]        = 401,
        ["NotFound"]            = 404,
        ["InternalServerError"] = 500,
    }.ToFrozenDictionary(StringComparer.OrdinalIgnoreCase);

// Hot path — called thousands of times per second
static int GetStatus(string name)
    => HttpStatusCodes.TryGetValue(name, out int code) ? code : -1;

Console.WriteLine(GetStatus("notfound")); // 404 — case-insensitive match

// === FrozenSet: keyword lookup ===
static readonly FrozenSet<string> CSharpKeywords =
    new[] { "class", "struct", "record", "interface", "enum",
            "namespace", "using", "if", "else", "for", "while",
            "return", "var", "new", "this", "base", "null", "true", "false" }
    .ToFrozenSet(StringComparer.Ordinal);

static bool IsKeyword(string token) => CSharpKeywords.Contains(token);

Console.WriteLine(IsKeyword("record")); // true
Console.WriteLine(IsKeyword("order"));  // false

// === Performance comparison (illustrative — use BenchmarkDotNet for real numbers) ===
// For a set of 50 string keys, FrozenDictionary.TryGetValue is typically
// 30–50% faster than Dictionary.TryGetValue due to optimized hash strategy.

// === FrozenDictionary implements IReadOnlyDictionary ===
IReadOnlyDictionary<string, int> readOnly = HttpStatusCodes;
Console.WriteLine(readOnly["OK"]); // 200

// === Construction: LINQ projection ===
var records = new[] { ("Alice", 30), ("Bob", 25), ("Charlie", 35) };
FrozenDictionary<string, int> byName = records
    .ToFrozenDictionary(r => r.Item1, r => r.Item2);

Console.WriteLine(byName["Alice"]); // 30

// === FrozenSet from existing HashSet ===
var mutableSet = new HashSet<int> { 1, 2, 3, 4, 5 };
FrozenSet<int> frozenSet = mutableSet.ToFrozenSet();
Console.WriteLine(frozenSet.Contains(3)); // true
```

## Common Follow-up Questions

- How does `FrozenDictionary` choose between a perfect hash, a length-based strategy, and a linear scan?
- What is the construction time cost of `ToFrozenDictionary` compared to populating a `Dictionary`?
- Can `FrozenDictionary` be used across threads without locks?
- How does `FrozenDictionary` compare to third-party perfect hash libraries like `gperf` or `NetEscapades.EnumGenerators`?
- What happens if you call `ToFrozenDictionary()` on an empty collection?
- Is there a `FrozenList<T>` or similar in .NET 8?

## Common Mistakes / Pitfalls

- **Using `FrozenDictionary` for frequently updated data.** Frozen collections cannot be modified. Any update requires rebuilding the entire collection from scratch and re-freezing — an O(n) operation. Use only for truly static data.
- **Freezing inside a hot path.** `ToFrozenDictionary()` is expensive — do it once at startup (or in `IHostedService.StartAsync`, `IApplicationBuilder` configuration, or a `static readonly` initializer), never inside a per-request code path.
- **Assuming `FrozenDictionary` is always faster.** For very small collections (< 5 items), a `Dictionary` or even a `switch` expression may be faster. For large collections with poor key distribution, the analysis phase may not produce a faster layout. Benchmark your specific case.
- **Confusing with `ReadOnlyDictionary<K,V>`.** `ReadOnlyDictionary<K,V>` is a mutable dictionary wrapped in a read-only view — the underlying dictionary can still be modified externally. `FrozenDictionary` is truly immutable and optimized for reads.
- **Not specifying a `StringComparer`.** Omitting the comparer defaults to `EqualityComparer<TKey>.Default` (ordinal, case-sensitive for strings). If you need case-insensitive lookup, pass `StringComparer.OrdinalIgnoreCase` explicitly.

## References

- [FrozenDictionary<TKey,TValue> — .NET 8 API](https://learn.microsoft.com/dotnet/api/system.collections.frozen.frozendictionary-2)
- [FrozenSet<T> — .NET 8 API](https://learn.microsoft.com/dotnet/api/system.collections.frozen.frozenset-1)
- [System.Collections.Frozen — .NET 8 what's new](https://learn.microsoft.com/dotnet/core/whats-new/dotnet-8/runtime#frozen-collections)
- [Frozen collections design — .NET runtime GitHub](https://github.com/dotnet/runtime/issues/67209) (verify URL)
