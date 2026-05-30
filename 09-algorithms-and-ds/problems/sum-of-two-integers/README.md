# Sum of Two Integers (Without + Operator)

**Source:** LeetCode #371
**Difficulty:** 🟡 Medium
**Topics:** Bit Manipulation, Math

## Problem Statement

Given two integers `a` and `b`, return their sum without using `+` or `-`.

## Examples

```
Input: a = 1, b = 2   Output: 3
Input: a = 2, b = 3   Output: 5
```

## Constraints

- `-1000 <= a, b <= 1000`

---

## Approach: XOR + Carry — O(log max(|a|, |b|)) time, O(1) space ✓

- **XOR** computes the sum without carry: `a ^ b`
- **AND** + left shift computes the carry: `(a & b) << 1`
- Repeat until no carry remains.

```csharp
public static int GetSum(int a, int b)
{
    while (b != 0)
    {
        int carry = (a & b) << 1; // carry bits
        a ^= b;                   // sum without carry
        b = carry;
    }
    return a;
}
```

### Walkthrough: `a=3 (011), b=5 (101)`

```
Round 1: carry = (011 & 101) << 1 = 001 << 1 = 010
         a = 011 ^ 101 = 110 (6)
         b = 010 (2)
Round 2: carry = (110 & 010) << 1 = 010 << 1 = 100
         a = 110 ^ 010 = 100 (4)
         b = 100 (4)
Round 3: carry = (100 & 100) << 1 = 100 << 1 = 1000
         a = 100 ^ 100 = 000 (0)
         b = 1000 (8) ← Wait, original was 3+5=8 ✓
```

---

## Complexity Summary

| Approach  | Time              | Space |
|-----------|-------------------|-------|
| XOR carry | O(log max(a,b))   | O(1)  |

---

## Interview Tips

- This is more of a bitwise-addition explanation than a practical coding problem — the interviewer wants to see you understand carry propagation.
- **In C#**, beware of infinite loops with negative numbers due to signed integer arithmetic; the loop terminates because the carry eventually becomes 0.
