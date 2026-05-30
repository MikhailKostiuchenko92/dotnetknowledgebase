# In-Place vs Out-of-Place Algorithms

**Category:** Algorithms / Memory
**Difficulty:** Middle
**Tags:** `in-place`, `memory`, `space-complexity`, `Span<T>`

## Question
> What is the difference between in-place and out-of-place algorithms? What are the trade-offs?

## Short Answer
An **in-place** algorithm transforms input using only O(1) (or O(log n) for recursion stack) extra memory, modifying the input data structure directly. An **out-of-place** algorithm allocates additional memory proportional to input size. In-place saves memory; out-of-place is often simpler, can preserve the original, and may be faster (cache-friendly allocations).

## Detailed Explanation

### Strict vs Loose Definition

| Definition | Extra Space |
|------------|-------------|
| Strict in-place | O(1) auxiliary space |
| Loose in-place | O(log n) (allows recursion stack) |

Most interview discussions use the **loose** definition.

### Common Algorithms by Category

| Algorithm | In-Place? | Space |
|-----------|-----------|-------|
| Quick Sort | ✅ Yes (loose) | O(log n) stack |
| Merge Sort | ❌ No | O(n) auxiliary array |
| Heap Sort | ✅ Yes | O(1) |
| Insertion Sort | ✅ Yes | O(1) |
| Binary Search | ✅ Yes | O(1) iterative / O(log n) recursive |
| Kadane's Algorithm | ✅ Yes | O(1) |
| String reversal (mutate) | ✅ Yes | O(1) |
| LINQ `.Select()` projection | ❌ No | O(n) |

### Trade-Off Comparison

| Factor | In-Place | Out-of-Place |
|--------|----------|-------------|
| Memory | Less | More |
| Simplicity | Often harder | Often simpler |
| Input preservation | Destroys input | Preserves input |
| Parallelism | Harder (shared state) | Easier |
| Cache efficiency | May vary | Can be better (fresh allocation) |

### When to Prefer In-Place

- Memory-constrained environments
- Large datasets where allocating a copy is prohibitive
- Embedded systems / performance-critical paths

### When to Prefer Out-of-Place

- Original data must be preserved
- Multi-threaded scenarios (avoid shared mutable state)
- Clearer, safer code is prioritised

### `Span<T>` — In-Place in Modern C#

`Span<T>` enables safe, in-place manipulation of slices of arrays and stack-allocated buffers without allocations.

```csharp
// In-place string reversal with Span<T>
void ReverseString(char[] s)
{
    var span = s.AsSpan();
    for (int l = 0, r = span.Length - 1; l < r; l++, r--)
        (span[l], span[r]) = (span[r], span[l]);
}

// In-place array rotation
void RotateRight(int[] nums, int k)
{
    k %= nums.Length;
    Array.Reverse(nums, 0, nums.Length);
    Array.Reverse(nums, 0, k);
    Array.Reverse(nums, k, nums.Length - k);
}
```

## Code Example

```csharp
// In-place: remove duplicates from sorted array
int RemoveDuplicatesInPlace(int[] nums)
{
    if (nums.Length == 0) return 0;
    int write = 1;
    for (int read = 1; read < nums.Length; read++)
        if (nums[read] != nums[read - 1])
            nums[write++] = nums[read];
    return write; // first 'write' elements are deduplicated
}

// Out-of-place: same operation, preserves original
int[] RemoveDuplicatesOutOfPlace(int[] nums)
    => nums.Distinct().ToArray();
```

## Common Follow-up Questions
- Is quick sort truly in-place given its O(log n) stack usage?
- How does `Span<T>` differ from a regular array slice?
- When does in-place sorting cause correctness issues (e.g., stable sort requirement)?
- What is the space complexity of merge sort, and can it be made truly in-place?
- How does immutability (C# records, `string`) affect in-place design?

## Common Mistakes / Pitfalls
- Forgetting that recursive algorithms have O(depth) stack space — quick sort is O(log n), not O(1).
- Modifying input arrays in library methods when callers don't expect mutation.
- Confusing "in-place" with "no extra memory at all" — O(log n) stack is still considered in-place.
- Using `string` (immutable) and expecting in-place changes — convert to `char[]` first.

## References
- [Span<T> and Memory<T> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [Array.Reverse — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.array.reverse)
