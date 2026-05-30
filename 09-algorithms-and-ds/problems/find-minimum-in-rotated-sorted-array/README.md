# Find Minimum in Rotated Sorted Array

**Source:** LeetCode #153
**Difficulty:** 🟡 Medium
**Topics:** Array, Binary Search

## Problem Statement

Suppose an array of length `n` sorted in ascending order is rotated between `1` and `n` times. Given the sorted rotated array `nums` of **unique** elements, return the **minimum element** of this array.

Must run in **O(log n)** time.

## Examples

```
Input:  nums = [3, 4, 5, 1, 2]
Output: 1

Input:  nums = [4, 5, 6, 7, 0, 1, 2]
Output: 0

Input:  nums = [11, 13, 15, 17]
Output: 11   // not rotated (or rotated 0 times)
```

## Constraints

- `n == nums.Length`
- `1 <= n <= 5000`
- `-5000 <= nums[i] <= 5000`
- All integers are **unique**.
- `nums` is sorted and rotated between 1 and n times.

---

## Approach: Binary Search — O(log n) time, O(1) space

The minimum is the **pivot** — the only element smaller than its left neighbour. Compare `nums[mid]` with `nums[hi]` to determine which side the pivot is on.

```csharp
public static int FindMin(int[] nums)
{
    int lo = 0, hi = nums.Length - 1;

    while (lo < hi)
    {
        int mid = lo + (hi - lo) / 2;

        if (nums[mid] > nums[hi])
            lo = mid + 1;  // minimum is in the right half (past the pivot)
        else
            hi = mid;      // minimum is in the left half (or at mid)
    }

    return nums[lo]; // lo == hi at the minimum
}
```

### Why compare with `nums[hi]` (not `nums[lo]`)?

Comparing with `nums[lo]` would fail when the array is not rotated — `nums[mid] > nums[lo]` would send us right and we'd miss the minimum on the left. Comparing with `nums[hi]` always correctly identifies whether the minimum is to the right or left of (or at) `mid`.

### Why `lo < hi` (not `lo <= hi`)?

We never need to visit a single-element range — `nums[lo]` is already the answer when `lo == hi`.

---

## Complexity Summary

| Approach      | Time    | Space |
|---------------|---------|-------|
| Binary search | O(log n)| O(1)  |

---

## Interview Tips

- **State the invariant:** *"If `nums[mid] > nums[hi]`, the right half contains the pivot (minimum). Otherwise, the left half contains the minimum (or `mid` itself)."*
- The no-rotation case (e.g., `[11,13,15,17]`) naturally terminates with `lo` pointing to `nums[0]`.
- **Edge cases:** Single element (immediate return), array not rotated, rotated exactly once (pivot at index `n-1`).
- **Follow-up:** *"What if there are duplicates?"* → LeetCode #154. When `nums[mid] == nums[hi]`, you can't determine which side — do `hi--` (worst case O(n)).
- Related: [Search in Rotated Sorted Array](../search-in-rotated-sorted-array/README.md) — once you find the minimum (pivot), you can split into two sorted halves.
