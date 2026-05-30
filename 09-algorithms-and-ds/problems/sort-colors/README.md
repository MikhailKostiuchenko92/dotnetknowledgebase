# Sort Colors (Dutch National Flag)

**Source:** LeetCode #75
**Difficulty:** 🟡 Medium
**Topics:** Array, Two-Pointer, Sorting

## Problem Statement

Given an array `nums` with `n` objects colored red (0), white (1), or blue (2), sort them **in-place** so that objects of the same color are adjacent, in the order red, white, and blue.

Must solve using a **constant extra space** one-pass algorithm.

## Examples

```
Input:  nums = [2, 0, 2, 1, 1, 0]
Output: [0, 0, 1, 1, 2, 2]

Input:  nums = [2, 0, 1]
Output: [0, 1, 2]
```

## Constraints

- `n == nums.Length`
- `1 <= n <= 300`
- `nums[i]` is either `0`, `1`, or `2`.

---

## Approach 1: Count Sort — O(n) time, O(1) space, Two passes

Count occurrences of 0, 1, 2, then overwrite the array.

```csharp
public static void SortColorsCount(int[] nums)
{
    int c0 = 0, c1 = 0, c2 = 0;
    foreach (int n in nums) { if (n == 0) c0++; else if (n == 1) c1++; else c2++; }
    int i = 0;
    while (c0-- > 0) nums[i++] = 0;
    while (c1-- > 0) nums[i++] = 1;
    while (c2-- > 0) nums[i++] = 2;
}
```

Correct but requires two passes — doesn't satisfy the one-pass follow-up.

---

## Approach 2: Dutch National Flag (Three-Pointer) — O(n) time, O(1) space, One Pass ✓

Maintain three regions:
- `[0, lo)` — all 0s (red)
- `[lo, mid)` — all 1s (white)
- `(hi, n-1]` — all 2s (blue)
- `[mid, hi]` — unprocessed

```csharp
public static void SortColors(int[] nums)
{
    int lo = 0, mid = 0, hi = nums.Length - 1;

    while (mid <= hi)
    {
        switch (nums[mid])
        {
            case 0:
                (nums[lo], nums[mid]) = (nums[mid], nums[lo]);
                lo++; mid++;
                break;
            case 1:
                mid++; // already in the right region
                break;
            case 2:
                (nums[mid], nums[hi]) = (nums[hi], nums[mid]);
                hi--;
                // Do NOT increment mid — the swapped value needs checking
                break;
        }
    }
}
```

### Walkthrough: `[2,0,2,1,1,0]`

```
Initial: lo=0, mid=0, hi=5
nums[mid]=2: swap mid↔hi → [0,0,2,1,1,2], hi=4
nums[mid]=0: swap lo↔mid → [0,0,2,1,1,2], lo=1, mid=1
nums[mid]=0: swap lo↔mid → [0,0,2,1,1,2], lo=2, mid=2
nums[mid]=2: swap mid↔hi → [0,0,1,1,2,2], hi=3
nums[mid]=1: mid=3
nums[mid]=1: mid=4 > hi=3 → done
Result: [0,0,1,1,2,2] ✓
```

> **Why not increment `mid` when swapping with `hi`?** The value swapped in from `hi` is unknown — it must be inspected before advancing.

---

## Complexity Summary

| Approach            | Time | Space | Passes |
|---------------------|------|-------|--------|
| Count sort          | O(n) | O(1)  | 2      |
| Dutch National Flag | O(n) | O(1)  | 1      |

---

## Interview Tips

- **Name the algorithm:** "Dutch National Flag" — coined by Dijkstra. Interviewers appreciate this.
- Explain the three invariants (regions) before coding.
- **The key subtlety:** Don't advance `mid` when swapping with `hi`.
- **Generalisation:** This technique extends to k-way partitioning for any k distinct values.
- **Edge cases:** All same color, already sorted, single element.
