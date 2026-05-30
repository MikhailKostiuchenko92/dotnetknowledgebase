# Regular Expression Matching

**Source:** LeetCode #10
**Difficulty:** 🔴 Hard
**Topics:** String, Dynamic Programming, Recursion

## Problem Statement

Given an input string `s` and a pattern `p`, implement regular expression matching with support for `'.'` (any single character) and `'*'` (zero or more of the preceding character).

The matching must cover the entire string.

## Examples

```
Input: s = "aa",  p = "a"      Output: false
Input: s = "aa",  p = "a*"     Output: true
Input: s = "ab",  p = ".*"     Output: true
Input: s = "aab", p = "c*a*b"  Output: true
```

## Constraints

- `1 <= s.Length <= 20`; `1 <= p.Length <= 30`; lowercase letters only.

---

## Approach: 2-D DP — O(m·n) time, O(m·n) space ✓

`dp[i][j]` = does `s[0..i-1]` match `p[0..j-1]`?

Cases for `p[j-1]`:
1. `'.'` or letter that matches `s[i-1]`: `dp[i][j] = dp[i-1][j-1]`
2. `'*'`:
   - **Zero occurrences** of preceding char: `dp[i][j] = dp[i][j-2]`
   - **One or more:** if `p[j-2]` matches `s[i-1]` (letter match or `'.'`): `dp[i][j] |= dp[i-1][j]`

```csharp
public static bool IsMatch(string s, string p)
{
    int m = s.Length, n = p.Length;
    var dp = new bool[m + 1, n + 1];
    dp[0, 0] = true;

    // Handle patterns like a*, a*b*, a*b*c* matching empty string
    for (int j = 2; j <= n; j++)
        if (p[j-1] == '*') dp[0, j] = dp[0, j-2];

    for (int i = 1; i <= m; i++)
    for (int j = 1; j <= n; j++)
    {
        if (p[j-1] == '*')
        {
            dp[i, j] = dp[i, j-2]; // zero occurrences
            bool charMatch = p[j-2] == '.' || p[j-2] == s[i-1];
            if (charMatch) dp[i, j] |= dp[i-1, j]; // one+ occurrences
        }
        else
        {
            bool charMatch = p[j-1] == '.' || p[j-1] == s[i-1];
            dp[i, j] = charMatch && dp[i-1, j-1];
        }
    }
    return dp[m, n];
}
```

---

## Complexity Summary

| Approach  | Time   | Space   |
|-----------|--------|---------|
| 2-D DP    | O(m·n) | O(m·n)  |

---

## Interview Tips

- The `'*'` case is the tricky one — think "zero occurrences" (skip 2 in pattern) vs "one+ occurrences" (advance in string).
- **`dp[i-1][j]`** for one+ occurrences: `i-1` moves forward in `s`; `j` stays to allow more matches of `p[j-2]`.
- **Related:** [Wildcard Matching](../wildcard-matching/README.md) — similar but `'*'` matches any sequence directly.
