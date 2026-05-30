# Reverse Bits

**Source:** LeetCode #190
**Difficulty:** 🟢 Easy
**Topics:** Bit Manipulation, Divide and Conquer

## Problem Statement

Reverse the bits of a given 32-bit unsigned integer.

## Examples

```
Input:  n = 43261596  (00000010100101000001111010011100)
Output: 964176192     (00111001011110000010100101000000)
```

## Constraints

- Input is a 32-bit unsigned integer.

---

## Approach: Bit-by-Bit — O(1) time (32 iterations), O(1) space ✓

```csharp
public static uint ReverseBits(uint n)
{
    uint result = 0;
    for (int i = 0; i < 32; i++)
    {
        result = (result << 1) | (n & 1);
        n >>= 1;
    }
    return result;
}
```

---

## Approach 2: Divide and Conquer with Masks (O(1) via bit tricks)

```csharp
public static uint ReverseBitsOptimal(uint n)
{
    n = (n >> 16) | (n << 16);
    n = ((n & 0xFF00FF00u) >> 8) | ((n & 0x00FF00FFu) << 8);
    n = ((n & 0xF0F0F0F0u) >> 4) | ((n & 0x0F0F0F0Fu) << 4);
    n = ((n & 0xCCCCCCCCu) >> 2) | ((n & 0x33333333u) << 2);
    n = ((n & 0xAAAAAAAAu) >> 1) | ((n & 0x55555555u) << 1);
    return n;
}
```

---

## Complexity Summary

| Approach        | Time | Space |
|-----------------|------|-------|
| Bit-by-bit      | O(1) | O(1)  |
| Mask swapping   | O(1) | O(1)  |

---

## Interview Tips

- **Bit-by-bit** is the most readable — mention the 32-iteration upper bound is O(1).
- The mask-swapping approach reverses in 5 passes using word-level operations — worth explaining if the interviewer asks for optimisation.
- **`uint` in C#** — use unsigned right shift `>>` (no sign extension). For `int`, prefer `>>> ` (C# 11 unsigned right shift operator).
