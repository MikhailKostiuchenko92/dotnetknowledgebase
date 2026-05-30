# Big-O, Big-Ω, and Big-Θ Notation

**Category:** Algorithms / Complexity Theory
**Difficulty:** Junior
**Tags:** `big-o`, `complexity`, `asymptotic-analysis`

## Question
> Explain Big-O, Big-Ω (Omega), and Big-Θ (Theta) notation. What is the difference? Give examples for each.

## Short Answer
Big-O is an **upper bound** on growth rate (worst case). Big-Ω is a **lower bound** (best case). Big-Θ is a **tight bound** — the function is both O and Ω. In interviews, "Big-O" informally often means Big-Θ (tight asymptotic bound).

## Detailed Explanation

### Formal Definitions

| Notation | Meaning | Formal |
|----------|---------|--------|
| O(g) | Grows **no faster** than g | `f(n) ≤ c·g(n)` for large n |
| Ω(g) | Grows **at least as fast** as g | `f(n) ≥ c·g(n)` for large n |
| Θ(g) | Grows **exactly** as fast as g | Both O(g) and Ω(g) |

### Practical Examples

```
Linear search on unsorted array:
  O(n)   — worst case: element at end or absent
  Ω(1)   — best case: element at position 0
  Θ(n)   — on average/worst (no tight bound at all cases)

Binary search on sorted array:
  O(log n) — worst case
  Ω(1)     — best case (middle element)
  Θ(log n) — average case tight bound

Bubble sort:
  O(n²)  — worst (reverse sorted)
  Ω(n)   — best (already sorted, with early-exit optimisation)
  Θ(n²)  — without early-exit
```

### Why Does It Matter?

In interviews, when you say "O(n log n)", you typically mean the tight bound. Technically, **any O(n log n) algorithm is also O(n²)** — the latter is just a looser bound. Good engineers give the tightest bound they can.

### Common Complexity Classes (slowest to fastest growth)

```
O(1) < O(log n) < O(√n) < O(n) < O(n log n) < O(n²) < O(n³) < O(2ⁿ) < O(n!)
```

### Space Complexity

The same notation applies to memory. Example: merge sort is O(n log n) time but O(n) space (auxiliary array).

> **Tip:** When an interviewer asks "what's the time complexity?", always give both time **and** space complexity without being asked — it demonstrates thoroughness.

## Code Example

```csharp
// O(1) — constant: array index access
int GetFirst(int[] arr) => arr[0];

// O(log n) — binary search
int BinarySearch(int[] arr, int target)
{
    int lo = 0, hi = arr.Length - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (arr[mid] == target) return mid;
        else if (arr[mid] < target) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}

// O(n) — linear scan
int LinearSearch(int[] arr, int target)
{
    for (int i = 0; i < arr.Length; i++)
        if (arr[i] == target) return i;
    return -1;
}

// O(n²) — nested loops (bubble sort inner)
void BubbleSort(int[] arr)
{
    for (int i = 0; i < arr.Length; i++)
        for (int j = 0; j < arr.Length - 1 - i; j++)
            if (arr[j] > arr[j+1]) (arr[j], arr[j+1]) = (arr[j+1], arr[j]);
}
```

## Common Follow-up Questions
- What is amortised time complexity? Give an example.
- Is O(n log n) better than O(n²)? Always?
- What does "polynomial time" mean in complexity theory?
- Why do we drop constants in Big-O? Is `O(2n)` different from `O(n)`?
- What is the complexity of `string.Contains` in C#? Why?

## Common Mistakes / Pitfalls
- Confusing O (upper bound) with Θ (tight bound) — saying "the complexity is O(1)" when the function can be O(n) in worst case.
- Forgetting space complexity entirely.
- Reporting best-case as the algorithm's complexity without noting it.
- Not accounting for hidden constants — O(n) with `c=10⁶` can be slower than O(n²) for small n.

## References
- [Big O Notation — Microsoft Learn / .NET Guide](https://learn.microsoft.com/en-us/dotnet/standard/collections/selecting-a-collection-class)
- [Introduction to Algorithms, Cormen et al. — Chapter 3](https://mitpress.mit.edu/books/introduction-algorithms-third-edition)
- [Big-O Cheat Sheet](https://www.bigocheatsheet.com/) (verify URL)
