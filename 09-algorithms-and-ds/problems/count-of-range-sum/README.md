# Count of Range Sum

**Source:** LeetCode #327
**Difficulty:** 🔴 Hard
**Topics:** Array, Merge Sort, Binary Indexed Tree, Prefix Sum

## Problem Statement

Given an integer array `nums` and two integers `lower` and `upper`, return the **number of range sums** that lie in `[lower, upper]` inclusive.

A **range sum** `S(i, j)` is defined as the sum of elements in `nums` between indices `i` and `j` inclusive (where `i <= j`).

## Examples

```
Input:  nums = [-2, 5, -1], lower = -2, upper = 2
Output: 3
// Range sums: S(0,0)=-2✓, S(0,1)=3✗, S(0,2)=2✓, S(1,1)=5✗, S(1,2)=4✗, S(2,2)=-1✓

Input:  nums = [0], lower = 0, upper = 0
Output: 1
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-2³¹ <= nums[i] <= 2³¹ - 1`
- `-10⁵ <= lower <= upper <= 10⁵`
- The answer is guaranteed to fit in a 32-bit integer.

---

## Approach 1: Brute Force — O(n²) time, O(n) space

```csharp
public static int CountRangeSum_Brute(int[] nums, int lower, int upper)
{
    int count = 0;
    long runningSum = 0;
    long[] prefix = new long[nums.Length + 1];
    for (int i = 0; i < nums.Length; i++)
        prefix[i + 1] = prefix[i] + nums[i];

    for (int i = 0; i < prefix.Length; i++)
        for (int j = i + 1; j < prefix.Length; j++)
        {
            long s = prefix[j] - prefix[i];
            if (s >= lower && s <= upper) count++;
        }
    return count;
}
```

---

## Approach 2: Merge Sort on Prefix Sums — O(n log n) time, O(n) space ✓

### Key Insight

Build prefix sums array `P` (length `n+1`). Count pairs `(i, j)` with `i < j` where `lower <= P[j] - P[i] <= upper`. This is equivalent to `P[i] + lower <= P[j] <= P[i] + upper`.

During **merge sort**, when merging two sorted halves, for each right element `P[j]`, use two pointers (`lo`, `hi`) into the left half to count how many `P[i]` satisfy the range condition — since both halves are sorted, the pointers only move forward.

```csharp
public static int CountRangeSum(int[] nums, int lower, int upper)
{
    long[] prefix = new long[nums.Length + 1];
    for (int i = 0; i < nums.Length; i++)
        prefix[i + 1] = prefix[i] + nums[i];

    return MergeSort(prefix, 0, prefix.Length, lower, upper);
}

private static int MergeSort(long[] prefix, int left, int right, int lower, int upper)
{
    if (right - left <= 1) return 0;

    int mid = left + (right - left) / 2;
    int count = MergeSort(prefix, left, mid, lower, upper)
              + MergeSort(prefix, mid, right, lower, upper);

    // Count valid pairs across the two halves
    int lo = mid, hi = mid;
    for (int i = left; i < mid; i++)
    {
        // Advance lo so prefix[lo] - prefix[i] >= lower
        while (lo < right && prefix[lo] - prefix[i] < lower) lo++;
        // Advance hi so prefix[hi] - prefix[i] <= upper
        while (hi < right && prefix[hi] - prefix[i] <= upper) hi++;
        count += hi - lo;
    }

    // Merge the two halves in sorted order
    var sorted = new long[right - left];
    int p = left, q = mid, r = 0;
    while (p < mid && q < right)
        sorted[r++] = prefix[p] <= prefix[q] ? prefix[p++] : prefix[q++];
    while (p < mid) sorted[r++] = prefix[p++];
    while (q < right) sorted[r++] = prefix[q++];
    Array.Copy(sorted, 0, prefix, left, sorted.Length);

    return count;
}
```

> **Use `long` for prefix sums** to avoid integer overflow — `nums[i]` can be `±2³¹` and sums can reach `±n * 2³¹`.

---

## Complexity Summary

| Approach    | Time       | Space |
|-------------|------------|-------|
| Brute Force | O(n²)      | O(n)  |
| Merge Sort  | O(n log n) | O(n)  |

---

## Interview Tips

- This is a genuinely hard problem. State upfront: *"I'll build prefix sums and use merge sort to count valid pairs in O(n log n)."*
- **Overflow is a real trap** — use `long[]` for the prefix array.
- Walk through the counting step: *"During merge, both halves are sorted, so the window `[lo, hi)` of valid right-half elements for each left element only moves forward."*
- The merge sort approach is the canonical O(n log n) solution; mention that a Fenwick Tree (BIT) or segment tree can also achieve O(n log n).
- This problem rarely appears in standard interviews; it signals familiarity with advanced divide-and-conquer.
