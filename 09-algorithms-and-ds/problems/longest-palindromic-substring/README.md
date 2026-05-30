# Longest Palindromic Substring

**Source:** LeetCode #5
**Difficulty:** 🔴 Hard
**Topics:** String, Dynamic Programming, Expand Around Center

## Problem Statement

Given a string `s`, return the **longest palindromic substring** in `s`.

## Examples

```
Input:  s = "babad"
Output: "bab"  (or "aba" — both valid)

Input:  s = "cbbd"
Output: "bb"

Input:  s = "a"
Output: "a"

Input:  s = "ac"
Output: "a"
```

## Constraints

- `1 <= s.Length <= 1000`
- `s` consists of only digits and English letters.

---

## Approach 1: Expand Around Center — O(n²) time, O(1) space ✓ Preferred

For each index `i`, try expanding a palindrome centred at:
- `i` (odd-length palindromes, e.g., "aba")
- `(i, i+1)` (even-length palindromes, e.g., "abba")

```csharp
public static string LongestPalindrome(string s)
{
    int start = 0, maxLen = 1;

    for (int i = 0; i < s.Length; i++)
    {
        // Odd-length: centre at i
        Expand(s, i, i, ref start, ref maxLen);
        // Even-length: centre between i and i+1
        Expand(s, i, i + 1, ref start, ref maxLen);
    }

    return s.Substring(start, maxLen);
}

private static void Expand(string s, int lo, int hi, ref int start, ref int maxLen)
{
    while (lo >= 0 && hi < s.Length && s[lo] == s[hi])
    {
        lo--;
        hi++;
    }
    // After loop: lo and hi are one step outside the palindrome
    int len = hi - lo - 1;
    if (len > maxLen)
    {
        maxLen = len;
        start = lo + 1;
    }
}
```

---

## Approach 2: Dynamic Programming — O(n²) time, O(n²) space

`dp[i][j]` = true if `s[i..j]` is a palindrome.

```csharp
public static string LongestPalindromeDP(string s)
{
    int n = s.Length;
    bool[,] dp = new bool[n, n];
    int start = 0, maxLen = 1;

    // All single chars are palindromes
    for (int i = 0; i < n; i++) dp[i, i] = true;

    // Check length-2 substrings
    for (int i = 0; i < n - 1; i++)
        if (s[i] == s[i + 1]) { dp[i, i + 1] = true; start = i; maxLen = 2; }

    // Check lengths 3..n
    for (int len = 3; len <= n; len++)
    {
        for (int i = 0; i <= n - len; i++)
        {
            int j = i + len - 1;
            if (s[i] == s[j] && dp[i + 1, j - 1])
            {
                dp[i, j] = true;
                if (len > maxLen) { maxLen = len; start = i; }
            }
        }
    }

    return s.Substring(start, maxLen);
}
```

---

## Approach 3: Manacher's Algorithm — O(n) time, O(n) space

Manacher's algorithm finds all palindromic substrings in linear time by leveraging previously computed results. It's rarely expected in interviews but worth knowing.

**Key idea:** Transform `s` into `#a#b#a#` (insert separators), then maintain a "rightmost palindrome" boundary and its centre to reuse symmetry.

> Implementing Manacher's from scratch in an interview is impressive but risky unless you know it cold. Mention it to show breadth, then implement the O(n²) solution.

```csharp
public static string LongestPalindromeManacher(string s)
{
    // Transform: "abc" → "#a#b#c#"
    var t = string.Concat(s.SelectMany(c => new[] { '#', c })).Prepend('#');
    string T = new string(t.ToArray());
    int n = T.Length;
    int[] p = new int[n]; // p[i] = radius of palindrome at i in T
    int center = 0, right = 0;

    for (int i = 0; i < n; i++)
    {
        if (i < right)
            p[i] = Math.Min(right - i, p[2 * center - i]);

        while (i - p[i] - 1 >= 0 && i + p[i] + 1 < n && T[i - p[i] - 1] == T[i + p[i] + 1])
            p[i]++;

        if (i + p[i] > right) { center = i; right = i + p[i]; }
    }

    int maxIdx = Array.IndexOf(p, p.Max());
    int startInS = (maxIdx - p[maxIdx]) / 2;
    return s.Substring(startInS, p[maxIdx]);
}
```

---

## Complexity Summary

| Approach            | Time  | Space |
|---------------------|-------|-------|
| Expand around center| O(n²) | O(1)  |
| Dynamic programming | O(n²) | O(n²) |
| Manacher's          | O(n)  | O(n)  |

---

## Interview Tips

- **Recommended answer:** Expand around center — O(n²) time, O(1) space. Simple to implement and explain.
- Walk through the `"babad"` example showing both odd and even expansions.
- **Edge cases:** Single character (always a palindrome), two characters, all same characters ("aaaa" → entire string).
- **Common mistake in DP approach:** Iterating by start index instead of substring length (causes incorrect dependencies).
- **Mention Manacher's** to impress but don't implement it unless the interviewer asks for O(n).
- **Follow-up:** *"Count the number of palindromic substrings."* → LeetCode #647 — use the same expand-around-center approach but count instead of track max.
