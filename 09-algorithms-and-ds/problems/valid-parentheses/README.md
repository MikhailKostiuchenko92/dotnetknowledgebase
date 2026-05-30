# Valid Parentheses

**Source:** LeetCode #20
**Difficulty:** 🟢 Easy
**Topics:** String, Stack

## Problem Statement

Given a string `s` containing just the characters `'('`, `')'`, `'{'`, `'}'`, `'['` and `']'`, determine if the input string is **valid**.

A string is valid if:
1. Every open bracket is closed by the same type of bracket.
2. Open brackets are closed in the correct order.
3. Every close bracket has a corresponding open bracket.

## Examples

```
Input:  s = "()"
Output: true

Input:  s = "()[]{}"
Output: true

Input:  s = "(]"
Output: false

Input:  s = "([)]"
Output: false

Input:  s = "{[]}"
Output: true
```

## Constraints

- `1 <= s.Length <= 10⁴`
- `s` consists of parentheses only: `'()[]{}'`.

---

## Approach: Stack — O(n) time, O(n) space ✓

Push open brackets onto the stack. When a closing bracket is encountered, check if it matches the top of the stack.

```csharp
public static bool IsValid(string s)
{
    var stack = new Stack<char>();
    var matching = new Dictionary<char, char>
    {
        [')'] = '(',
        [']'] = '[',
        ['}'] = '{'
    };

    foreach (char c in s)
    {
        if (!matching.ContainsKey(c))
        {
            stack.Push(c); // it's an open bracket
        }
        else
        {
            // It's a closing bracket — check the stack top
            if (stack.Count == 0 || stack.Pop() != matching[c])
                return false;
        }
    }

    return stack.Count == 0; // all open brackets must be matched
}
```

---

## Alternative: Switch Expression (C# 8+)

```csharp
public static bool IsValidSwitch(string s)
{
    var stack = new Stack<char>();
    foreach (char c in s)
    {
        switch (c)
        {
            case '(' or '[' or '{':
                stack.Push(c);
                break;
            case ')' when stack.Count > 0 && stack.Peek() == '(':
            case ']' when stack.Count > 0 && stack.Peek() == '[':
            case '}' when stack.Count > 0 && stack.Peek() == '{':
                stack.Pop();
                break;
            default:
                return false; // mismatched or empty stack
        }
    }
    return stack.Count == 0;
}
```

---

## Complexity Summary

| Approach | Time | Space |
|----------|------|-------|
| Stack    | O(n) | O(n)  |

---

## Interview Tips

- **Explain the invariant:** *"The stack at any point holds the unmatched open brackets in the order they appeared."*
- **Check stack count before popping** — an empty stack when encountering a closing bracket means invalid.
- **Final check:** `stack.Count == 0` — if any open brackets remain unmatched, the string is invalid.
- **Edge cases:** Empty string (valid), string of only open brackets, string of only close brackets, odd-length string (always invalid).
- **Common mistake:** Forgetting the `stack.Count == 0` final check — `"((("` would incorrectly return `true`.
- **Follow-up:** *"Minimum number of removals to make valid."* → LeetCode #1249 — track unmatched opens and closes.
