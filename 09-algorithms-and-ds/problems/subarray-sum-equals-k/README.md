# Subarray Sum Equals K

**Source:** LeetCode #560
**Difficulty:** 🟡 Medium
**Topics:** Array, HashMap, Prefix Sum

## Problem Statement

Given an array of integers `nums` and an integer `k`, return the **total number of subarrays** whose sum equals `k`.

## Examples

```
Input:  nums = [1, 1, 1], k = 2
Output: 2   // [1,1] at indices [0,1] and [1,2]

Input:  nums = [1, 2, 3], k = 3
Output: 2   // [3] at index 2, [1,2] at indices [0,1]

Input:  nums = [-1, -1, 1], k = 0
Output: 1   // [-1,-1,1] sums to -1; [-1,1] sums to 0 ✓
```

## Constraints

- `1 <= nums.Length <= 2 × 10⁴`
- `-1000 <= nums[i] <= 1000`
- `-10⁷ <= k <= 10⁷`

---

## Approach 1: Brute Force — O(n²) time, O(1) space

Compute all subarray sums directly.

```csharp
public static int SubarraySum_Brute(int[] nums, int k)
{
    int count = 0;
    for (int i = 0; i < nums.Length; i++)
    {
        int sum = 0;
        for (int j = i; j < nums.Length; j++)
        {
            sum += nums[j];
            if (sum == k) count++;
        }
    }
    return count;
}
```

---

## Approach 2: Prefix Sum + HashMap — O(n) time, O(n) space ✓

### Key Insight

`sum(i..j) = prefixSum[j+1] - prefixSum[i]`. We want this to equal `k`.  
Rearranging: we need `prefixSum[j+1] - k` to have appeared before index `j+1` in the prefix sums.

Store `prefixSum → count` in a map. For each new prefix sum, look up how many times `prefixSum - k` has appeared.

```csharp
public static int SubarraySum(int[] nums, int k)
{
    var prefixCounts = new Dictionary<int, int>();
    prefixCounts[0] = 1; // empty prefix has sum 0

    int runningSum = 0, count = 0;

    foreach (int n in nums)
    {
        runningSum += n;

        // How many prior prefixes had sum = runningSum - k?
        if (prefixCounts.TryGetValue(runningSum - k, out int times))
            count += times;

        prefixCounts[runningSum] = prefixCounts.GetValueOrDefault(runningSum) + 1;
    }

    return count;
}
```

### Why initialise `prefixCounts[0] = 1`?

The subarray starting at index 0 has prefix sum = `runningSum - 0 = k` when `runningSum == k`. Without the initial `0 → 1` entry, we'd miss subarrays that start from the beginning of the array.

> **Important:** This approach works with negative numbers because it doesn't use a two-pointer/sliding-window (those require non-negative values for correctness).

---

## Complexity Summary

| Approach         | Time  | Space |
|------------------|-------|-------|
| Brute Force      | O(n²) | O(1)  |
| Prefix Sum + Map | O(n)  | O(n)  |

---

## Interview Tips

- **This requires prefix sums — sliding window doesn't work because values can be negative.** State this explicitly.
- Explain the `prefixCounts[0] = 1` initialisation — interviewers often ask about it.
- **Common mistake:** Forgetting to handle negative numbers (ruling out two-pointer) and the empty prefix base case.
- **Edge cases:** All zeros (`nums = [0,0,0], k = 0` → 6 subarrays), negative numbers, `k = 0`.
- **Follow-up:** *"Return the indices of one such subarray."* → Store `prefixSum → index` instead of a count, reconstruct on match.
- **Follow-up:** *"Maximum subarray sum equals k."* → Requires careful adaptation of the prefix sum map.
