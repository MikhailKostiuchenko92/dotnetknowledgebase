# `GroupBy` and `ToLookup`

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `LINQ`, `GroupBy`, `ToLookup`, `IGrouping`, `ILookup`, `grouping`, `deferred-execution`

## Question

> What is the difference between `GroupBy` and `ToLookup` in LINQ? When should you use each?

Additional phrasings:
- *"Why does `ToLookup` execute immediately while `GroupBy` is deferred?"*
- *"What does `IGrouping<TKey, TElement>` represent?"*

## Short Answer

Both partition a sequence into groups by key. `GroupBy` is **deferred** — it returns an `IEnumerable<IGrouping<TKey, TElement>>` that re-executes the grouping on every enumeration. `ToLookup` is **immediate** — it materializes all groups into an `ILookup<TKey, TElement>`, a read-only dictionary-of-lists that supports O(1) key lookup. Use `GroupBy` when you will enumerate the groups once in a pipeline (e.g., to produce a result set). Use `ToLookup` when you need to look up groups by key multiple times, or when you need the groups to persist in memory as a reusable structure.

## Detailed Explanation

### `IGrouping<TKey, TElement>`

Both operators produce groups typed as `IGrouping<TKey, TElement>`, which extends `IEnumerable<TElement>` and adds a `Key` property:

```csharp
public interface IGrouping<out TKey, out TElement> : IEnumerable<TElement>
{
    TKey Key { get; }
}
```

Enumerating an `IGrouping<K, E>` yields the elements in that group.

### `GroupBy` — Deferred Grouping

`GroupBy` is a **deferred, buffered** operator:
- It does **not** iterate the source until the result is consumed.
- Once enumeration starts, it **buffers the entire source** to form groups (it must see all elements before it can determine the groups).
- Re-enumerating the `GroupBy` result re-buffers everything.

`GroupBy` is appropriate in a LINQ pipeline when you want to process groups as they're produced but don't need to look them up by key:

```csharp
var summary = source
    .GroupBy(x => x.Category)
    .Select(g => new { Category = g.Key, Count = g.Count() });
// The GroupBy runs once when this pipeline is materialized
```

For `IQueryable<T>` (EF Core), `GroupBy` is translated to a SQL `GROUP BY` clause.

### `ToLookup` — Immediate Grouped Dictionary

`ToLookup` materializes immediately into an `ILookup<TKey, TElement>`:
- **O(1) key access** via `lookup[key]` — backed by a hash table.
- If a key is absent, returns an **empty sequence** (not `null`, not exception — unlike `Dictionary`).
- Read-only — no `Add` or `Remove`.
- Built once, queryable many times.

```
ILookup<string, Order> layout:
  "Fruit"  → [banana, apple]
  "Veggie" → [carrot, daikon]
lookup["Fruit"][0]  → banana   (O(1))
lookup["Unknown"]   → empty IEnumerable (no exception)
```

### Key Differences

| Feature | `GroupBy` | `ToLookup` |
|---|---|---|
| Execution | Deferred | Immediate |
| Returns | `IEnumerable<IGrouping<K,E>>` | `ILookup<K,E>` |
| Key lookup by index | ❌ No | ✅ `lookup[key]` O(1) |
| Missing key | — | Returns empty sequence |
| Re-enumerable safely | ❌ Re-executes pipeline | ✅ Already materialized |
| EF Core translatable | ✅ → `GROUP BY` SQL | ❌ (forces client eval) |
| Use case | Single-pass pipeline, SQL | Multi-lookup, in-memory caching |

### `GroupBy` with Element Projection

Both operators have overloads to project elements and compare keys:

```csharp
// Project the grouped elements
var grouped = products.GroupBy(
    p => p.Category,            // key selector
    p => p.Name);               // element selector → groups of strings, not products

// Custom key comparer
var caseInsensitive = words.GroupBy(
    w => w,
    StringComparer.OrdinalIgnoreCase);
```

### When `ToLookup` Shines

A classic use case: building an in-memory join structure:

```csharp
// Pre-build lookup of orders indexed by CustomerId
ILookup<int, Order> ordersByCustomer = allOrders.ToLookup(o => o.CustomerId);

// Now for each customer, get orders in O(1) — no repeated LINQ queries
foreach (var customer in customers)
{
    IEnumerable<Order> orders = ordersByCustomer[customer.Id]; // O(1) hash lookup
    ProcessOrders(customer, orders);
}
```

Doing this with `GroupBy` would re-execute the grouping on every access; with `ToLookup` it's computed once.

[See: deferred-vs-immediate-execution.md](./deferred-vs-immediate-execution.md) for the broader deferred/immediate execution discussion.
[See: dictionary-internals.md](./dictionary-internals.md) for how the underlying hash table works.

## Code Example

```csharp
using System.Linq;

var products = new[]
{
    new { Name = "Apple",     Category = "Fruit",  Price = 1.2m },
    new { Name = "Banana",    Category = "Fruit",  Price = 0.5m },
    new { Name = "Carrot",    Category = "Veggie", Price = 0.8m },
    new { Name = "Daikon",    Category = "Veggie", Price = 1.5m },
    new { Name = "Elderberry",Category = "Fruit",  Price = 3.0m },
};

// === GroupBy: deferred — use in pipeline ===
var summary = products
    .GroupBy(p => p.Category)
    .Select(g => new
    {
        Category = g.Key,
        Count    = g.Count(),
        AvgPrice = g.Average(p => p.Price),
        Names    = string.Join(", ", g.Select(p => p.Name))
    });

foreach (var s in summary)
    Console.WriteLine($"{s.Category}: {s.Count} items, avg ${s.AvgPrice:F2} — {s.Names}");
// Fruit:  3 items, avg $1.57 — Apple, Banana, Elderberry
// Veggie: 2 items, avg $1.15 — Carrot, Daikon

// === GroupBy with element selector ===
var namesByCategory = products
    .GroupBy(p => p.Category, p => p.Name); // groups contain names, not full products
foreach (var g in namesByCategory)
    Console.WriteLine($"{g.Key}: {string.Join(", ", g)}");

// === ToLookup: immediate, O(1) key access ===
ILookup<string, string> lookup = products.ToLookup(
    p => p.Category,
    p => p.Name);

Console.WriteLine(lookup["Fruit"].Count()); // 3 — instant
Console.WriteLine(lookup["Dairy"].Count()); // 0 — missing key → empty, NOT exception

// Access specific group
foreach (var name in lookup["Veggie"])
    Console.WriteLine(name); // Carrot, Daikon

// === ToLookup as in-memory join structure ===
var orders = new[]
{
    new { CustomerId = 1, Product = "Widget" },
    new { CustomerId = 2, Product = "Gadget" },
    new { CustomerId = 1, Product = "Gizmo"  },
};
var customers = new[] { new { Id = 1, Name = "Alice" }, new { Id = 2, Name = "Bob" } };

ILookup<int, string> ordersByCustomer = orders.ToLookup(o => o.CustomerId, o => o.Product);

foreach (var c in customers)
{
    var customerOrders = ordersByCustomer[c.Id]; // O(1)
    Console.WriteLine($"{c.Name}: {string.Join(", ", customerOrders)}");
}
// Alice: Widget, Gizmo
// Bob: Gadget
```

## Common Follow-up Questions

- How does `GroupBy` behave in EF Core — does it always translate to SQL `GROUP BY`?
- What is the difference between `ToLookup` and `ToDictionary` with a list value?
- Can you modify an `ILookup<K,V>` after creation? What about `IGrouping<K,V>`?
- How does `GroupBy` preserve the order of elements within each group?
- What happens if the key selector in `GroupBy` returns `null`?

## Common Mistakes / Pitfalls

- **Using `GroupBy` as a lookup structure and calling `.Where(g => g.Key == key)` each time.** This re-executes the group scan on every call — O(n) per lookup. Use `ToLookup` for key-based retrieval.
- **Expecting a missing `ToLookup` key to throw.** Unlike `Dictionary`, `ILookup` returns an empty sequence for missing keys — no `KeyNotFoundException`. This is usually desirable but can mask bugs if you expect the key to always exist.
- **Re-enumerating a `GroupBy` result repeatedly.** Since `GroupBy` is deferred and buffered, re-enumerating re-buffers the entire source. Assign to a list or `ToLookup` if you need multiple passes.
- **Using `GroupBy` with `IQueryable<T>` and then calling `ToLookup`.** Calling `ToLookup` on an `IQueryable<T>` forces client-side evaluation — it pulls all data into memory before grouping. Use `GroupBy` on `IQueryable<T>` and project in SQL; only `ToLookup` in-memory.
- **Forgetting that `GroupBy` is stable.** Elements within each group appear in source order, and groups appear in the order their key is first encountered. This is part of the LINQ spec.

## References

- [Enumerable.GroupBy — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.groupby)
- [Enumerable.ToLookup — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.tolookup)
- [ILookup<TKey,TElement> — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.ilookup-2)
- [Grouping data in LINQ — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/linq/standard-query-operators/grouping-data)
