# Decode Ways

**Source:** LeetCode #91
**Difficulty:** 🟡 Medium
**Topics:** String, Dynamic Programming

## Problem Statement

A string of digits can be encoded as letters: `'A'=1`, `'B'=2`, ..., `'Z'=26`. Given a string `s` of digits, return the **number of ways** to decode it.

## Examples

```
Input: s = "12"    Output: 2   // "AB" or "L"
Input: s = "226"   Output: 3   // "BZ"(2,26), "VF"(22,6), "BBF"(2,2,6)
Input: s = "06"    Output: 0   // "06" can't be "F"; leading zero is invalid
```

## Constraints

- `1 <= s.Length <= 100`; `s` contains only digits; may contain leading zeros.

---

## Approach: Bottom-Up DP — O(n) time, O(1) space ✓

`dp[i]` = number of ways to decode `s[0..i-1]`.
- **Single digit** `s[i-1]`: valid if `'1'–'9'` → add `dp[i-1]`.
- **Two digits** `s[i-2..i-1]`: valid if `10–26` → add `dp[i-2]`.

```csharp
public static int NumDecodings(string s)
{
    int n = s.Length;
    // prev2 = dp[i-2], prev1 = dp[i-1]
    int prev2 = 1; // dp[0] — empty string has one decoding
    int prev1 = s[0] != '0' ? 1 : 0; // dp[1]

    for (int i = 2; i <= n; i++)
    {
        int curr = 0;
        int oneDigit = s[i - 1] - '0';
        int twoDigit = int.Parse(s[(i - 2)..i]);

        if (oneDigit >= 1) curr += prev1;              // valid single digit
        if (twoDigit >= 10 && twoDigit <= 26) curr += prev2; // valid two digits

        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;
}
```

---

## Complexity Summary

| Approach     | Time | Space |
|--------------|------|-------|
| Bottom-up DP | O(n) | O(1)  |

---

## Interview Tips

- **`'0'` kills single-digit paths** — `oneDigit >= 1` handles this.
- Two-digit range: exactly `10–26`. `07` and `30` are invalid.
- `int.Parse(s[(i-2)..i])` — range operator for substring, works for 2-char strings.
- **Edge case:** `s = "0"` → return 0. `s = "10"` → 1 way ("J"). `s = "100"` → 0 ways.
