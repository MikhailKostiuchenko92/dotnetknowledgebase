# House Robber II

**Source:** LeetCode #213
**Difficulty:** 🟡 Medium
**Topics:** Array, Dynamic Programming

## Problem Statement

Same as [House Robber](../house-robber/README.md), but the houses are arranged in a **circle** — the first and last houses are adjacent.

## Examples

```
Input: nums = [2,3,2]   Output: 3   // can't rob both house 1 and 3
Input: nums = [1,2,3,1]   Output: 4  // rob house 1 and house 3
```

## Constraints

- `1 <= nums.Length <= 100`; `0 <= nums[i] <= 1000`

---

## Approach: Two Linear Passes — O(n) time, O(1) space ✓

Since first and last can't both be robbed, solve House Robber I twice:
1. On subarray `[0 .. n-2]` (include first, exclude last).
2. On subarray `[1 .. n-1]` (exclude first, include last).

Return the maximum of the two.

```csharp
public static int Rob(int[] nums)
{
    if (nums.Length == 1) return nums[0];
    if (nums.Length == 2) return Math.Max(nums[0], nums[1]);
    return Math.Max(RobLinear(nums, 0, nums.Length - 2),
                    RobLinear(nums, 1, nums.Length - 1));
}

private static int RobLinear(int[] nums, int start, int end)
{
    int prev2 = nums[start];
    int prev1 = Math.Max(nums[start], nums[start + 1]);
    for (int i = start + 2; i <= end; i++)
    {
        int curr = Math.Max(prev1, prev2 + nums[i]);
        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;
}
```

---

## Complexity Summary

| Approach          | Time | Space |
|-------------------|------|-------|
| Two linear passes | O(n) | O(1)  |

---

## Interview Tips

- The key insight: **break the circle** into two linear subproblems.
- Edge cases: `n == 1` (return nums[0]), `n == 2` (max of both).
- **Related:** [House Robber](../house-robber/README.md), LeetCode #337 (tree variant).
