# Climbing Stairs

**Source:** LeetCode #70
**Difficulty:** 🟢 Easy
**Topics:** Math, Dynamic Programming, Memoisation

## Problem Statement

You are climbing a staircase. It takes `n` steps to reach the top. Each time you can climb 1 or 2 steps. In how many distinct ways can you climb to the top?

## Examples

```
Input: n = 2   Output: 2   // (1+1) or (2)
Input: n = 3   Output: 3   // (1+1+1), (1+2), (2+1)
```

## Constraints

- `1 <= n <= 45`

---

## Approach: Bottom-Up DP (Fibonacci) — O(n) time, O(1) space ✓

`dp[i] = dp[i-1] + dp[i-2]` — the number of ways to reach step `i` equals ways to reach `i-1` (then take 1 step) plus ways to reach `i-2` (then take 2 steps).

```csharp
public static int ClimbStairs(int n)
{
    if (n <= 2) return n;
    int prev2 = 1, prev1 = 2;
    for (int i = 3; i <= n; i++)
        (prev2, prev1) = (prev1, prev1 + prev2);
    return prev1;
}
```

---

## Complexity Summary

| Approach        | Time | Space |
|-----------------|------|-------|
| Bottom-up DP    | O(n) | O(1)  |

---

## Interview Tips

- This is literally Fibonacci — recognise the pattern immediately and state it.
- **Follow-up:** *"What if you can take 1, 2, or 3 steps?"* → `dp[i] = dp[i-1] + dp[i-2] + dp[i-3]`.
- **Follow-up:** *"What if costs are attached to each step?"* → LeetCode #746 "Min Cost Climbing Stairs".
