# Missing Number

**Source:** LeetCode #268
**Difficulty:** 🟢 Easy
**Topics:** Bit Manipulation, Math, Array

## Problem Statement

Given an array `nums` containing `n` distinct numbers in the range `[0, n]`, return the one number that is missing.

## Examples

```
Input: nums = [3,0,1]   Output: 2
Input: nums = [0,1]     Output: 2
Input: nums = [9,6,4,2,3,5,7,0,1]   Output: 8
```

## Constraints

- `n == nums.Length`; `0 <= nums[i] <= n`; all numbers distinct.

---

## Approach 1: Gauss Formula — O(n) time, O(1) space ✓

Expected sum = `n*(n+1)/2`. Missing = expected - actual.

```csharp
public static int MissingNumber(int[] nums)
    => nums.Length * (nums.Length + 1) / 2 - nums.Sum();
```

## Approach 2: XOR — O(n) time, O(1) space

XOR `0..n` with all elements; duplicates cancel, leaving the missing number.

```csharp
public static int MissingNumberXOR(int[] nums)
{
    int result = nums.Length;
    for (int i = 0; i < nums.Length; i++)
        result ^= i ^ nums[i];
    return result;
}
```

---

## Complexity Summary

| Approach      | Time | Space |
|---------------|------|-------|
| Gauss formula | O(n) | O(1)  |
| XOR           | O(n) | O(1)  |

---

## Interview Tips

- Both approaches are O(n) time, O(1) space — know both.
- Gauss is simpler to explain verbally; XOR demonstrates bit-manipulation fluency.
- **Overflow concern:** `n*(n+1)/2` — for `n = 10⁴`, max = ~50M, fits in `int`. Use `long` if unsure.
