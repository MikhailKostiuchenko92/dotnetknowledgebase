# Maximum Product Subarray

**Source:** LeetCode #152
**Difficulty:** 🟡 Medium
**Topics:** Array, Dynamic Programming

## Problem Statement

Given an integer array `nums`, find a contiguous subarray with the largest product and return the product.

## Examples

```
Input: nums = [2,3,-2,4]   Output: 6   // [2,3]
Input: nums = [-2,0,-1]    Output: 0   // [0]
Input: nums = [-2,3,-4]    Output: 24  // [-2,3,-4]
```

## Constraints

- `1 <= nums.Length <= 2 × 10⁴`; `-10 <= nums[i] <= 10`; product fits in 32-bit int.

---

## Approach: Track Min & Max — O(n) time, O(1) space ✓

A negative × negative = positive. Track both the **max** and **min** product ending at each position. At each step swap min/max when multiplying by a negative.

```csharp
public static int MaxProduct(int[] nums)
{
    int maxProd = nums[0], minProd = nums[0], result = nums[0];

    for (int i = 1; i < nums.Length; i++)
    {
        // When multiplying by negative, max and min swap roles
        if (nums[i] < 0) (maxProd, minProd) = (minProd, maxProd);

        maxProd = Math.Max(nums[i], maxProd * nums[i]);
        minProd = Math.Min(nums[i], minProd * nums[i]);
        result  = Math.Max(result, maxProd);
    }
    return result;
}
```

---

## Complexity Summary

| Approach          | Time | Space |
|-------------------|------|-------|
| DP (min+max)      | O(n) | O(1)  |

---

## Interview Tips

- The trick: **keep track of both the running max and min** because multiplying by a negative flips them.
- Zeros reset both `maxProd` and `minProd` to the current element (handled by `Math.Max(nums[i], ...)` — starting fresh).
- **Related:** [Best Time to Buy and Sell Stock](../best-time-to-buy-and-sell-stock/README.md) (similar "reset on bad event" idea), [Maximum Subarray Sum (Kadane's)](../find-maximum-element/README.md).
