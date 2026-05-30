# Single Number

**Source:** LeetCode #136
**Difficulty:** 🟢 Easy
**Topics:** Bit Manipulation, Array

## Problem Statement

Given a non-empty array of integers `nums`, every element appears **twice** except for one. Find that single element. Must run in O(n) time and O(1) extra space.

## Examples

```
Input: nums = [2,2,1]   Output: 1
Input: nums = [4,1,2,1,2]   Output: 4
```

## Constraints

- `1 <= nums.Length <= 3 × 10⁴`; `-3 × 10⁴ <= nums[i] <= 3 × 10⁴`; exactly one single element.

---

## Approach: XOR — O(n) time, O(1) space ✓

`a ^ a = 0` and `a ^ 0 = a`. XOR-ing all elements cancels duplicates.

```csharp
public static int SingleNumber(int[] nums)
    => nums.Aggregate(0, (acc, n) => acc ^ n);
```

---

## Complexity Summary

| Approach | Time | Space |
|----------|------|-------|
| XOR      | O(n) | O(1)  |

---

## Interview Tips

- This is the quintessential XOR problem — state the insight (`a ^ a = 0`) immediately.
- **Follow-up:** *"Every element appears three times except one."* → LeetCode #137 — bit counting modulo 3.
- **Follow-up:** *"Two elements appear once."* → LeetCode #260 — XOR to find `a ^ b`, then find differing bit to split.
