# Longest Increasing Subsequence (LIS)

**Source:** LeetCode #300
**Difficulty:** 🟡 Medium
**Topics:** Array, Binary Search, Dynamic Programming

## Problem Statement

Given an integer array `nums`, return the length of the **longest strictly increasing subsequence**.

## Examples

```
Input: nums = [10,9,2,5,3,7,101,18]   Output: 4   // [2,3,7,101]
Input: nums = [0,1,0,3,2,3]   Output: 4
Input: nums = [7,7,7,7]   Output: 1
```

## Constraints

- `1 <= nums.Length <= 2500`; `-10⁴ <= nums[i] <= 10⁴`

---

## Approach 1: DP — O(n²) time, O(n) space

`dp[i]` = length of LIS ending at index `i`. For each `j < i`, if `nums[j] < nums[i]`, update `dp[i] = max(dp[i], dp[j] + 1)`.

```csharp
public static int LengthOfLIS_DP(int[] nums)
{
    int n = nums.Length;
    var dp = new int[n];
    Array.Fill(dp, 1);
    int best = 1;

    for (int i = 1; i < n; i++)
    {
        for (int j = 0; j < i; j++)
            if (nums[j] < nums[i])
                dp[i] = Math.Max(dp[i], dp[j] + 1);
        best = Math.Max(best, dp[i]);
    }
    return best;
}
```

---

## Approach 2: Binary Search (Patience Sorting) — O(n log n) time, O(n) space ✓

Maintain a `tails` array where `tails[i]` = smallest tail element of all IS of length `i+1`. Binary search to find the insertion point for each number.

```csharp
public static int LengthOfLIS(int[] nums)
{
    var tails = new List<int>();

    foreach (int num in nums)
    {
        // Find leftmost index where tails[idx] >= num
        int lo = 0, hi = tails.Count;
        while (lo < hi)
        {
            int mid = lo + (hi - lo) / 2;
            if (tails[mid] < num) lo = mid + 1;
            else hi = mid;
        }

        if (lo == tails.Count) tails.Add(num);  // extend LIS
        else tails[lo] = num;                   // replace with smaller tail
    }
    return tails.Count;
}
```

### Walkthrough: `[10,9,2,5,3,7,101,18]`

```
10  → tails=[10]
9   → tails=[9]      // replace 10
2   → tails=[2]      // replace 9
5   → tails=[2,5]    // extend
3   → tails=[2,3]    // replace 5
7   → tails=[2,3,7]  // extend
101 → tails=[2,3,7,101]  // extend → LIS length = 4
18  → tails=[2,3,7,18]   // replace 101
```

---

## Complexity Summary

| Approach         | Time     | Space |
|------------------|----------|-------|
| DP               | O(n²)    | O(n)  |
| Binary Search    | O(n log n)| O(n) |

---

## Interview Tips

- `tails` doesn't store the actual LIS — just its **length** and the optimal tails for reconstruction.
- **To reconstruct** the actual sequence: add a `parent` array tracking where each element came from (use DP approach).
- `Array.BinarySearch` can replace the manual loop: returns `~insertionPoint` for not found.
