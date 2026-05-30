# Group Anagrams

**Source:** LeetCode #49
**Difficulty:** 🟢 Easy
**Topics:** Array, HashMap, Sorting

## Problem Statement

Given an array of strings `strs`, group the **anagrams** together. You can return the answer in any order.

An **anagram** is a word or phrase formed by rearranging the letters of another, using all original letters exactly once.

## Examples

```
Input:  strs = ["eat","tea","tan","ate","nat","bat"]
Output: [["bat"],["nat","tan"],["ate","eat","tea"]]

Input:  strs = [""]
Output: [[""]]

Input:  strs = ["a"]
Output: [["a"]]
```

## Constraints

- `1 <= strs.Length <= 10⁴`
- `0 <= strs[i].Length <= 100`
- `strs[i]` consists of lowercase English letters.

---

## Approach 1: Sort Each Word as Key — O(n · k log k) time, O(n · k) space

Sort each string's characters to form a canonical key. All anagrams share the same sorted key.

```csharp
public static IList<IList<string>> GroupAnagrams(string[] strs)
{
    var map = new Dictionary<string, List<string>>();

    foreach (string s in strs)
    {
        // Canonical key: sorted characters
        char[] key = s.ToCharArray();
        Array.Sort(key);
        string sortedKey = new string(key);

        if (!map.TryGetValue(sortedKey, out var group))
        {
            group = new List<string>();
            map[sortedKey] = group;
        }
        group.Add(s);
    }

    return new List<IList<string>>(map.Values);
}
```

---

## Approach 2: Frequency Count as Key — O(n · k) time, O(n · k) space

Instead of sorting, build a frequency vector of the 26 letters and encode it as a string key. Avoids the `k log k` sort cost.

```csharp
public static IList<IList<string>> GroupAnagramsFreq(string[] strs)
{
    var map = new Dictionary<string, List<string>>();

    foreach (string s in strs)
    {
        int[] count = new int[26];
        foreach (char c in s) count[c - 'a']++;

        // Encode as "a2b1..." — use '#' separator to avoid ambiguity
        var sb = new System.Text.StringBuilder();
        for (int i = 0; i < 26; i++) { sb.Append('#'); sb.Append(count[i]); }
        string key = sb.ToString();

        if (!map.TryGetValue(key, out var group))
        {
            group = new List<string>();
            map[key] = group;
        }
        group.Add(s);
    }

    return new List<IList<string>>(map.Values);
}
```

> **Why '#' separators?** Without separators, `count = [12, 0, ...]` and `[1, 2, 0, ...]` could produce the same string `"120..."`. Separators make each count unambiguous.

---

## Complexity Summary

| Approach        | Time          | Space     |
|-----------------|---------------|-----------|
| Sort-based key  | O(n · k log k)| O(n · k)  |
| Frequency key   | O(n · k)      | O(n · k)  |

*n = number of strings, k = max string length*

---

## Interview Tips

- **Sorting approach is easier to code** and usually sufficient. Mention the frequency approach as an optimisation.
- **Key insight:** All anagrams share the same sorted representation — that's the hash map key.
- **Edge cases:** Empty string (groups with other empty strings), single-character strings.
- **Common mistake:** Using `string.Sort()` — doesn't exist. Use `char[] + Array.Sort + new string(chars)`.
- **Follow-up:** *"How would you handle Unicode characters (beyond 26 letters)?"* → Use `Dictionary<char,int>` for the frequency map instead of a fixed array.
