# Stable vs Unstable Sorting Algorithms

**Category:** Algorithms / Sorting
**Difficulty:** Middle
**Tags:** `sorting`, `stability`, `merge-sort`, `quick-sort`

## Question
> What is a stable sorting algorithm? When does stability matter? Give examples of stable and unstable sorts.

## Short Answer
A sort is **stable** if it preserves the original relative order of elements with equal keys. Merge sort and insertion sort are stable; quick sort and heap sort are typically unstable. Stability matters when sorting by multiple criteria or when the original order carries meaning (e.g., sorting by last name after having sorted by first name).

## Detailed Explanation

### What Stability Means

```
Input:  [(Alice, 30), (Bob, 25), (Charlie, 30), (Dave, 25)]
Sort by age:
Stable result:   [(Bob, 25), (Dave, 25), (Alice, 30), (Charlie, 30)]  // Bob before Dave (original order)
Unstable result: [(Dave, 25), (Bob, 25), (Charlie, 30), (Alice, 30)]  // arbitrary
```

### When Stability Matters

1. **Multi-key sorting**: Sort employees by department, then by name. Sort by name (stable) first, then by department — stable ensures within each department, names remain alphabetically sorted.

2. **UI tables**: User sorts a grid by column A. Then sorts by column B. A stable sort preserves the A ordering within equal B values.

3. **Radix sort**: Requires stability of the inner sort (typically counting sort) to work correctly.

### Stable vs Unstable — Common Algorithms

| Algorithm | Stable? | Time (avg) | Space |
|-----------|---------|-----------|-------|
| Bubble Sort | ✅ Yes | O(n²) | O(1) |
| Insertion Sort | ✅ Yes | O(n²) | O(1) |
| Merge Sort | ✅ Yes | O(n log n) | O(n) |
| Tim Sort | ✅ Yes | O(n log n) | O(n) |
| Quick Sort | ❌ No* | O(n log n) | O(log n) |
| Heap Sort | ❌ No | O(n log n) | O(1) |
| Counting Sort | ✅ Yes | O(n + k) | O(k) |

*Quick sort can be made stable but requires extra space.

### .NET Sorting Stability

```csharp
// Array.Sort — UNSTABLE (uses introspective sort / quick sort internally)
Array.Sort(arr);

// LINQ OrderBy — STABLE (uses merge sort)
var sorted = arr.OrderBy(x => x.Age).ToArray();

// List<T>.Sort — UNSTABLE
list.Sort();

// Stable multi-key sort with LINQ
var result = employees
    .OrderBy(e => e.Department)
    .ThenBy(e => e.Name)  // stable secondary sort
    .ToList();
```

> **Important .NET detail:** `Array.Sort` and `List<T>.Sort` are **not stable**. Always use LINQ `OrderBy`/`ThenBy` if stability is required.

## Code Example

```csharp
var employees = new[]
{
    new { Name = "Bob",     Dept = "Engineering" },
    new { Name = "Alice",   Dept = "HR" },
    new { Name = "Charlie", Dept = "Engineering" },
    new { Name = "Dave",    Dept = "HR" },
};

// Stable: Engineering employees retain Bob-before-Charlie order
var stable = employees.OrderBy(e => e.Dept).ToArray();
// Result: [Bob-Eng, Charlie-Eng, Alice-HR, Dave-HR]

// Unstable (Array.Sort with custom comparer may reorder equal Dept)
Array.Sort(employees, (a, b) => string.Compare(a.Dept, b.Dept, StringComparison.Ordinal));
// Order within Dept: not guaranteed
```

## Common Follow-up Questions
- Why is `Array.Sort` in .NET unstable? What sorting algorithm does it use internally?
- How does Tim Sort achieve stability while being efficient?
- Can you make quick sort stable? What's the cost?
- Why does LINQ `OrderBy` use a stable sort?
- When would you deliberately choose an unstable sort over a stable one?

## Common Mistakes / Pitfalls
- Assuming `Array.Sort` is stable — it is not.
- Using `list.Sort()` and expecting stable ordering for UI scenarios.
- Not understanding that `ThenBy` in LINQ is always stable relative to the preceding `OrderBy`.
- Confusing "stable" with "consistent" — an unstable sort is deterministic but may produce different orderings for equal elements across different runs.

## References
- [Array.Sort — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.array.sort)
- [Enumerable.OrderBy (stable) — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable.orderby)
- [Tim Sort — Wikipedia](https://en.wikipedia.org/wiki/Timsort) (verify URL)
