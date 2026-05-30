# Unique Paths

**Source:** LeetCode #62
**Difficulty:** 🟡 Medium
**Topics:** Math, Dynamic Programming, Combinatorics

## Problem Statement

A robot is on an `m × n` grid at the top-left corner and wants to reach the bottom-right corner. The robot can only move down or right. How many unique paths are there?

## Examples

```
Input: m = 3, n = 7   Output: 28
Input: m = 3, n = 2   Output: 3
```

## Constraints

- `1 <= m, n <= 100`

---

## Approach 1: Bottom-Up DP — O(m·n) time, O(m·n) space

```csharp
public static int UniquePaths(int m, int n)
{
    var dp = new int[m, n];
    for (int r = 0; r < m; r++) dp[r, 0] = 1;
    for (int c = 0; c < n; c++) dp[0, c] = 1;

    for (int r = 1; r < m; r++)
    for (int c = 1; c < n; c++)
        dp[r, c] = dp[r-1, c] + dp[r, c-1];

    return dp[m-1, n-1];
}
```

---

## Approach 2: 1-D DP — O(m·n) time, O(n) space ✓

Roll the 2-D array into a single row.

```csharp
public static int UniquePathsOpt(int m, int n)
{
    var dp = new int[n];
    Array.Fill(dp, 1);
    for (int r = 1; r < m; r++)
    for (int c = 1; c < n; c++)
        dp[c] += dp[c - 1];
    return dp[n - 1];
}
```

---

## Approach 3: Combinatorics — O(min(m,n)) time, O(1) space

Total steps = `m+n-2`; choose `m-1` downward steps: C(m+n-2, m-1).

```csharp
public static int UniquePathsMath(int m, int n)
{
    long result = 1;
    int smaller = Math.Min(m - 1, n - 1);
    int total   = m + n - 2;
    for (int i = 0; i < smaller; i++)
        result = result * (total - i) / (i + 1);
    return (int)result;
}
```

---

## Complexity Summary

| Approach        | Time   | Space   |
|-----------------|--------|---------|
| 2-D DP          | O(m·n) | O(m·n)  |
| 1-D DP          | O(m·n) | O(n)    |
| Combinatorics   | O(min) | O(1)    |

---

## Interview Tips

- Lead with 2-D DP as the obvious solution, then optimise to 1-D.
- Mention the combinatorics approach as a bonus — but explain risk of integer overflow for large inputs.
- **Follow-up:** [Minimum Path Sum](../minimum-path-sum/README.md) — same grid DP with costs.
