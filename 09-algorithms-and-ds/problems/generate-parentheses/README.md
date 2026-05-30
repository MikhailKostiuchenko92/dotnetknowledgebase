# Generate Parentheses

**Source:** LeetCode #22
**Difficulty:** 🟡 Medium
**Topics:** String, Backtracking, Dynamic Programming

## Problem Statement

Given `n` pairs of parentheses, generate all combinations of **well-formed** parentheses.

## Examples

```
Input: n = 3
Output: ["((()))","(()())","(())()","()(())","()()()"]
```

## Constraints

- `1 <= n <= 8`

---

## Approach: Backtracking — O(4ⁿ / √n) time, O(n) space ✓

The n-th Catalan number counts valid combinations. Track `open` and `close` counts; only add `'('` if `open < n`, only `')'` if `close < open`.

```csharp
public static IList<string> GenerateParenthesis(int n)
{
    var result = new List<string>();
    var sb     = new System.Text.StringBuilder();

    void Backtrack(int open, int close)
    {
        if (sb.Length == 2 * n) { result.Add(sb.ToString()); return; }
        if (open < n)          { sb.Append('('); Backtrack(open + 1, close); sb.Length--; }
        if (close < open)      { sb.Append(')'); Backtrack(open, close + 1); sb.Length--; }
    }

    Backtrack(0, 0);
    return result;
}
```

---

## Complexity Summary

| Approach     | Time        | Space |
|--------------|-------------|-------|
| Backtracking | O(4ⁿ / √n)  | O(n)  |

---

## Interview Tips

- The invariant `close < open` ensures we never close more than we've opened — the key correctness constraint.
- Total valid sequences = C(2n, n) / (n+1) (n-th Catalan number).
- Clean, simple backtracking — a go-to example for interview explanations.
