# Edit Distance (Levenshtein Distance)

**Source:** LeetCode #72
**Difficulty:** 🔴 Hard
**Topics:** String, Dynamic Programming

## Problem Statement

Given two strings `word1` and `word2`, return the minimum number of operations (insert, delete, replace) required to convert `word1` into `word2`.

## Examples

```
Input: word1 = "horse", word2 = "ros"   Output: 3
// horse → rorse (replace h→r) → rose (delete r) → ros (delete e)
Input: word1 = "intention", word2 = "execution"   Output: 5
```

## Constraints

- `0 <= word1.Length, word2.Length <= 500`

---

## Approach: 2-D DP — O(m·n) time, O(m·n) space ✓

`dp[i][j]` = min edits to convert `word1[0..i-1]` to `word2[0..j-1]`.
- **Match:** `word1[i-1] == word2[j-1]` → `dp[i-1][j-1]` (no cost)
- **Replace:** `dp[i-1][j-1] + 1`
- **Insert** (into word1): `dp[i][j-1] + 1`
- **Delete** (from word1): `dp[i-1][j] + 1`

```csharp
public static int MinDistance(string word1, string word2)
{
    int m = word1.Length, n = word2.Length;
    var dp = new int[m + 1, n + 1];

    // Base cases: converting to/from empty string
    for (int i = 0; i <= m; i++) dp[i, 0] = i;
    for (int j = 0; j <= n; j++) dp[0, j] = j;

    for (int i = 1; i <= m; i++)
    for (int j = 1; j <= n; j++)
    {
        if (word1[i-1] == word2[j-1])
            dp[i, j] = dp[i-1, j-1];
        else
            dp[i, j] = 1 + Math.Min(dp[i-1, j-1],   // replace
                            Math.Min(dp[i, j-1],      // insert
                                     dp[i-1, j]));    // delete
    }
    return dp[m, n];
}
```

### Table for "horse" → "ros"

|   |   | r | o | s |
|---|---|---|---|---|
|   | 0 | 1 | 2 | 3 |
| h | 1 | 1 | 2 | 3 |
| o | 2 | 2 | 1 | 2 |
| r | 3 | 2 | 2 | 2 |
| s | 4 | 3 | 3 | 2 |
| e | 5 | 4 | 4 | 3 |

---

## Complexity Summary

| Approach     | Time   | Space   |
|--------------|--------|---------|
| 2-D DP       | O(m·n) | O(m·n)  |
| 1-D rolling  | O(m·n) | O(n)    |

---

## Interview Tips

- Walk through the small example table above during the interview.
- **The three operations** map directly to three neighbors in the DP table: diagonal = replace, left = insert, up = delete.
- **Related:** [LCS](../longest-common-subsequence/README.md) — complementary DP. [Regular Expression Matching](../regular-expression-matching/README.md) — similar 2-D DP structure.
