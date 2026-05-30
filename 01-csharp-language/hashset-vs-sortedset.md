# `HashSet<T>` vs `SortedSet<T>`

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `HashSet`, `SortedSet`, `set`, `deduplication`, `ordering`, `ISet`, `complexity`

## Question

> What is the difference between `HashSet<T>` and `SortedSet<T>`? When would you use each?

Additional phrasings:
- *"What operations does `HashSet<T>` provide that `List<T>` does not, and at what cost?"*
- *"Why is `SortedSet<T>` O(log n) for lookup instead of O(1)?"*

## Short Answer

`HashSet<T>` is a hash-table-based set that guarantees no duplicates and provides O(1) average Contains/Add/Remove — but has no ordering. `SortedSet<T>` is a red-black tree that also guarantees uniqueness but keeps elements in sorted order, at the cost of O(log n) for all operations. Use `HashSet<T>` when you need fast membership testing or deduplication and don't care about order. Use `SortedSet<T>` when you need sorted enumeration, range queries (`GetViewBetween`), or min/max in O(log n).

## Detailed Explanation

### `HashSet<T>` — Hash-Table Set

Internally, `HashSet<T>` mirrors `Dictionary<TKey, TValue>` but stores only keys (no values). It uses the same bucket + chaining layout.

```
Complexity:
  Add:      O(1) amortized
  Remove:   O(1) amortized
  Contains: O(1) average
  Enumerate: O(n)
  Min/Max:  O(n) — must scan all
```

Key properties:
- No duplicates — `Add` returns `false` (and does nothing) if the element exists.
- **No ordering** — enumeration order is not defined and changes after resize.
- Requires a good `GetHashCode` / `Equals` for the element type ([See: gethashcode-contract.md](./gethashcode-contract.md)).

**Set operations** are the killer feature: `UnionWith`, `IntersectWith`, `ExceptWith`, `IsSubsetOf`, `IsSupersetOf`, `Overlaps`, `SetEquals` — all O(n) but implemented with hash lookups rather than nested loops.

### `SortedSet<T>` — Red-Black Tree Set

`SortedSet<T>` is backed by a self-balancing binary search tree (red-black tree). Elements are always kept in sorted order according to `IComparer<T>`.

```
Complexity:
  Add:      O(log n)
  Remove:   O(log n)
  Contains: O(log n)
  Enumerate: O(n) in-order
  Min:      O(log n) — leftmost node
  Max:      O(log n) — rightmost node
  GetViewBetween: O(log n) to find range, O(k) to enumerate k results
```

Unique capabilities vs `HashSet<T>`:
- **`Min` and `Max` properties** — O(log n).
- **`GetViewBetween(lower, upper)`** — returns a live view of elements in a range; extremely useful for range queries.
- **Sorted enumeration** — iterating yields elements in `IComparer<T>` order.
- Accepts a custom `IComparer<T>` for domain-specific ordering.

### Memory Overhead

| Collection | Per-element overhead |
|---|---|
| `HashSet<T>` | ~16–24 bytes (entry struct + bucket int) |
| `SortedSet<T>` | ~48 bytes (tree node: value + left/right/parent pointers + color bit) |

`SortedSet<T>` uses considerably more memory per element due to tree-node pointers.

### `ISet<T>` — Shared Interface

Both implement `ISet<T>` (and `IReadOnlySet<T>` in .NET 5+), so set-operation code can be written against the interface and work with either concrete type.

### When to Use Which

| Need | Choice |
|---|---|
| Fast membership test / deduplication | `HashSet<T>` |
| Sorted iteration | `SortedSet<T>` |
| Range query (get all items between X and Y) | `SortedSet<T>.GetViewBetween` |
| Min/max retrieval without scanning | `SortedSet<T>` |
| Set algebra (union, intersection, difference) | `HashSet<T>` (faster O(1) lookup) |
| Thread-safe set | Neither — wrap with `ConcurrentDictionary<T,byte>` or use locks |
| Immutable set | `ImmutableHashSet<T>` / `ImmutableSortedSet<T>` |

## Code Example

```csharp
using System.Collections.Generic;

// === HashSet<T>: fast deduplication ===
var words = new[] { "apple", "banana", "apple", "cherry", "banana" };
var unique = new HashSet<string>(words, StringComparer.OrdinalIgnoreCase);
Console.WriteLine(unique.Count); // 3

Console.WriteLine(unique.Contains("APPLE")); // true — OrdinalIgnoreCase
unique.Add("apple");                          // false — already present, no-op

// === Set operations ===
var setA = new HashSet<int> { 1, 2, 3, 4, 5 };
var setB = new HashSet<int> { 3, 4, 5, 6, 7 };

var union     = new HashSet<int>(setA); union.UnionWith(setB);
var intersect = new HashSet<int>(setA); intersect.IntersectWith(setB);
var diff      = new HashSet<int>(setA); diff.ExceptWith(setB);

Console.WriteLine(string.Join(",", union));     // 1,2,3,4,5,6,7
Console.WriteLine(string.Join(",", intersect)); // 3,4,5
Console.WriteLine(string.Join(",", diff));      // 1,2

// === SortedSet<T>: ordered, range queries ===
var scores = new SortedSet<int> { 42, 17, 99, 8, 55, 73 };

// Enumerate in sorted order — no extra Sort() call needed
foreach (int s in scores)
    Console.Write($"{s} "); // 8 17 42 55 73 99

Console.WriteLine();
Console.WriteLine($"Min: {scores.Min}, Max: {scores.Max}"); // 8, 99

// GetViewBetween: live range view (O(log n) to establish, O(k) to enumerate)
SortedSet<int> midRange = scores.GetViewBetween(20, 70);
foreach (int s in midRange)
    Console.Write($"{s} "); // 42 55

// Adding to the view reflects in the original set
scores.Add(60);
Console.WriteLine();
Console.WriteLine(midRange.Contains(60)); // true — live view

// === Custom comparer with SortedSet ===
var byLength = new SortedSet<string>(Comparer<string>.Create(
    (a, b) =>
    {
        int cmp = a.Length.CompareTo(b.Length);
        return cmp != 0 ? cmp : string.Compare(a, b, StringComparison.Ordinal);
    }));
byLength.Add("banana"); byLength.Add("fig"); byLength.Add("apple"); byLength.Add("kiwi");
Console.WriteLine(string.Join(", ", byLength)); // fig, kiwi, apple, banana
```

## Common Follow-up Questions

- How does `HashSet<T>` handle duplicate keys that are equal by `Equals` but have different hash codes (contract violation)?
- What is `ImmutableHashSet<T>` and when would you prefer it over `HashSet<T>`?
- How does `SortedSet<T>.GetViewBetween` avoid copying elements?
- Is `HashSet<T>` thread-safe for concurrent reads without locks?
- What is the difference between `HashSet<T>` and `ConcurrentDictionary<T, byte>` as a thread-safe set?
- How does `FrozenSet<T>` in .NET 8 compare to `HashSet<T>` for read-only scenarios?

## Common Mistakes / Pitfalls

- **Iterating `HashSet<T>` and expecting insertion order.** No ordering is guaranteed. If insertion order matters, use `List<T>` + a `HashSet<T>` as a side-car for O(1) existence checks.
- **Using `List<T>.Contains` for membership testing.** `List<T>.Contains` is O(n); if membership tests are frequent, a `HashSet<T>` is the right tool.
- **Modifying a `SortedSet<T>` while enumerating it.** Like all .NET collection enumerators, this throws `InvalidOperationException` via a version counter.
- **Not providing an `IComparer<T>` when `T` doesn't implement `IComparable<T>`.** `SortedSet<T>` requires comparison — if `T` has no natural order, you must provide a comparer or get a runtime exception.
- **Using `SortedSet<T>` when you only need fast lookups.** The O(log n) overhead is noticeable at scale. `HashSet<T>` is faster for pure membership tests; only use `SortedSet<T>` when you need the ordering features.

## References

- [HashSet<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.hashset-1)
- [SortedSet<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.sortedset-1)
- [ISet<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.iset-1)
- [Choosing a collection class — .NET guidelines](https://learn.microsoft.com/dotnet/standard/collections/selecting-a-collection-class)
