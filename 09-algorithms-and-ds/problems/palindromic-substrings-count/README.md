# Count Palindromic Substrings

**Source:** LeetCode #647
**Difficulty:** 🟡 Medium
**Topics:** String, Dynamic Programming, Two Pointers

## Problem Statement

Given a string `s`, return the **number of palindromic substrings** in it. A substring is a contiguous sequence of characters. Single characters are palindromes.

## Examples

```
Input: s = "abc"   Output: 3   // "a","b","c"
Input: s = "aaa"   Output: 6   // "a","a","a","aa","aa","aaa"
```

## Constraints

- `1 <= s.Length <= 1000`

---

## Approach 1: Expand Around Centre — O(n²) time, O(1) space ✓

For each character (odd-length centres) and each pair (even-length centres), expand outward while characters match.

```csharp
public static int CountSubstrings(string s)
{
    int count = 0;

    void Expand(int left, int right)
    {
        while (left >= 0 && right < s.Length && s[left] == s[right])
        {
            count++;
            left--;
            right++;
        }
    }

    for (int i = 0; i < s.Length; i++)
    {
        Expand(i, i);     // odd-length
        Expand(i, i + 1); // even-length
    }
    return count;
}
```

---

## Approach 2: DP — O(n²) time, O(n²) space

`dp[i][j]` = true if `s[i..j]` is a palindrome.
- Single char: always true.
- Two chars: `s[i] == s[j]`.
- Longer: `s[i] == s[j] && dp[i+1][j-1]`.

---

## Complexity Summary

| Approach              | Time  | Space |
|-----------------------|-------|-------|
| Expand around centre  | O(n²) | O(1)  |
| DP                    | O(n²) | O(n²) |
| Manacher's Algorithm  | O(n)  | O(n)  |

---

## Interview Tips

- Expand-around-centre is the go-to: simple, O(1) space.
- **Manacher's** runs in O(n) — mention it as a bonus if the interviewer pushes for optimal.
- **Related:** LeetCode #5 "Longest Palindromic Substring" — same expansion, just track the longest instead of counting.
