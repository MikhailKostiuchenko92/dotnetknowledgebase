# Binary Search

**Source:** LeetCode #704
**Difficulty:** 🟢 Easy
**Topics:** Array, Binary Search

## Problem Statement

Given an array of integers `nums` sorted in **ascending order**, and an integer `target`, write a function to search for `target` in `nums`. Return the index if found, or `-1` otherwise.

## Examples

```
Input:  nums = [-1, 0, 3, 5, 9, 12], target = 9
Output: 4

Input:  nums = [-1, 0, 3, 5, 9, 12], target = 2
Output: -1
```

## Constraints

- `1 <= nums.Length <= 10⁴`
- `-10⁴ <= nums[i], target <= 10⁴`
- All integers in `nums` are **unique**.
- `nums` is sorted in ascending order.

---

## Approach 1: Iterative Binary Search — O(log n) time, O(1) space ✓ Preferred

```csharp
public static int Search(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;

    while (lo <= hi)
    {
        // Avoid overflow: mid = lo + (hi - lo) / 2  NOT  (lo + hi) / 2
        int mid = lo + (hi - lo) / 2;

        if (nums[mid] == target) return mid;
        if (nums[mid] < target)  lo = mid + 1;
        else                      hi = mid - 1;
    }

    return -1;
}
```

> **Overflow pitfall:** `(lo + hi) / 2` can overflow if both are large positive integers. Always use `lo + (hi - lo) / 2`.

---

## Approach 2: Recursive Binary Search — O(log n) time, O(log n) space

```csharp
public static int SearchRecursive(int[] nums, int target, int lo = 0, int hi = -1)
{
    if (hi == -1) hi = nums.Length - 1;
    if (lo > hi) return -1;

    int mid = lo + (hi - lo) / 2;
    if (nums[mid] == target) return mid;
    if (nums[mid] < target)  return SearchRecursive(nums, target, mid + 1, hi);
    return SearchRecursive(nums, target, lo, mid - 1);
}
```

Uses O(log n) call stack space — iterative preferred in production.

---

## Template: Left / Right Boundary Search

Essential variants that appear in many problems:

```csharp
// Find leftmost (first) position where nums[i] >= target
public static int LowerBound(int[] nums, int target)
{
    int lo = 0, hi = nums.Length; // hi = length (exclusive upper bound)
    while (lo < hi)               // NOT lo <= hi
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] < target) lo = mid + 1;
        else                     hi = mid;     // keep mid in range
    }
    return lo; // lo == hi, index of first element >= target
}

// Find rightmost (last) position where nums[i] <= target
public static int UpperBound(int[] nums, int target)
{
    int lo = 0, hi = nums.Length;
    while (lo < hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] <= target) lo = mid + 1;
        else                      hi = mid;
    }
    return lo - 1; // index of last element <= target
}
```

---

## Complexity Summary

| Approach   | Time    | Space   |
|------------|---------|---------|
| Iterative  | O(log n)| O(1)    |
| Recursive  | O(log n)| O(log n)|

---

## Interview Tips

- **Always use `lo + (hi - lo) / 2`** — explain the overflow risk. Interviewers expect this.
- Distinguish `lo <= hi` (exact search) vs. `lo < hi` (boundary search) — these are different and easy to mix up.
- **Boundary templates** are foundational — dozens of LeetCode problems reduce to "find first/last position satisfying condition X". Know them cold.
- **Edge cases:** Target not in array, single-element array, target smaller than all or larger than all elements.
- **Follow-up:** *"What if the array has duplicates?"* → Return first or last occurrence → [First and Last Position in Sorted Array](../first-and-last-position-in-sorted-array/README.md).
