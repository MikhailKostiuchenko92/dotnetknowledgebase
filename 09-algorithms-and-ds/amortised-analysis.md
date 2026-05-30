# Amortised Analysis

**Category:** Algorithms / Complexity Theory
**Difficulty:** Middle
**Tags:** `amortised`, `dynamic-array`, `union-find`, `path-compression`

## Question
> What is amortised analysis? Give two concrete examples where it applies.

## Short Answer
Amortised analysis gives the **average cost per operation over a sequence of n operations**, even when individual operations can be expensive. Unlike average-case analysis, it doesn't assume probability — it guarantees the average over **any** sequence. Classic examples: dynamic array `Add()` is O(1) amortised despite occasional O(n) resize; Union-Find `Find()` is O(α(n)) ≈ O(1) amortised with path compression.

## Detailed Explanation

### Why Amortised Analysis?

Some data structures have **occasionally expensive operations** that are rare enough that the total cost over n operations is still O(n), giving O(1) per operation on average. This guarantee holds for **every** input sequence, not just random inputs.

### Example 1: Dynamic Array (`List<T>`) — Doubling Strategy

When `List<T>` runs out of capacity, it doubles the backing array and copies all elements. That copy costs O(n). But how often does it happen?

```
Capacity:  1 → 2 → 4 → 8 → 16 → 32 ...
Copy work: 1,  2,  4,  8,  16,  32 ...
```

For n `Add()` calls, total copy work = 1 + 2 + 4 + ... + n = **2n** (geometric series). So amortised cost per `Add()` = 2n / n = **O(1)**.

### Example 2: Union-Find with Path Compression

Without optimisations, `Find()` is O(n) (tall tree). With **path compression** (make all nodes point directly to root) + **union by rank**, the amortised cost per operation is **O(α(n))** where α is the inverse Ackermann function — essentially constant (α(n) ≤ 4 for any practical n).

```csharp
// Path compression: halve path length each call (iterative)
int Find(int x)
{
    while (parent[x] != x)
    {
        parent[x] = parent[parent[x]]; // path splitting
        x = parent[x];
    }
    return x;
}
```

### Three Methods of Amortised Analysis

| Method | Approach |
|--------|----------|
| **Aggregate** | Total cost / n operations |
| **Accounting** | Assign "credits" to cheap ops to pay for future expensive ops |
| **Potential** | Φ(state) function measures "stored work"; amortised cost = actual + ΔΦ |

In interviews, the **aggregate method** is usually sufficient to explain.

## Code Example

```csharp
// Demonstrate amortised O(1) Add with manual doubling
public class DynamicArray<T>
{
    private T[] _data;
    private int _size;

    public DynamicArray() => _data = new T[1];

    public void Add(T item)
    {
        if (_size == _data.Length)
        {
            // O(n) resize — but happens only O(log n) times for n adds
            var newData = new T[_data.Length * 2];
            Array.Copy(_data, newData, _size);
            _data = newData;
        }
        _data[_size++] = item; // O(1)
    }
    // n Add() calls: O(n) total = O(1) amortised each
}
```

## Common Follow-up Questions
- Why does List<T> double capacity instead of growing by a fixed amount?
- What is the amortised complexity of `Stack<T>.Push` in .NET?
- How does `Dictionary<K,V>` rehashing relate to amortised analysis?
- Is amortised O(1) the same as worst-case O(1)?
- What happens if you `AddRange` a large collection to a List in one call vs one at a time?

## Common Mistakes / Pitfalls
- Confusing amortised O(1) with **worst-case** O(1) — they're different.
- Assuming the doubling strategy works for growth by 1 each time — it doesn't (O(n²) total for n adds).
- Forgetting to mention that amortised analysis only applies to **sequences of operations**, not single calls.

## References
- [Introduction to Algorithms — Chapter 17 (Amortised Analysis)](https://mitpress.mit.edu/books/introduction-algorithms)
- [List<T> source — dotnet/runtime](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Collections/src/System/Collections/Generic/List.cs) (verify URL)
