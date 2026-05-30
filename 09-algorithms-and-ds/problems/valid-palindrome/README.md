# Valid Palindrome

**Source:** LeetCode #125
**Difficulty:** 🟢 Easy
**Topics:** Strings, Two-Pointer

## Problem Statement

A phrase is a **palindrome** if, after converting all uppercase letters to lowercase and removing all non-alphanumeric characters, it reads the same forward and backward.

Given a string `s`, return `true` if it is a palindrome, or `false` otherwise.

## Examples

```
Input:  s = "A man, a plan, a canal: Panama"
Output: true   // "amanaplanacanalpanama" is a palindrome

Input:  s = "race a car"
Output: false  // "raceacar" is not a palindrome

Input:  s = " "
Output: true   // empty after stripping → valid palindrome
```

## Constraints

- `1 <= s.Length <= 2 × 10⁵`
- `s` consists only of printable ASCII characters.

---

## Approach 1: Sanitise Then Two-Pointer — O(n) time, O(n) space

Build a cleaned string first, then check it.

```csharp
public static bool IsPalindromeV1(string s)
{
    // LINQ: filter + lowercase — readable but allocates
    string clean = new string(s.Where(char.IsLetterOrDigit)
                                .Select(char.ToLowerInvariant)
                                .ToArray());

    int lo = 0, hi = clean.Length - 1;
    while (lo < hi)
    {
        if (clean[lo] != clean[hi]) return false;
        lo++; hi--;
    }
    return true;
}
```

---

## Approach 2: Two-Pointer on Original String — O(n) time, O(1) space

Skip non-alphanumeric characters directly using two pointers. No extra string allocation.

```csharp
public static bool IsPalindrome(string s)
{
    int lo = 0, hi = s.Length - 1;

    while (lo < hi)
    {
        // Skip non-alphanumeric from the left
        while (lo < hi && !char.IsLetterOrDigit(s[lo])) lo++;
        // Skip non-alphanumeric from the right
        while (lo < hi && !char.IsLetterOrDigit(s[hi])) hi--;

        if (char.ToLowerInvariant(s[lo]) != char.ToLowerInvariant(s[hi]))
            return false;

        lo++;
        hi--;
    }
    return true;
}
```

> **Why `char.ToLowerInvariant` and not `char.ToLower`?**  
> `ToLower()` is culture-sensitive (e.g., Turkish 'I' → 'ı'), which can give wrong results in a palindrome check. Always use `ToLowerInvariant` for ASCII/ordinal comparisons.

---

## Approach 3: `Span<char>` variant — O(n) time, O(n) space (stack for small input)

Useful if you want to show Span knowledge:

```csharp
public static bool IsPalindromeSpan(string s)
{
    // Build cleaned buffer without heap allocation for short strings
    Span<char> buf = s.Length <= 512 ? stackalloc char[s.Length] : new char[s.Length];
    int len = 0;
    foreach (char c in s)
        if (char.IsLetterOrDigit(c))
            buf[len++] = char.ToLowerInvariant(c);

    Span<char> clean = buf[..len];
    int lo = 0, hi = len - 1;
    while (lo < hi)
    {
        if (clean[lo] != clean[hi]) return false;
        lo++; hi--;
    }
    return true;
}
```

---

## Complexity Summary

| Approach                  | Time | Space  |
|---------------------------|------|--------|
| Sanitise then two-pointer | O(n) | O(n)   |
| Two-pointer on original   | O(n) | O(1)   |
| Span<char> variant        | O(n) | O(1)*  |

---

## Interview Tips

- **Clarify:** "Should I consider only alphanumeric characters, or all characters?" LeetCode #125 filters to alphanumeric only.
- **Mention edge cases:** empty string (true), single char (true), string of spaces (true after stripping), case mismatch ("Racecar" → true).
- The two-pointer O(1)-space version is the expected answer in interviews.
- Follow-up: *"What if the string contains Unicode / emoji?"* — `char.IsLetterOrDigit` works for Unicode; surrogate pairs would need `StringInfo` for correct grapheme cluster handling.
- Related: [Valid Palindrome II](https://leetcode.com/problems/valid-palindrome-ii/) (at most one deletion allowed) — extends this with a helper check.
