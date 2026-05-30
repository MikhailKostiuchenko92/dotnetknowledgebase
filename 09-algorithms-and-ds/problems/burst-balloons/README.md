# Burst Balloons

**Source:** LeetCode #312
**Difficulty:** 🔴 Hard
**Topics:** Array, Dynamic Programming, Interval DP

## Problem Statement

You are given `n` balloons indexed `0` to `n-1`, each with a number. If you burst balloon `i`, you gain `nums[i-1] * nums[i] * nums[i+1]` coins (use 1 for out-of-bounds). Burst all balloons to maximise coins.

## Examples

```
Input: nums = [3,1,5,8]   Output: 167
// [3,1,5,8] → [3,5,8] (burst 1, +3*1*5=15)
//           → [3,8]   (burst 5, +3*5*8=120)
//           → [8]     (burst 3, +1*3*8=24)
//           → []      (burst 8, +1*8*1=8)
// 15 + 120 + 24 + 8 = 167
```

## Constraints

- `1 <= nums.Length <= 300`; `0 <= nums[i] <= 100`

---

## Approach: Interval DP (Think in Reverse) — O(n³) time, O(n²) space ✓

**Key insight:** Instead of thinking about which balloon to burst first, think about which balloon is the **last** to be burst in an interval `(left, right)`. When it's the last burst, its neighbors are the virtual boundaries.

Pad with `1` on both ends: `nums = [1, ...original..., 1]` (size n+2).

`dp[left][right]` = max coins from bursting all balloons in the open interval `(left, right)`.

```csharp
public static int MaxCoins(int[] nums)
{
    int n = nums.Length;
    // Pad with 1s on both sides
    var padded = new int[n + 2];
    padded[0] = padded[n + 1] = 1;
    for (int i = 0; i < n; i++) padded[i + 1] = nums[i];
    n += 2;

    var dp = new int[n, n];

    // Fill by interval length
    for (int len = 2; len < n; len++)     // len = right - left
    for (int left = 0; left < n - len; left++)
    {
        int right = left + len;
        for (int k = left + 1; k < right; k++) // k is the last balloon burst in (left, right)
        {
            int coins = padded[left] * padded[k] * padded[right]
                      + dp[left, k] + dp[k, right];
            dp[left, right] = Math.Max(dp[left, right], coins);
        }
    }
    return dp[0, n - 1];
}
```

---

## Complexity Summary

| Approach     | Time  | Space |
|--------------|-------|-------|
| Interval DP  | O(n³) | O(n²) |

---

## Interview Tips

- The **reverse thinking** (last burst = boundary) is the breakthrough insight. Without it, the state space is intractable.
- Iterate by increasing interval length so subproblems are always computed first.
- This is a classic **interval DP** pattern — similar structure to Matrix Chain Multiplication.
