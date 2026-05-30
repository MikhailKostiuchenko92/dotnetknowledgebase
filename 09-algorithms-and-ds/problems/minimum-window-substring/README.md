# Minimum Window Substring

**Source:** LeetCode #76
**Difficulty:** 🟡 Medium
**Topics:** String, Sliding Window, Frequency Map

## Problem Statement

Given two strings `s` and `t`, return the **minimum window substring** of `s` such that every character in `t` (including duplicates) is included in the window. If no such window exists, return `""`.

## Examples

```
Input:  s = "ADOBECODEBANC", t = "ABC"
Output: "BANC"

Input:  s = "a", t = "a"
Output: "a"

Input:  s = "a", t = "aa"
Output: ""   // only one 'a' in s, need two
```

## Constraints

- `1 <= s.Length, t.Length <= 10⁵`
- `s` and `t` consist of uppercase and lowercase English letters.

---

## Approach: Sliding Window + Two Frequency Maps — O(|s| + |t|) time, O(|t|) space

### Algorithm

1. Build a **need** map: character → required count from `t`.
2. Maintain a **window** map for the current window in `s`.
3. Track `formed`: how many unique characters from `t` have their required count satisfied in the window.
4. Expand `right`; when `formed == required`, try to shrink `left` to minimise the window.

```csharp
public static string MinWindow(string s, string t)
{
    if (s.Length == 0 || t.Length == 0) return "";

    // Build frequency map for t
    var need = new Dictionary<char, int>();
    foreach (char c in t)
        need[c] = need.GetValueOrDefault(c) + 1;

    int required = need.Count; // number of unique chars in t that must be satisfied
    var window = new Dictionary<char, int>();

    int formed = 0;    // unique chars currently meeting their required count
    int left = 0;
    int minLen = int.MaxValue;
    int minLeft = 0;

    for (int right = 0; right < s.Length; right++)
    {
        // Expand window to the right
        char c = s[right];
        window[c] = window.GetValueOrDefault(c) + 1;

        // Check if this char's frequency in window meets the requirement
        if (need.TryGetValue(c, out int req) && window[c] == req)
            formed++;

        // Contract window from the left while all requirements are met
        while (formed == required && left <= right)
        {
            // Update answer
            if (right - left + 1 < minLen)
            {
                minLen = right - left + 1;
                minLeft = left;
            }

            // Remove leftmost character
            char lc = s[left++];
            window[lc]--;
            if (need.TryGetValue(lc, out int lReq) && window[lc] < lReq)
                formed--;
        }
    }

    return minLen == int.MaxValue ? "" : s.Substring(minLeft, minLen);
}
```

### Walkthrough: `s = "ADOBECODEBANC"`, `t = "ABC"`

```
need = {A:1, B:1, C:1}, required = 3

Expand until formed==3: window covers "ADOBEC" (indices 0–5)
Shrink: remove 'A' → formed drops to 2
Expand to include next 'A' at index 10 → "ADOBECODEBA" (too big)
  ... keep shrinking → "BANC" (indices 9–12) → length 4 ← minimum
```

---

## Optimisation: Filtered Index List

If `|t|` is much smaller than `|s|`, pre-filter `s` to only indices with characters that appear in `t`. Reduces inner loop iterations.

```csharp
// Build filtered positions
var filtered = s.Select((c, i) => (c, i))
                .Where(x => need.ContainsKey(x.c))
                .ToList();
// Then run the two-pointer on 'filtered' instead of all of 's'
```

Useful when `|s| >> |t|`, e.g., s = 10⁶ chars but t has only 3 unique chars.

---

## Complexity Summary

| | Time | Space |
|---|---|---|
| Two-pointer sliding window | O(\|s\| + \|t\|) | O(\|t\|) |
| With filtered list | O(\|s\| + \|t\|) | O(\|s\| + \|t\|) |

---

## Interview Tips

- This is one of the hardest 🟡 problems — state the approach before coding: *"I'll use two pointers and two frequency maps, tracking how many unique chars from `t` are currently satisfied."*
- **Key variables to explain:** `required` (goal) and `formed` (current); shrink when they're equal.
- **Edge cases:** `t` has duplicates (`t = "AA"` needs two A's in the window), `t` not found in `s` at all.
- **Common mistake:** Using a single dict without separating `need` vs `window` — causes confusion when chars appear in `s` but not in `t`.
- **Follow-up:** *"Find all such windows."* → Collect all windows when `formed == required` during the contraction phase.
- **Follow-up:** *"What if characters have weights?"* → Adjust the `formed` logic to track weighted sums.
