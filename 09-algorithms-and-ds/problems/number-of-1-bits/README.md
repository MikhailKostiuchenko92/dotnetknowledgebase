# Number of 1 Bits (Hamming Weight)

**Source:** LeetCode #191
**Difficulty:** 🟢 Easy
**Topics:** Bit Manipulation

## Problem Statement

Write a function that takes an unsigned integer and returns the number of `'1'` bits it has (also known as the Hamming weight).

## Examples

```
Input: n = 11 (0b1011)   Output: 3
Input: n = 128 (0b10000000)   Output: 1
```

## Constraints

- Input is a 32-bit unsigned integer.

---

## Approach 1: Brian Kernighan's Trick — O(k) time where k = number of set bits ✓

`n & (n-1)` clears the lowest set bit. Count how many times until `n == 0`.

```csharp
public static int HammingWeight(uint n)
{
    int count = 0;
    while (n != 0) { n &= n - 1; count++; }
    return count;
}
```

## Approach 2: `BitOperations.PopCount` (.NET 5+) — O(1)

```csharp
public static int HammingWeightBuiltin(uint n)
    => System.Numerics.BitOperations.PopCount(n);
```

---

## Complexity Summary

| Approach           | Time | Space |
|--------------------|------|-------|
| Kernighan's trick  | O(k) | O(1)  |
| `BitOperations`    | O(1) | O(1)  |

---

## Interview Tips

- `n & (n-1)` clears the **lowest** set bit — explain why: subtracting 1 flips all bits from the lowest `1` downward.
- In production C# code, prefer `BitOperations.PopCount` — it compiles to a single POPCNT instruction on x86.
- **Related:** [Reverse Bits](../reverse-bits/README.md), [Missing Number](../missing-number/README.md).
