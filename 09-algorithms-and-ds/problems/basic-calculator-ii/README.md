# Basic Calculator II

**Source:** LeetCode #227
**Difficulty:** 🔴 Hard
**Topics:** String, Stack, Math

## Problem Statement

Given a string `s` representing a valid arithmetic expression, implement a basic calculator to evaluate it and return the **result**.

The expression contains only non-negative integers, `+`, `-`, `*`, `/` operators, and empty spaces. Integer division should **truncate toward zero**.

## Examples

```
Input:  s = "3+2*2"
Output: 7

Input:  s = " 3/2 "
Output: 1

Input:  s = " 3+5 / 2 "
Output: 5
```

## Constraints

- `1 <= s.Length <= 3 × 10⁵`
- `s` consists of digits, `+`, `-`, `*`, `/`, and spaces.
- `s` represents a valid expression.
- All intermediate values fit in a 32-bit integer.

---

## Approach: Stack with Pending Operator — O(n) time, O(n) space ✓

Process numbers and operators left to right. Use a stack to handle precedence:
- For `+`/`-`: push the signed number (defer addition until flush).
- For `*`/`/`: immediately compute with the stack top (higher precedence).

At the end, sum all values in the stack.

```csharp
public static int Calculate(string s)
{
    var stack = new Stack<int>();
    int num = 0;
    char op = '+'; // pending operator (start as '+' to push first number)

    for (int i = 0; i < s.Length; i++)
    {
        char c = s[i];

        if (char.IsDigit(c))
            num = num * 10 + (c - '0');

        // Process when we hit an operator or end of string
        if ((c is '+' or '-' or '*' or '/') || i == s.Length - 1)
        {
            switch (op)
            {
                case '+': stack.Push(num);         break;
                case '-': stack.Push(-num);        break;
                case '*': stack.Push(stack.Pop() * num); break;
                case '/': stack.Push(stack.Pop() / num); break;
            }
            op = c;   // save current operator for the next number
            num = 0;  // reset number
        }
    }

    // Sum everything in the stack (all deferred +/- additions)
    int result = 0;
    while (stack.Count > 0) result += stack.Pop();
    return result;
}
```

### Key Insight

By pushing deferred additions/subtractions onto the stack, we handle `*` and `/` first (immediately) without needing explicit precedence parsing. The final stack sum collects all the `+/-` contributions.

### Walkthrough: `"3+2*2"`

```
c='3': num=3
c='+': op='+' → push(3). op='+', num=0
c='2': num=2
c='*': op='+' → push(2). op='*', num=0
c='2': num=2
end:   op='*' → push(pop()*2=2*2=4)
stack=[3,4] → 3+4=7 ✓
```

---

## Complexity Summary

| Approach                  | Time | Space |
|---------------------------|------|-------|
| Stack + pending operator  | O(n) | O(n)  |

---

## Interview Tips

- **Initialize `op = '+'`** — this ensures the first number is pushed with a `+` sign without special-casing.
- Process on operator or end-of-string: the condition `|| i == s.Length - 1` handles the last number.
- **Multi-digit numbers:** `num = num * 10 + (c - '0')` — important to handle correctly.
- **Spaces:** `char.IsDigit` and operator checks naturally skip spaces.
- **Follow-up:** *"Handle parentheses."* → LeetCode #224 (Basic Calculator) — requires recursion or additional stack.
