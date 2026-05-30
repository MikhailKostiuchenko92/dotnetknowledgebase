# Longest Substring Without Repeating Characters

**Source:** LeetCode #3
**Difficulty:** 🟡 Medium
**Topics:** String, Sliding Window, HashSet / Dictionary

## Problem Statement

Given a string `s`, find the length of the **longest substring without repeating characters**.

## Examples

```
Input:  s = "abcabcbb"
Output: 3   // "abc"

Input:  s = "bbbbb"
Output: 1   // "b"

Input:  s = "pwwkew"
Output: 3   // "wke"

Input:  s = ""
Output: 0
```

## Constraints

- `0 <= s.Length <= 5 × 10⁴`
- `s` consists of English letters, digits, symbols, and spaces.

---

## Approach 1: Sliding Window + HashSet — O(n) time, O(min(n,α)) space

Maintain a window `[left, right)`. Expand `right`; when a duplicate is found, shrink `left` until the duplicate is removed.

```csharp
public static int LengthOfLongestSubstringV1(string s)
{
    var window = new HashSet<char>();
    int left = 0, maxLen = 0;

    for (int right = 0; right < s.Length; right++)
    {
        // Shrink left until window has no duplicate of s[right]
        while (window.Contains(s[right]))
            window.Remove(s[left++]);

        window.Add(s[right]);
        maxLen = Math.Max(maxLen, right - left + 1);
    }

    return maxLen;
}
```

Space: O(α) where α = size of character set (26 for lowercase letters, 128 for ASCII).

---

## Approach 2: Sliding Window + Last-Seen Dictionary — O(n) time, O(α) space

Store the **last seen index** of each character. When a repeat is found, jump `left` directly past the previous occurrence — no inner loop needed.

```csharp
public static int LengthOfLongestSubstring(string s)
{
    // char → last seen index
    var lastSeen = new Dictionary<char, int>(s.Length);
    int left = 0, maxLen = 0;

    for (int right = 0; right < s.Length; right++)
    {
        char c = s[right];

        // If char was seen AND it's still inside the current window
        if (lastSeen.TryGetValue(c, out int prev) && prev >= left)
            left = prev + 1; // jump left past the previous occurrence

        lastSeen[c] = right; // update last seen index
        maxLen = Math.Max(maxLen, right - left + 1);
    }

    return maxLen;
}
```

### Why `prev >= left`?

Without this check, a character seen far to the left (outside the current window) would incorrectly shrink the window. Example: `"abba"` — when we hit the second `a`, its previous index is `0`, but `left` is already `2` (past the first `b`). We must not move `left` backward.

---

## Approach 3: Array as Hash Map (ASCII only) — O(n) time, O(1) space

For ASCII inputs, replace the dictionary with a fixed-size `int[128]` array — faster constant factor.

```csharp
public static int LengthOfLongestSubstringAscii(string s)
{
    var lastSeen = new int[128]; // index + 1; 0 means "not seen"
    Array.Fill(lastSeen, -1);
    int left = 0, maxLen = 0;

    for (int right = 0; right < s.Length; right++)
    {
        int idx = s[right];
        if (lastSeen[idx] >= left)
            left = lastSeen[idx] + 1;

        lastSeen[idx] = right;
        maxLen = Math.Max(maxLen, right - left + 1);
    }

    return maxLen;
}
```

---

## Complexity Summary

| Approach                  | Time | Space  |
|---------------------------|------|--------|
| Sliding window + HashSet  | O(n) | O(α)   |
| Sliding window + Dict     | O(n) | O(α)   |
| Array as hash map (ASCII) | O(n) | O(1)   |

*α = character set size (at most 128 for ASCII, 26 for lowercase letters)*

---

## Interview Tips

- **Name the pattern:** *"This is a classic sliding window problem — I maintain a window and expand/contract it."*
- Clarify the character set: ASCII only? Unicode? The answer affects space complexity.
- **The dictionary approach is faster** because it avoids the inner `while` loop — it's the preferred answer.
- **Edge cases:** empty string (0), single character (1), all same characters ("aaaa" → 1), all unique ("abcd" → 4).
- **Common mistake:** Forgetting the `prev >= left` guard — leads to incorrect window shrinking.
- **Follow-up:** *"Find the actual substring, not just its length."* → Track `maxStart = left` when updating `maxLen`.
