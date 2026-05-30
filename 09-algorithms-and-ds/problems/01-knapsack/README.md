# 0/1 Knapsack

**Source:** Classic problem / Custom
**Difficulty:** 🟡 Medium
**Topics:** Dynamic Programming, Array

## Problem Statement

Given `n` items, each with a weight `w[i]` and value `v[i]`, and a knapsack with capacity `W`, determine the maximum total value you can carry. Each item can be used **at most once** (0/1 choice).

## Examples

```
weights = [1, 3, 4, 5], values = [1, 4, 5, 7], W = 7
Output: 9   // items with w=3,v=4 and w=4,v=5
```

---

## Approach 1: 2-D DP — O(n·W) time, O(n·W) space

`dp[i][w]` = max value using first `i` items with capacity `w`.
- Don't take item `i`: `dp[i-1][w]`
- Take item `i` (if `w[i] <= w`): `dp[i-1][w - w[i]] + v[i]`

```csharp
public static int Knapsack(int[] weights, int[] values, int capacity)
{
    int n = weights.Length;
    var dp = new int[n + 1, capacity + 1];

    for (int i = 1; i <= n; i++)
    for (int w = 0; w <= capacity; w++)
    {
        dp[i, w] = dp[i-1, w]; // don't take item i
        if (weights[i-1] <= w)
            dp[i, w] = Math.Max(dp[i, w], dp[i-1, w - weights[i-1]] + values[i-1]);
    }
    return dp[n, capacity];
}
```

---

## Approach 2: Space-Optimised 1-D — O(n·W) time, O(W) space ✓

Traverse the capacity **right-to-left** in the 1-D array to ensure each item is counted at most once.

```csharp
public static int KnapsackOpt(int[] weights, int[] values, int capacity)
{
    var dp = new int[capacity + 1];

    for (int i = 0; i < weights.Length; i++)
        for (int w = capacity; w >= weights[i]; w--) // right-to-left!
            dp[w] = Math.Max(dp[w], dp[w - weights[i]] + values[i]);

    return dp[capacity];
}
```

> **Key distinction:** 0/1 Knapsack iterates capacity **right-to-left**. Unbounded Knapsack (like Coin Change) iterates **left-to-right**.

---

## Complexity Summary

| Approach    | Time    | Space   |
|-------------|---------|---------|
| 2-D DP      | O(n·W)  | O(n·W)  |
| 1-D DP      | O(n·W)  | O(W)    |

---

## Interview Tips

- **Right-to-left** iteration prevents using the same item twice — the key insight of 0/1 knapsack.
- Common applications: partition equal subset sum (LeetCode #416), target sum (LeetCode #494).
- **Follow-up:** *"Unbounded knapsack?"* → Left-to-right iteration; each item reusable (Coin Change pattern).
