# Valid Anagram

**Source:** LeetCode #242
**Difficulty:** 🟢 Easy
**Topics:** String, HashMap, Sorting

## Problem Statement

Given two strings `s` and `t`, return `true` if `t` is an **anagram** of `s`, and `false` otherwise.

An anagram uses all original characters exactly once.

## Examples

```
Input:  s = "anagram", t = "nagaram"
Output: true

Input:  s = "rat", t = "car"
Output: false

Input:  s = "a", t = "ab"
Output: false   // different lengths
```

## Constraints

- `1 <= s.Length, t.Length <= 5 × 10⁴`
- `s` and `t` consist of lowercase English letters.

---

## Approach 1: Frequency Array — O(n) time, O(1) space ✓ Preferred

Since only lowercase letters are involved, use a fixed `int[26]` array. Increment for each char in `s`, decrement for each char in `t`. If all counts are zero, they're anagrams.

```csharp
public static bool IsAnagram(string s, string t)
{
    if (s.Length != t.Length) return false;

    int[] count = new int[26];
    for (int i = 0; i < s.Length; i++)
    {
        count[s[i] - 'a']++;
        count[t[i] - 'a']--;
    }

    foreach (int c in count)
        if (c != 0) return false;

    return true;
}
```

---

## Approach 2: Sort Both Strings — O(n log n) time, O(n) space

```csharp
public static bool IsAnagramSort(string s, string t)
{
    if (s.Length != t.Length) return false;

    char[] sa = s.ToCharArray(); Array.Sort(sa);
    char[] ta = t.ToCharArray(); Array.Sort(ta);
    return new string(sa) == new string(ta);
}
```

---

## Approach 3: Dictionary (Unicode support) — O(n) time, O(k) space

For the follow-up (Unicode characters, not just lowercase ASCII):

```csharp
public static bool IsAnagramUnicode(string s, string t)
{
    if (s.Length != t.Length) return false;

    var count = new Dictionary<char, int>();
    foreach (char c in s) count[c] = count.GetValueOrDefault(c) + 1;
    foreach (char c in t)
    {
        if (!count.TryGetValue(c, out int n) || n == 0) return false;
        count[c] = n - 1;
    }
    return true;
}
```

---

## Complexity Summary

| Approach         | Time      | Space |
|------------------|-----------|-------|
| Frequency array  | O(n)      | O(1)  |
| Sort             | O(n log n)| O(n)  |
| Dictionary       | O(n)      | O(k)  |

---

## Interview Tips

- **Always check lengths first** — different lengths immediately means not an anagram.
- Mention the `int[26]` trick for lowercase-only inputs.
- **Follow-up:** *"What if inputs contain Unicode characters?"* → Use a `Dictionary<char,int>` instead of the fixed array.
- **Follow-up:** *"What if the strings are very large and you can't load them into memory?"* → Stream through the files, maintaining a frequency dictionary.
- Related: [Group Anagrams](../group-anagrams/README.md).
