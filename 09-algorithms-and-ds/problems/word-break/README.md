# Word Break

**Source:** LeetCode #139
**Difficulty:** 🟡 Medium
**Topics:** String, Dynamic Programming, Trie

## Problem Statement

Given a string `s` and a dictionary `wordDict`, return `true` if `s` can be segmented into a space-separated sequence of one or more dictionary words.

## Examples

```
Input: s = "leetcode", wordDict = ["leet","code"]   Output: true
Input: s = "applepenapple", wordDict = ["apple","pen"]   Output: true
Input: s = "catsandog", wordDict = ["cats","dog","sand","and","cat"]   Output: false
```

## Constraints

- `1 <= s.Length <= 300`; `1 <= wordDict.Length <= 1000`; all lowercase letters.

---

## Approach: Bottom-Up DP — O(n² · m) time, O(n) space ✓

`dp[i]` = `true` if `s[0..i-1]` can be segmented. For each position `i`, try all possible last-word endings `j..i-1`.

```csharp
public static bool WordBreak(string s, IList<string> wordDict)
{
    var wordSet = new HashSet<string>(wordDict);
    int n = s.Length;
    var dp = new bool[n + 1];
    dp[0] = true; // empty prefix is always "segmented"

    for (int i = 1; i <= n; i++)
    {
        for (int j = 0; j < i; j++)
        {
            if (dp[j] && wordSet.Contains(s[j..i]))
            {
                dp[i] = true;
                break; // no need to check further j values
            }
        }
    }
    return dp[n];
}
```

### Optimisation: Limit inner loop by max word length

```csharp
int maxLen = wordDict.Max(w => w.Length);
for (int j = Math.Max(0, i - maxLen); j < i; j++) { ... }
```

---

## Complexity Summary

| Approach         | Time         | Space |
|------------------|--------------|-------|
| Bottom-up DP     | O(n² · m)    | O(n)  |
| + max word limit | O(n · W · m) | O(n)  |

*m = avg word length for substring comparison, W = max word length.*

---

## Interview Tips

- `dp[0] = true` is the base case: empty string → no segmentation needed.
- Using `HashSet<string>` makes `Contains` O(m) (string hash) instead of O(dict × m).
- **Follow-up:** *"Return all possible sentences."* → LeetCode #140 "Word Break II" — DFS + memoisation.
