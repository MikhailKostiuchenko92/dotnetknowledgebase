# Wildcard Matching

**Source:** LeetCode #44
**Difficulty:** 🔴 Hard
**Topics:** String, Dynamic Programming, Greedy

## Problem Statement

Given an input string `s` and a pattern `p` (with `'?'` matching any single character, and `'*'` matching any sequence including empty), return `true` if the pattern matches the whole string.

## Examples

```
Input: s = "aa",    p = "a"      Output: false
Input: s = "aa",    p = "*"      Output: true
Input: s = "cb",    p = "?a"     Output: false
Input: s = "adceb", p = "*a*b"   Output: true
```

## Constraints

- `0 <= s.Length, p.Length <= 2000`; lowercase letters only.

---

## Approach: 2-D DP — O(m·n) time, O(m·n) space ✓

`dp[i][j]` = does `s[0..i-1]` match `p[0..j-1]`?

- `p[j-1] == '*'`: matches empty (`dp[i][j-1]`) or one+ chars (`dp[i-1][j]`)
- `p[j-1] == '?'` or letter == `s[i-1]`: `dp[i-1][j-1]`

```csharp
public static bool IsMatch(string s, string p)
{
    int m = s.Length, n = p.Length;
    var dp = new bool[m + 1, n + 1];
    dp[0, 0] = true;

    // Leading stars can match empty string
    for (int j = 1; j <= n; j++)
        if (p[j-1] == '*') dp[0, j] = dp[0, j-1];

    for (int i = 1; i <= m; i++)
    for (int j = 1; j <= n; j++)
    {
        if (p[j-1] == '*')
            dp[i, j] = dp[i, j-1] || dp[i-1, j]; // empty or one+char
        else
        {
            bool charMatch = p[j-1] == '?' || p[j-1] == s[i-1];
            dp[i, j] = charMatch && dp[i-1, j-1];
        }
    }
    return dp[m, n];
}
```

### Wildcard vs Regex `'*'`

| | Wildcard `*` | Regex `*` |
|---|---|---|
| Meaning | Any sequence (0+ of **any** char) | 0+ of **preceding** char |
| Pattern `a*b` | `a` then any sequence then `b` | `a` repeated 0+ times then `b` |
| DP `'*'` case | `dp[i][j-1]` or `dp[i-1][j]` | Also involves `dp[i][j-2]` |

---

## Complexity Summary

| Approach  | Time   | Space   |
|-----------|--------|---------|
| 2-D DP    | O(m·n) | O(m·n)  |
| Greedy    | O(m·n) | O(1)    |

---

## Interview Tips

- `dp[i-1][j]` for `'*'`: advance `s` by one char while staying at the same `*` in `p` — matches one more character.
- **Greedy approach** uses backtracking pointers to O(1) space, but is harder to code correctly under pressure.
