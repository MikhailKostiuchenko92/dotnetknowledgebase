# First and Last Position of Element in Sorted Array

**Source:** LeetCode #34
**Difficulty:** 🟢 Easy
**Topics:** Array, Binary Search

## Problem Statement

Given an array of integers `nums` sorted in non-decreasing order, find the **starting and ending position** of a given `target` value. If `target` is not found, return `[-1, -1]`.

Must run in **O(log n)** time.

## Examples

```
Input:  nums = [5, 7, 7, 8, 8, 10], target = 8
Output: [3, 4]

Input:  nums = [5, 7, 7, 8, 8, 10], target = 6
Output: [-1, -1]

Input:  nums = [], target = 0
Output: [-1, -1]
```

## Constraints

- `0 <= nums.Length <= 10⁵`
- `-10⁹ <= nums[i] <= 10⁹`
- `nums` is sorted in non-decreasing order.

---

## Approach: Two Binary Searches — O(log n) time, O(1) space ✓

Run binary search twice: once to find the **leftmost** (first) occurrence, once for the **rightmost** (last) occurrence.

```csharp
public static int[] SearchRange(int[] nums, int target)
{
    return [FindFirst(nums, target), FindLast(nums, target)];
}

// Find index of leftmost occurrence of target, or -1
private static int FindFirst(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1, result = -1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] == target)
        {
            result = mid;   // record, but keep searching left
            hi = mid - 1;
        }
        else if (nums[mid] < target) lo = mid + 1;
        else                          hi = mid - 1;
    }
    return result;
}

// Find index of rightmost occurrence of target, or -1
private static int FindLast(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1, result = -1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] == target)
        {
            result = mid;   // record, but keep searching right
            lo = mid + 1;
        }
        else if (nums[mid] < target) lo = mid + 1;
        else                          hi = mid - 1;
    }
    return result;
}
```

### Alternative: Lower/Upper Bound Template

Using the boundary template from [Binary Search](../binary-search/README.md):

```csharp
public static int[] SearchRangeBounds(int[] nums, int target)
{
    int first = LowerBound(nums, target);
    if (first == nums.Length || nums[first] != target)
        return [-1, -1];
    int last = LowerBound(nums, target + 1) - 1;
    return [first, last];
}

private static int LowerBound(int[] nums, int target)
{
    int lo = 0, hi = nums.Length;
    while (lo < hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] < target) lo = mid + 1;
        else                     hi = mid;
    }
    return lo;
}
```

The `LowerBound(target + 1) - 1` trick finds the last position of `target` cleanly.

---

## Complexity Summary

| Approach         | Time    | Space |
|------------------|---------|-------|
| Two binary searches | O(log n) | O(1) |

---

## Interview Tips

- **Explain the "record and continue" pattern:** When you find `target` at `mid`, record it but continue searching in the half that could contain an earlier/later occurrence.
- Alternatively, use the lower/upper bound templates — cleaner and reusable.
- **Edge cases:** Empty array, target not present, all elements equal to target, single element.
- **Common mistake:** Returning `-1` only when the loop exits without checking the recorded `result` variable — no issue in the implementation above, but easy to get confused.
- See also: [Binary Search](../binary-search/README.md) for boundary templates.
