# Longest Common Subsequence (LCS)

**Source:** LeetCode #1143
**Difficulty:** 🟡 Medium
**Topics:** String, Dynamic Programming

## Problem Statement

Given two strings `text1` and `text2`, return the length of their **longest common subsequence**. A subsequence is a sequence derived by deleting some characters without changing the relative order.

## Examples

```
Input: text1 = "abcde", text2 = "ace"    Output: 3   // "ace"
Input: text1 = "abc",   text2 = "abc"    Output: 3
Input: text1 = "abc",   text2 = "def"    Output: 0
```

## Constraints

- `1 <= text1.Length, text2.Length <= 1000`

---

## Approach 1: 2-D DP — O(m·n) time, O(m·n) space

`dp[i][j]` = LCS of `text1[0..i-1]` and `text2[0..j-1]`.
- If `text1[i-1] == text2[j-1]`: `dp[i][j] = dp[i-1][j-1] + 1`
- Else: `dp[i][j] = max(dp[i-1][j], dp[i][j-1])`

```csharp
public static int LongestCommonSubsequence(string text1, string text2)
{
    int m = text1.Length, n = text2.Length;
    var dp = new int[m + 1, n + 1];

    for (int i = 1; i <= m; i++)
    for (int j = 1; j <= n; j++)
        dp[i, j] = text1[i-1] == text2[j-1]
            ? dp[i-1, j-1] + 1
            : Math.Max(dp[i-1, j], dp[i, j-1]);

    return dp[m, n];
}
```

---

## Approach 2: Space-Optimised 1-D — O(m·n) time, O(n) space ✓

Only the previous row is needed; use two arrays (or a single array with `prev` tracking).

```csharp
public static int LCSOptimised(string text1, string text2)
{
    int m = text1.Length, n = text2.Length;
    var prev = new int[n + 1];

    for (int i = 1; i <= m; i++)
    {
        var curr = new int[n + 1];
        for (int j = 1; j <= n; j++)
            curr[j] = text1[i-1] == text2[j-1]
                ? prev[j-1] + 1
                : Math.Max(prev[j], curr[j-1]);
        prev = curr;
    }
    return prev[n];
}
```

---

## Complexity Summary

| Approach    | Time   | Space   |
|-------------|--------|---------|
| 2-D DP      | O(m·n) | O(m·n)  |
| 1-D rolling | O(m·n) | O(n)    |

---

## Interview Tips

- This is one of the **canonical DP** problems — know the recurrence by heart.
- **Related:** [Edit Distance](../edit-distance/README.md) — builds on LCS logic. [Longest Increasing Subsequence](../longest-increasing-subsequence/README.md) — 1-D variant.
- To reconstruct the actual subsequence, backtrack through the `dp` table.
