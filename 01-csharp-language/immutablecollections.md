# Immutable Collections

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `ImmutableArray`, `ImmutableList`, `ImmutableDictionary`, `immutability`, `thread-safety`, `System.Collections.Immutable`

## Question

> What are immutable collections in .NET? When should you use `ImmutableArray<T>` vs `ImmutableList<T>`?

Additional phrasings:
- *"How do immutable collections handle 'mutation' — and what does a 'with' operation actually cost?"*
- *"What is the difference between a read-only collection and an immutable collection?"*

## Short Answer

Immutable collections (in `System.Collections.Immutable`) guarantee that once created, the collection's content never changes. Any "mutation" produces a **new collection** sharing structural data with the original (persistent data structures). `ImmutableArray<T>` is a thin wrapper around a plain array — O(1) reads, O(n) for any modification (full copy). `ImmutableList<T>` uses a balanced binary tree — O(log n) reads, O(log n) for modifications with structural sharing. Use `ImmutableArray<T>` for small, rarely-modified, frequently-read collections; `ImmutableList<T>` when modifications happen alongside reads and structural sharing matters.

## Detailed Explanation

### Read-Only vs Immutable

These are distinct concepts:

| | `IReadOnlyList<T>` | `ReadOnlyCollection<T>` | `ImmutableList<T>` |
|---|---|---|---|
| Callers can mutate? | No (via this interface) | No | No |
| Underlying data can change? | Yes (if cast to mutable) | Yes (original list changes) | **No** — ever |
| Structural sharing | N/A | N/A | ✅ Yes |
| Thread-safe | No | No | ✅ Yes |

A `List<T>` wrapped in `IReadOnlyList<T>` is not immutable — the original `List<T>` can still be modified. An `ImmutableList<T>` is truly unchangeable.

### `ImmutableArray<T>` — Array Wrapper

`ImmutableArray<T>` is a `readonly struct` wrapping a plain `T[]`. Its immutability comes from never exposing the backing array for mutation.

```
Complexity:
  Read by index: O(1)
  Add/Remove/Insert: O(n) — creates a new array with all elements copied
  Enumerate: O(n), excellent cache locality
  Memory: same as T[] + a 4-byte struct wrapper
```

**Best for:**
- Collections that are built once and then only read.
- Small collections where O(n) modification cost is acceptable.
- Interop with `Span<T>` via `AsSpan()`.

**Builder pattern** for efficient construction:
```csharp
var builder = ImmutableArray.CreateBuilder<int>(initialCapacity: 10);
builder.Add(1); builder.Add(2); builder.Add(3);
ImmutableArray<int> arr = builder.ToImmutable(); // O(1) if capacity not exceeded
```

### `ImmutableList<T>` — Balanced Binary Tree

`ImmutableList<T>` uses an **AVL tree** (a self-balancing binary search tree). Structural sharing means modifications reuse unchanged subtrees — only the path from root to the changed node is reallocated.

```
Complexity:
  Read by index: O(log n) — tree traversal
  Add/Remove/Insert: O(log n) — new nodes on changed path only
  Enumerate: O(n) but slower than array due to tree traversal
  Memory: significant overhead (~40 bytes per node vs 4 bytes for int)
```

**Best for:**
- Frequently modified collections where you also need historical versions (event sourcing, undo/redo).
- Scenarios where `O(n)` copy cost of `ImmutableArray` is too expensive.

### The Full Family

| Collection | Mutable counterpart | Modification cost |
|---|---|---|
| `ImmutableArray<T>` | `T[]` | O(n) — full copy |
| `ImmutableList<T>` | `List<T>` | O(log n) — tree path copy |
| `ImmutableDictionary<K,V>` | `Dictionary<K,V>` | O(log n) |
| `ImmutableHashSet<T>` | `HashSet<T>` | O(log n) |
| `ImmutableSortedDictionary<K,V>` | `SortedDictionary<K,V>` | O(log n) |
| `ImmutableSortedSet<T>` | `SortedSet<T>` | O(log n) |
| `ImmutableQueue<T>` | `Queue<T>` | O(1) amortized (functional queue) |
| `ImmutableStack<T>` | `Stack<T>` | O(1) (linked list) |

### Thread Safety

All immutable collections are **inherently thread-safe for reads and for publishing new versions** — because no mutation is possible, no synchronization is needed for readers. The pattern for shared mutable state:

```csharp
private volatile ImmutableList<string> _items = ImmutableList<string>.Empty;

public void AddItem(string item)
{
    ImmutableList<string> current, updated;
    do
    {
        current = _items;
        updated = current.Add(item);
    } while (Interlocked.CompareExchange(ref _items, updated, current) != current);
}
```

Or use `ImmutableInterlocked` helper class which encapsulates this pattern.

### Performance Warning

Immutable collections are **not a free thread-safety upgrade** for mutable collections. If you were using `List<T>` + `lock` and switch to `ImmutableList<T>` + `Interlocked`, you trade:
- The `lock` cost for `CompareExchange` retry cost.
- O(1) add for O(log n) add.
- Excellent cache locality for tree pointer chasing.

Profile before switching. For read-heavy, write-rare scenarios `ImmutableArray<T>` or `FrozenDictionary<K,V>` ([See: frozencollections.md](./frozencollections.md)) are better choices.

## Code Example

```csharp
using System.Collections.Immutable;

// === ImmutableArray<T>: build once, read fast ===
ImmutableArray<int> arr = [1, 2, 3, 4, 5]; // collection expression (C# 12)

// "Mutation" returns a new array — original unchanged
ImmutableArray<int> arr2 = arr.Add(6);
ImmutableArray<int> arr3 = arr.SetItem(0, 99);
Console.WriteLine(arr[0]);  // 1 — unchanged
Console.WriteLine(arr2[5]); // 6
Console.WriteLine(arr3[0]); // 99

// Efficient construction with builder
var builder = ImmutableArray.CreateBuilder<string>();
builder.Add("Alice"); builder.Add("Bob"); builder.Add("Charlie");
ImmutableArray<string> names = builder.ToImmutable();

// Span integration
ReadOnlySpan<int> span = arr.AsSpan(); // zero-copy span view

// === ImmutableList<T>: O(log n) modification with structural sharing ===
var list = ImmutableList.Create(1, 2, 3, 4, 5);
var list2 = list.Add(6);     // new version — O(log n)
var list3 = list.Remove(3);  // new version — O(log n)

Console.WriteLine(list.Count);  // 5 — original unchanged
Console.WriteLine(list2.Count); // 6
Console.WriteLine(list3.Count); // 4

// === ImmutableDictionary<K,V> ===
var dict = ImmutableDictionary<string, int>.Empty
    .Add("Alice", 30)
    .Add("Bob", 25);     // fluent chaining returns new instances

var dict2 = dict.SetItem("Alice", 31); // new version
Console.WriteLine(dict["Alice"]);  // 30
Console.WriteLine(dict2["Alice"]); // 31

// === Thread-safe shared state with ImmutableInterlocked ===
var sharedList = ImmutableList<string>.Empty;
Parallel.For(0, 10, i =>
{
    ImmutableInterlocked.Update(ref sharedList, l => l.Add($"item{i}"));
});
Console.WriteLine(sharedList.Count); // 10 — no locks needed

// === ImmutableArray default is dangerous ===
ImmutableArray<int> defaultArr = default; // not initialized!
Console.WriteLine(defaultArr.IsDefault);  // true
// defaultArr.Length → throws NullReferenceException!
// Always check IsDefault or use IsDefaultOrEmpty
```

## Common Follow-up Questions

- How does `ImmutableList<T>`'s AVL tree implement structural sharing, and what is the memory cost?
- What is `ImmutableInterlocked` and when should you use it over a simple `lock`?
- How does `ImmutableArray<T>` differ from `ReadOnlyMemory<T>` or `ReadOnlySpan<T>`?
- What is the performance difference between `ImmutableArray<T>` and `ImmutableList<T>` for iteration?
- When would you use `ImmutableDictionary` vs `FrozenDictionary` (.NET 8)?
- What does `ImmutableArray<T>.IsDefault` mean and why is it dangerous?

## Common Mistakes / Pitfalls

- **Discarding the return value of modification methods.** `list.Add(item)` without `list = list.Add(item)` does nothing — the original is unchanged. This is a silent no-op bug.
- **Using `ImmutableArray<T>` without initializing it.** The `default` value of `ImmutableArray<T>` has `IsDefault == true` and will throw on most operations. Always initialize: `ImmutableArray<T>.Empty` or via a builder/factory.
- **Using immutable collections for high-frequency write scenarios.** If you add/remove many times per second, the O(n) or O(log n) allocation cost defeats the purpose. Use `ConcurrentDictionary` or lock-protected mutable collections instead.
- **Expecting `ImmutableList<T>` to be as fast as `List<T>` for reads.** `ImmutableList<T>` is O(log n) for indexed reads — significantly slower than `List<T>`'s O(1). For read-heavy scenarios, `ImmutableArray<T>` is almost always better.
- **Treating `IReadOnlyList<T>` as immutable.** A caller can cast to `List<T>` and mutate it. Only `ImmutableList<T>` (and family) provides a true immutability guarantee.

## References

- [System.Collections.Immutable — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.immutable)
- [ImmutableArray<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.immutable.immutablearray-1)
- [ImmutableList<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.immutable.immutablelist-1)
- [Immutable collections — .NET guide](https://learn.microsoft.com/dotnet/standard/collections/thread-safe/immutable-collections)
- [ImmutableInterlocked — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.immutable.immutableinterlocked)
