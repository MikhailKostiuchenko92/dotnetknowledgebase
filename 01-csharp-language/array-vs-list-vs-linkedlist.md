# Array vs `List<T>` vs `LinkedList<T>`

**Category:** C# / Collections & LINQ
**Difficulty:** 🟢 Junior
**Tags:** `array`, `List<T>`, `LinkedList<T>`, `collections`, `complexity`, `performance`, `cache-locality`

## Question

> When should you use an array, a `List<T>`, or a `LinkedList<T>`? What are the performance trade-offs?

Additional phrasings:
- *"Why is `List<T>` usually preferred over `LinkedList<T>` even for frequent insertions?"*
- *"What does `List<T>` do internally when its capacity is exceeded?"*

## Short Answer

Use an **array** when the size is fixed and known upfront, or when you need the absolute minimum memory overhead and maximum cache performance. Use **`List<T>`** for a dynamic, random-access collection — it is backed by an array that doubles when full (amortized O(1) append). Use **`LinkedList<T>`** only when you have a measured requirement for O(1) insertions at arbitrary known nodes and you can afford the 3× memory overhead per element; in practice the CPU cache penalty of linked lists makes `List<T>` faster for most real workloads even for mid-list insertions.

## Detailed Explanation

### Array — Fixed Size, Maximum Locality

A C# array (`T[]`) is:
- A **contiguous block** of memory, each element adjacent in memory.
- Fixed size at creation — you cannot add or remove elements.
- The most cache-friendly data structure: sequential access hits L1/L2 cache perfectly.
- Reference type (the array object is on the heap) but elements are stored inline.

```
Complexity: Access O(1) | Search O(n) | Append: not supported | Insert/Delete: not supported
```

When to prefer arrays:
- Size is known at construction time and never changes.
- Interop with native code or `Span<T>`-heavy APIs.
- Multi-dimensional data (`int[,]`, `int[][]`).
- Extreme performance hot paths (avoids `List<T>`'s bounds check + version check overhead — though JIT largely eliminates these).

### `List<T>` — Dynamic Array

`List<T>` wraps a `T[]` internally with a `_size` counter:

```
Initial capacity: 4 (default when using new List<T>())
Growth strategy: double when full (4 → 8 → 16 → 32 → ...)
```

When `Add` exceeds capacity:
1. Allocate a new array of double the current capacity.
2. Copy all existing elements with `Array.Copy`.
3. Replace the internal array reference.

This gives **amortized O(1) `Add`** at the cost of occasional O(n) re-allocations. Setting `Capacity` upfront eliminates re-allocations entirely.

```
Complexity: Access O(1) | Search O(n) | Append O(1) amortized | Insert O(n) | Delete O(n)
```

`List<T>` is the workhorse collection — default choice unless you have a specific reason otherwise.

### `LinkedList<T>` — Doubly Linked Nodes

`LinkedList<T>` stores elements in heap-allocated `LinkedListNode<T>` objects, each holding a value, a `Next` pointer, and a `Previous` pointer:

```
Memory per node: value + 2 managed pointers = ~24 bytes on 64-bit for a node holding an int
vs array element: 4 bytes for int in List<int>
→ ~6× memory overhead per element
```

```
Complexity: Access O(n) | Search O(n) | Append/Prepend O(1) | Insert at known node O(1) | Remove at known node O(1)
```

The O(1) insert/remove requires you to already hold a `LinkedListNode<T>` reference. Finding the node is still O(n).

### Why `LinkedList<T>` Is Often a Pessimization in Practice

The theoretical O(1) insertion advantage is usually negated by:
- **Cache misses:** each node is a separate heap object; traversal chases pointers across memory, causing CPU cache thrashing.
- **Memory overhead:** ~3–6× larger than `List<T>` for the same data.
- **GC pressure:** each node is a separate heap object the GC must track.

Benchmarks typically show `List<T>.Insert` (which is O(n) memcopy) **outperforms `LinkedList<T>.AddAfter`** (O(1) pointer manipulation) for lists under ~10,000 elements because `Array.Copy` is a highly-optimized bulk memory move (SIMD-assisted), while linked list traversal to find the insert position serializes through pointer chains.

### Decision Guide

| Requirement | Best choice |
|---|---|
| Fixed size, known at creation | `T[]` (array) |
| Dynamic size, random access, general use | `List<T>` |
| Frequent additions to front/end only | `List<T>` (tail), `Queue<T>` (front+back) |
| O(1) insert/remove at both ends | `LinkedList<T>` or `Deque<T>` (third-party) |
| Stack semantics (LIFO) | `Stack<T>` |
| Queue semantics (FIFO) | `Queue<T>` |
| Sorted data, frequent search | `SortedList<K,V>`, `SortedSet<T>` |
| Frequent arbitrary mid-list insert with profiled need | `LinkedList<T>` (only if benchmarks confirm) |

### Memory Layout Comparison

```
Array / List<T> internals:
[ elem0 | elem1 | elem2 | elem3 | ...  ]  — contiguous, one allocation

LinkedList<T> internals:
Node{val=0, prev=null, next=→} → Node{val=1, prev=←, next=→} → Node{val=2, ...}
 (separate heap objects, scattered in memory)
```

## Code Example

```csharp
using System.Collections.Generic;

// === Array: fixed size, inline elements ===
int[] squares = new int[5];
for (int i = 0; i < squares.Length; i++) squares[i] = i * i;
// squares.Add(25); ❌ — arrays have no Add method

// Multi-dimensional
int[,] matrix = new int[3, 3];
matrix[1, 1] = 42;

// === List<T>: dynamic, preferred default ===
var list = new List<int>(capacity: 8); // pre-size to avoid re-allocations
list.Add(1);
list.Add(2);
list.Insert(1, 99); // O(n) — shifts elements right
list.Remove(99);    // O(n) — finds and shifts

// CollectionExpression (C# 12):
List<string> names = ["Alice", "Bob", "Charlie"];

// Check internal capacity
var big = new List<int>();
for (int i = 0; i < 100; i++) big.Add(i);
Console.WriteLine(big.Capacity); // 128 (next power of 2 after 100)
Console.WriteLine(big.Count);    // 100
big.TrimExcess();               // shrink backing array to Count
Console.WriteLine(big.Capacity); // 100

// === LinkedList<T>: O(1) insert at known node ===
var ll = new LinkedList<int>(new[] { 1, 2, 4, 5 });
LinkedListNode<int>? node2 = ll.Find(2); // O(n) to find
if (node2 != null)
    ll.AddAfter(node2, 3); // O(1) insert after node — list: 1,2,3,4,5

Console.WriteLine(string.Join(",", ll)); // 1,2,3,4,5

// LinkedList has no indexer — must walk the list
// ll[2]; ❌ — no random access

// === Performance tip: use Span<T>/arrays for hot paths ===
static int SumArray(ReadOnlySpan<int> data)
{
    int sum = 0;
    foreach (int x in data) sum += x; // JIT eliminates bounds check
    return sum;
}

int[] arr = [1, 2, 3, 4, 5];
Console.WriteLine(SumArray(arr)); // 15
```

## Common Follow-up Questions

- How does `List<T>` handle removal from the middle — does it compact immediately or use tombstones?
- What is the difference between `List<T>.RemoveAt(i)` (O(n)) and using a swap-remove pattern (O(1))?
- When would you use `ImmutableArray<T>` vs a regular array?
- How does `ArrayPool<T>` avoid array allocations in hot paths?
- What collection should you use for a sliding window / circular buffer scenario?
- How does `Span<T>` relate to arrays in terms of performance?

## Common Mistakes / Pitfalls

- **Defaulting to `LinkedList<T>` for "faster insertions."** Unless you already hold the node reference and have profiled the workload, `List<T>.Insert` is almost always faster due to cache effects. Always benchmark before choosing `LinkedList<T>`.
- **Not pre-sizing `List<T>` when the count is known.** Without a `Capacity` hint, `List<T>` will re-allocate and copy several times. `new List<T>(expectedCount)` eliminates this overhead.
- **Using an array where you need dynamic growth.** Manually managing array resizing is error-prone. `List<T>` or `ArrayPool<T>` handles this correctly.
- **Accessing `LinkedList<T>` by index via a loop.** Each `list.ElementAt(i)` is O(n) — O(n²) in a loop. If you need index access, use `List<T>`.
- **Returning `List<T>` from a public API when `IReadOnlyList<T>` or `IEnumerable<T>` is sufficient.** Expose the least powerful interface that satisfies callers; `List<T>` allows `Add` and `Clear` that callers shouldn't have.

## References

- [List<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.list-1)
- [LinkedList<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.linkedlist-1)
- [Arrays — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/arrays/)
- [Choosing a collection class — .NET guidelines](https://learn.microsoft.com/dotnet/standard/collections/selecting-a-collection-class)
- [.NET collection performance — performance documentation](https://learn.microsoft.com/dotnet/standard/collections/)
