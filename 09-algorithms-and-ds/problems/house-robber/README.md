# House Robber

**Source:** LeetCode #198
**Difficulty:** 🟡 Medium
**Topics:** Array, Dynamic Programming

## Problem Statement

You are a robber planning to rob houses along a street. Each house has a certain amount of money. Adjacent houses have alarms — you cannot rob two adjacent houses. Given an integer array `nums` representing the amount of money in each house, return the maximum amount you can rob tonight without alerting the police.

## Examples

```
Input: nums = [1,2,3,1]   Output: 4   // rob house 1 (1) and house 3 (3)
Input: nums = [2,7,9,3,1]   Output: 12  // rob house 1 (2), 3 (9), 5 (1)
```

## Constraints

- `1 <= nums.Length <= 100`; `0 <= nums[i] <= 400`

---

## Approach: Bottom-Up DP — O(n) time, O(1) space ✓

`dp[i] = max(dp[i-1], dp[i-2] + nums[i])` — either skip house `i` or rob it (adding to the best without the previous house).

```csharp
public static int Rob(int[] nums)
{
    if (nums.Length == 1) return nums[0];
    int prev2 = nums[0];
    int prev1 = Math.Max(nums[0], nums[1]);

    for (int i = 2; i < nums.Length; i++)
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

| Approach     | Time | Space |
|--------------|------|-------|
| Bottom-up DP | O(n) | O(1)  |

---

## Interview Tips

- Classic DP; recognise the "cannot pick adjacent elements" pattern.
- `prev2` = best result two positions back; `prev1` = best result one position back.
- **Follow-up:** Houses in a circle → [House Robber II](../house-robber-ii/README.md).
- **Follow-up:** Houses form a binary tree → LeetCode #337 "House Robber III".
