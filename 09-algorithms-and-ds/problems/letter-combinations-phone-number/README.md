# Letter Combinations of a Phone Number

**Source:** LeetCode #17
**Difficulty:** 🟡 Medium
**Topics:** String, Backtracking, HashMap

## Problem Statement

Given a string containing digits `2–9`, return all possible letter combinations the number could represent on a phone keypad. Return an empty list for empty input.

```
2→abc, 3→def, 4→ghi, 5→jkl, 6→mno, 7→pqrs, 8→tuv, 9→wxyz
```

## Examples

```
Input: digits = "23"   Output: ["ad","ae","af","bd","be","bf","cd","ce","cf"]
Input: digits = ""     Output: []
```

## Constraints

- `0 <= digits.Length <= 4`; each digit is in `[2-9]`.

---

## Approach: Backtracking — O(4ⁿ · n) time, O(n) space ✓

```csharp
public static IList<string> LetterCombinations(string digits)
{
    if (digits.Length == 0) return [];
    string[] map = ["", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"];

    var result = new List<string>();
    var sb     = new System.Text.StringBuilder();

    void Backtrack(int index)
    {
        if (index == digits.Length) { result.Add(sb.ToString()); return; }
        foreach (char c in map[digits[index] - '0'])
        {
            sb.Append(c);
            Backtrack(index + 1);
            sb.Length--;
        }
    }

    Backtrack(0);
    return result;
}
```

---

## Complexity Summary

| Approach     | Time      | Space |
|--------------|-----------|-------|
| Backtracking | O(4ⁿ · n) | O(n)  |

---

## Interview Tips

- Each digit maps to at most 4 letters (7 and 9 have 4); total combinations ≤ 4⁴ = 256 for n=4.
- Using `StringBuilder` + `sb.Length--` is more efficient than `string` concatenation.
