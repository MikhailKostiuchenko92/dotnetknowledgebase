# Evaluate Reverse Polish Notation

**Source:** LeetCode #150
**Difficulty:** 🟡 Medium
**Topics:** Array, Stack, Math

## Problem Statement

Evaluate the value of an arithmetic expression in **Reverse Polish Notation** (RPN / postfix notation).

Valid operators are `+`, `-`, `*`, `/`. Each operand may be an integer or another expression. **Division truncates toward zero.**

## Examples

```
Input:  tokens = ["2","1","+","3","*"]
Output: 9   // ((2 + 1) * 3) = 9

Input:  tokens = ["4","13","5","/","+"]
Output: 6   // (4 + (13 / 5)) = 4 + 2 = 6

Input:  tokens = ["10","6","9","3","+","-11","*","/","*","17","+","5","+"]
Output: 22
```

## Constraints

- `1 <= tokens.Length <= 10⁴`
- `tokens[i]` is either an operator `+`, `-`, `*`, `/`, or an integer in `[-200, 200]`.
- The input is always a valid RPN expression.
- The result and intermediate values fit in a 32-bit integer.

---

## Approach: Stack — O(n) time, O(n) space ✓

Process each token left to right:
- If a **number**, push onto the stack.
- If an **operator**, pop two operands, apply the operator, push the result.

```csharp
public static int EvalRPN(string[] tokens)
{
    var stack = new Stack<int>();

    foreach (string token in tokens)
    {
        if (token is "+" or "-" or "*" or "/")
        {
            int b = stack.Pop(); // second operand (top)
            int a = stack.Pop(); // first operand
            stack.Push(token switch
            {
                "+" => a + b,
                "-" => a - b,
                "*" => a * b,
                "/" => a / b, // C# int division truncates toward zero ✓
                _   => throw new InvalidOperationException($"Unknown operator: {token}")
            });
        }
        else
        {
            stack.Push(int.Parse(token));
        }
    }

    return stack.Pop();
}
```

> **Order of operands matters for `-` and `/`:**  
> Pop `b` first (it was pushed last → it's the right operand), then `a` (left operand).  
> `a / b` not `b / a`.

---

## Why RPN and stacks go together

RPN was specifically designed to be evaluated with a stack — no parentheses or operator precedence rules needed. Compilers often generate code that evaluates expressions in this form. The stack depth is bounded by the maximum nesting depth.

---

## Complexity Summary

| Approach | Time | Space |
|----------|------|-------|
| Stack    | O(n) | O(n)  |

---

## Interview Tips

- **Operand order:** When you pop from the stack, the top is the *right* operand for the operation. State this explicitly.
- C#'s integer division truncates toward zero (e.g., `-7/2 = -3`), matching the problem requirement.
- **Edge cases:** Negative numbers in tokens (e.g., `"-11"`), single number expression, deeply nested expressions.
- **Common mistake:** Popping `a` first and `b` second — results in `b op a` instead of `a op b` for non-commutative operators.
- **Follow-up:** *"Convert infix expression to RPN."* → Shunting-yard algorithm using a stack and an operator precedence map.
