# Search in Rotated Sorted Array

**Source:** LeetCode #33
**Difficulty:** 🟡 Medium
**Topics:** Array, Binary Search

## Problem Statement

There is an integer array `nums` sorted in ascending order (with **distinct** values), then rotated at an unknown pivot index `k`. Given `nums` and a `target`, return the index of `target`, or `-1` if not found.

Must run in **O(log n)** time.

## Examples

```
Input:  nums = [4, 5, 6, 7, 0, 1, 2], target = 0
Output: 4

Input:  nums = [4, 5, 6, 7, 0, 1, 2], target = 3
Output: -1

Input:  nums = [1], target = 0
Output: -1
```

## Constraints

- `1 <= nums.Length <= 5000`
- `-10⁴ <= nums[i], target <= 10⁴`
- All values are **unique**.

---

## Approach: Modified Binary Search — O(log n) time, O(1) space

At each step, at least one half of the current range is **sorted**. Determine which half is sorted, then decide if `target` falls in that half.

```csharp
public static int Search(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;

    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] == target) return mid;

        // Determine which half is sorted
        if (nums[lo] <= nums[mid])
        {
            // Left half [lo..mid] is sorted
            if (target >= nums[lo] && target < nums[mid])
                hi = mid - 1;   // target is in the sorted left half
            else
                lo = mid + 1;   // target must be in the right half
        }
        else
        {
            // Right half [mid..hi] is sorted
            if (target > nums[mid] && target <= nums[hi])
                lo = mid + 1;   // target is in the sorted right half
            else
                hi = mid - 1;   // target must be in the left half
        }
    }

    return -1;
}
```

### Walkthrough: `[4,5,6,7,0,1,2]`, target = 0

```
lo=0, hi=6: mid=3, nums[3]=7 ≠ 0
  nums[0]=4 <= nums[3]=7 → left half [4,5,6,7] is sorted
  target=0 not in [4,7) → lo = mid+1 = 4

lo=4, hi=6: mid=5, nums[5]=1 ≠ 0
  nums[4]=0 > nums[5]=1 → right half [1,2] is sorted
  target=0 not in (1,2] → hi = mid-1 = 4

lo=4, hi=4: mid=4, nums[4]=0 == 0 → return 4 ✓
```

---

## Complexity Summary

| Approach              | Time    | Space |
|-----------------------|---------|-------|
| Modified binary search| O(log n)| O(1)  |

---

## Interview Tips

- **Key invariant:** At least one of the two halves `[lo..mid]` or `[mid..hi]` is always sorted after a rotation. Use this to determine where the target can lie.
- The condition `nums[lo] <= nums[mid]` (not strict `<`) handles the case where `lo == mid`.
- **Edge cases:** No rotation (regular sorted array — still works), single element, target at the pivot position.
- **Common mistake:** Using `nums[lo] < nums[mid]` strictly — fails when `lo == mid`.
- **Follow-up:** *"What if there are duplicates?"* → LeetCode #81. When `nums[lo] == nums[mid]`, you can't determine which half is sorted → increment `lo` and decrement `hi` (worst case O(n)).
- **Follow-up:** *"Find the pivot/minimum element."* → [Find Minimum in Rotated Sorted Array](../find-minimum-in-rotated-sorted-array/README.md).
