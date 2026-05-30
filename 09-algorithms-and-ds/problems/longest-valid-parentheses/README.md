# Longest Valid Parentheses

**Source:** LeetCode #32
**Difficulty:** 🔴 Hard
**Topics:** String, Stack, Dynamic Programming

## Problem Statement

Given a string containing only `'('` and `')'`, return the length of the **longest valid (well-formed) parentheses substring**.

## Examples

```
Input: s = "(()"      Output: 2   // "()"
Input: s = ")()())"   Output: 4   // "()()"
Input: s = ""         Output: 0
```

## Constraints

- `0 <= s.Length <= 3 × 10⁴`

---

## Approach 1: Stack — O(n) time, O(n) space ✓

Keep a stack of **indices**. Push `-1` as a base index. On `'('`, push index. On `')'`, pop; if stack is empty, push current index as new base; else update max with `i - stack.Peek()`.

```csharp
public static int LongestValidParentheses(string s)
{
    var stack = new Stack<int>();
    stack.Push(-1); // base index
    int maxLen = 0;

    for (int i = 0; i < s.Length; i++)
    {
        if (s[i] == '(')
        {
            stack.Push(i);
        }
        else
        {
            stack.Pop(); // try to match
            if (stack.Count == 0)
                stack.Push(i); // new base: unmatched ')'
            else
                maxLen = Math.Max(maxLen, i - stack.Peek());
        }
    }
    return maxLen;
}
```

---

## Approach 2: Two Counters (O(1) space) — O(n) time, O(1) space

Left-to-right pass counting `(` and `)`. When counts match → valid substring. When `)` > `(`, reset. Do the same right-to-left to handle unclosed `(`.

```csharp
public static int LongestValidParenthesesOpt(string s)
{
    int left = 0, right = 0, maxLen = 0;
    foreach (char c in s)
    {
        if (c == '(') left++; else right++;
        if (left == right) maxLen = Math.Max(maxLen, 2 * right);
        else if (right > left) { left = right = 0; }
    }

    left = right = 0;
    for (int i = s.Length - 1; i >= 0; i--)
    {
        if (s[i] == '(') left++; else right++;
        if (left == right) maxLen = Math.Max(maxLen, 2 * left);
        else if (left > right) { left = right = 0; }
    }
    return maxLen;
}
```

---

## Complexity Summary

| Approach      | Time | Space |
|---------------|------|-------|
| Stack         | O(n) | O(n)  |
| Two Counters  | O(n) | O(1)  |

---

## Interview Tips

- **Stack approach** is easier to explain; **two-counter** is O(1) space for a bonus.
- Key insight in stack approach: the stack always has the "last unmatched ')' index" at the bottom as a boundary.
- **Common mistake:** forgetting to push `-1` as the initial base, causing an empty-stack edge case.
