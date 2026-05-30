# Median of Two Sorted Arrays

**Source:** LeetCode #4
**Difficulty:** 🔴 Hard
**Topics:** Array, Binary Search, Divide and Conquer

## Problem Statement

Given two sorted arrays `nums1` and `nums2` of sizes `m` and `n`, return the **median** of the two sorted arrays.

The overall run time complexity must be **O(log(m + n))**.

## Examples

```
Input:  nums1 = [1, 3], nums2 = [2]
Output: 2.0   // merged: [1, 2, 3] → median = 2

Input:  nums1 = [1, 2], nums2 = [3, 4]
Output: 2.5   // merged: [1, 2, 3, 4] → median = (2+3)/2 = 2.5

Input:  nums1 = [], nums2 = [1]
Output: 1.0
```

## Constraints

- `nums1.Length == m`, `nums2.Length == n`
- `0 <= m, n <= 1000`; `1 <= m + n <= 2000`
- `-10⁶ <= nums1[i], nums2[i] <= 10⁶`

---

## Approach 1: Merge then Find Median — O(m+n) time, O(m+n) space

Simple but doesn't meet the O(log(m+n)) requirement. Useful as a baseline.

```csharp
public static double FindMedianSortedArraysLinear(int[] nums1, int[] nums2)
{
    int m = nums1.Length, n = nums2.Length, total = m + n;
    var merged = new int[total];
    int i = 0, j = 0, k = 0;

    while (i < m && j < n)
        merged[k++] = nums1[i] <= nums2[j] ? nums1[i++] : nums2[j++];
    while (i < m) merged[k++] = nums1[i++];
    while (j < n) merged[k++] = nums2[j++];

    return total % 2 == 1
        ? merged[total / 2]
        : (merged[total / 2 - 1] + (double)merged[total / 2]) / 2;
}
```

---

## Approach 2: Binary Search on Partition — O(log(min(m,n))) time, O(1) space ✓

### Core Idea

Binary search on the **smaller array** to find the correct partition point. A valid partition splits both arrays such that:
- All elements on the left of both partitions ≤ all elements on the right.
- The left side has exactly `(m + n + 1) / 2` elements.

```csharp
public static double FindMedianSortedArrays(int[] nums1, int[] nums2)
{
    // Ensure nums1 is the smaller array (binary search over its indices)
    if (nums1.Length > nums2.Length)
        return FindMedianSortedArrays(nums2, nums1);

    int m = nums1.Length, n = nums2.Length;
    int lo = 0, hi = m;
    int half = (m + n + 1) / 2; // total elements on the left side

    while (lo <= hi)
    {
        int partA = (lo + hi) / 2;     // elements from nums1 on the left
        int partB = half - partA;       // elements from nums2 on the left

        int maxLeftA  = partA == 0 ? int.MinValue : nums1[partA - 1];
        int minRightA = partA == m ? int.MaxValue : nums1[partA];
        int maxLeftB  = partB == 0 ? int.MinValue : nums2[partB - 1];
        int minRightB = partB == n ? int.MaxValue : nums2[partB];

        if (maxLeftA <= minRightB && maxLeftB <= minRightA)
        {
            // Found the correct partition
            if ((m + n) % 2 == 1)
                return Math.Max(maxLeftA, maxLeftB);
            else
                return (Math.Max(maxLeftA, maxLeftB) + Math.Min(minRightA, minRightB)) / 2.0;
        }
        else if (maxLeftA > minRightB)
            hi = partA - 1; // too many from nums1 on the left
        else
            lo = partA + 1; // too few from nums1 on the left
    }

    throw new InvalidOperationException("Input arrays are not sorted.");
}
```

### Why this works

We want a partition where the combined left half has `⌈(m+n)/2⌉` elements and every left element ≤ every right element. The binary search adjusts `partA` until the cross-conditions `maxLeftA ≤ minRightB` and `maxLeftB ≤ minRightA` are both satisfied.

The `+1` in `half = (m + n + 1) / 2` ensures odd-total case returns the correct middle element from the left side.

---

## Complexity Summary

| Approach              | Time          | Space |
|-----------------------|---------------|-------|
| Merge then find       | O(m + n)      | O(m+n)|
| Binary search on partition | O(log(min(m,n))) | O(1) |

---

## Interview Tips

- **State the constraint upfront:** O(log(m+n)) is required — merge approach won't satisfy it.
- Explain the partition idea before coding: *"I binary search for a cut in the smaller array such that the combined left halves satisfy the median condition."*
- **Edge cases:** One empty array, arrays of different sizes, all elements of one array smaller than the other.
- **The sentinel values** (`int.MinValue`, `int.MaxValue`) handle partition at the array boundaries cleanly — explain this explicitly.
- This is genuinely hard — it's OK to take 10–15 minutes. Interviewers often care more about your thought process than getting it right first try.
- **Follow-up:** *"What if the arrays are not sorted?"* → Sort first: O((m+n) log(m+n)) then apply the linear merge.
