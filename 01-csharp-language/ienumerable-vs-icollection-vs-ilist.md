# `IEnumerable<T>` vs `ICollection<T>` vs `IList<T>`

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `IEnumerable`, `ICollection`, `IList`, `interfaces`, `collection-hierarchy`, `API-design`

## Question

> What is the difference between `IEnumerable<T>`, `ICollection<T>`, and `IList<T>`? When should you expose each from a public API?

Additional phrasings:
- *"Why would you return `IEnumerable<T>` instead of `List<T>` from a method?"*
- *"What additional capabilities does `IList<T>` provide over `ICollection<T>`?"*

## Short Answer

These interfaces form a hierarchy of increasing capability: `IEnumerable<T>` allows forward-only iteration; `ICollection<T>` adds `Count`, `Contains`, `Add`, `Remove`, and `Clear`; `IList<T>` further adds indexed access (`this[int]`), `IndexOf`, `Insert`, and `RemoveAt`. As a general rule, **accept the least powerful interface that satisfies your needs** (Liskov/robustness) and **return the most specific type that callers can reasonably use** — but prefer `IReadOnlyList<T>` or `IReadOnlyCollection<T>` over mutable interfaces when the caller shouldn't mutate the collection.

## Detailed Explanation

### The Interface Hierarchy

```
IEnumerable<T>
  └─ ICollection<T>
       └─ IList<T>

IEnumerable<T>         (also: IReadOnlyCollection<T>, IReadOnlyList<T>)
  └─ IReadOnlyCollection<T>
       └─ IReadOnlyList<T>
```

### `IEnumerable<T>` — Forward-Only Iteration

The most basic contract: "you can iterate over me."

Members:
- `IEnumerator<T> GetEnumerator()` — the only member (plus the non-generic version from `IEnumerable`).

Properties:
- Can be a lazy sequence (LINQ pipeline, `yield return`) — **not materialized in memory**.
- Can be enumerated **once** (some sequences: network streams, generators).
- **No `Count`** — getting the count requires full enumeration.
- **No random access.**

Use for: method parameters where you only need to iterate; lazy sequences; LINQ chains.

> **Warning — multiple enumeration:** if the caller enumerates an `IEnumerable<T>` twice, a lazy sequence (e.g., a LINQ query) will execute twice. If the underlying source has side effects or is expensive, this is a bug. See [linq-common-pitfalls.md](./linq-common-pitfalls.md).

### `ICollection<T>` — Countable, Mutable Set

Adds to `IEnumerable<T>`:
- `int Count` — O(1) for materialized collections.
- `bool Contains(T item)` — existence check.
- `void Add(T item)`, `bool Remove(T item)`, `void Clear()` — mutation.
- `void CopyTo(T[] array, int arrayIndex)` — bulk copy.
- `bool IsReadOnly` — indicates mutability.

Use for: parameters that need to know the count without enumerating, or that need to add/remove elements.

### `IList<T>` — Indexed Access

Adds to `ICollection<T>`:
- `T this[int index]` — get/set by index (O(1) for arrays/lists, O(n) for `LinkedList<T>`).
- `int IndexOf(T item)` — position lookup.
- `void Insert(int index, T item)`, `void RemoveAt(int index)` — positional mutation.

Use for: APIs that need positional access (sorting, pagination, indexed rendering).

### Read-Only Counterparts (Prefer These)

The mutable interfaces allow callers to `Add`, `Remove`, and `Clear` the collection you return. Often this is undesirable:

| Mutable | Read-only equivalent | Members |
|---|---|---|
| `IEnumerable<T>` | `IEnumerable<T>` (same) | Iteration only |
| `ICollection<T>` | `IReadOnlyCollection<T>` | `Count` + iteration |
| `IList<T>` | `IReadOnlyList<T>` | `Count` + iteration + `this[int]` |
| `IDictionary<K,V>` | `IReadOnlyDictionary<K,V>` | `Keys`, `Values`, `TryGetValue` |

`IReadOnlyList<T>` is the sweet spot for most return types: callers can iterate, count, and index — but cannot mutate.

### API Design Guidelines

**Parameters (what you accept):**
- Prefer `IEnumerable<T>` for read-only iteration.
- Prefer `IReadOnlyList<T>` / `IReadOnlyCollection<T>` when you need count/indexing.
- Only accept `IList<T>` or `ICollection<T>` if you intend to mutate the caller's collection.

**Return types (what you expose):**
- Return `IReadOnlyList<T>` (or `IReadOnlyCollection<T>`) to share the collection without permitting mutation.
- Return `IEnumerable<T>` for lazy sequences that should not be materialized eagerly.
- Avoid returning `List<T>` from public APIs — it forces callers to depend on the concrete type and prevents you from switching implementations.

```
Good: public IReadOnlyList<Customer> GetCustomers() { ... }
Avoid: public List<Customer> GetCustomers() { ... }  // exposes concrete type unnecessarily
```

### `IAsyncEnumerable<T>`

For streaming / async sequences (database cursor, HTTP paginated response), use `IAsyncEnumerable<T>` — the async analogue of `IEnumerable<T>`, consumed with `await foreach`. [See: iasyncenumerable.md](./iasyncenumerable.md).

## Code Example

```csharp
using System.Collections.Generic;
using System.Linq;

// === Accepting least-powerful interface ===
static int CountEvens(IEnumerable<int> source)  // only need iteration
    => source.Count(x => x % 2 == 0);

static void AddAll<T>(ICollection<T> target, IEnumerable<T> source) // need Add
{
    foreach (var item in source) target.Add(item);
}

static T GetMiddle<T>(IReadOnlyList<T> list)    // need count + indexer
    => list[list.Count / 2];

// === Returning read-only interfaces ===
class OrderService
{
    private readonly List<string> _orders = ["O1", "O2", "O3"];

    // ✅ Callers can read but not Add/Remove
    public IReadOnlyList<string> GetOrders() => _orders;

    // ❌ Exposes internal list — caller could cast and mutate
    // public List<string> GetOrders() => _orders;
}

var svc = new OrderService();
IReadOnlyList<string> orders = svc.GetOrders();
Console.WriteLine(orders.Count);    // 3
Console.WriteLine(orders[0]);       // O1
// orders.Add("O4");               // ❌ compile error — IReadOnlyList has no Add

// === Multiple enumeration gotcha with IEnumerable<T> ===
IEnumerable<int> lazy = Enumerable.Range(1, 5).Select(x => { Console.Write($"gen{x} "); return x; });
int sum1 = lazy.Sum();   // generates: gen1 gen2 gen3 gen4 gen5
int sum2 = lazy.Sum();   // generates AGAIN: gen1 gen2 gen3 gen4 gen5 (double work)
// Fix: materialize once
IReadOnlyList<int> eager = lazy.ToList(); // generate once
int sum3 = eager.Sum();  // no re-generation
int sum4 = eager.Sum();  // same

// === Checking interface in received collection ===
static void Process(IEnumerable<string> items)
{
    // Avoid double enumeration by checking if already materialized
    IReadOnlyCollection<string> collection = items as IReadOnlyCollection<string>
        ?? items.ToList();
    Console.WriteLine($"Processing {collection.Count} items");
    foreach (var item in collection) Console.WriteLine(item);
}
```

## Common Follow-up Questions

- What is the difference between `IReadOnlyList<T>` and `T[]` as a return type?
- Why does `IList<T>` not inherit from `IReadOnlyList<T>` directly in .NET?
- When does `IEnumerable<T>` cause performance problems and how do you detect it?
- How do `IAsyncEnumerable<T>` and `IEnumerable<T>` differ in terms of consuming code?
- What is `IStructuralEquatable` and `IStructuralComparable`?
- How does covariance apply to `IEnumerable<T>` vs `IList<T>`?

## Common Mistakes / Pitfalls

- **Enumerating `IEnumerable<T>` multiple times.** Lazy sequences (LINQ pipelines, `yield return` generators) re-execute their logic on every enumeration. Materialize with `.ToList()` or `.ToArray()` before multiple passes.
- **Calling `.Count()` on `IEnumerable<T>` in a loop.** LINQ's `Count()` on a raw `IEnumerable<T>` iterates all elements unless the runtime detects an `ICollection<T>` implementation. Cast or materialize first.
- **Returning `IEnumerable<T>` from a method that already materialized the data.** If you built a `List<T>` internally, return `IReadOnlyList<T>` — callers can access `Count` and indexer efficiently. Returning `IEnumerable<T>` hides the fact that the data is already in memory.
- **Accepting `IList<T>` when you only need to read.** This forces callers to provide a mutable list even if they have a `T[]` or a `ReadOnlyCollection<T>`. Accept `IReadOnlyList<T>` instead.
- **Casting the returned `IReadOnlyList<T>` back to `List<T>` to mutate it.** This defeats the read-only contract. Design patterns like defensive copying (`return new List<T>(_internal).AsReadOnly()`) prevent this, at a copy cost.

## References

- [IEnumerable<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [ICollection<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.icollection-1)
- [IList<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.ilist-1)
- [IReadOnlyList<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.ireadonlylist-1)
- [Collection guidelines — .NET design guidelines](https://learn.microsoft.com/dotnet/standard/design-guidelines/guidelines-for-collections)
