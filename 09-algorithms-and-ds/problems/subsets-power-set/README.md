# Subsets / Power Set

**Source:** LeetCode #78
**Difficulty:** 🟡 Medium
**Topics:** Array, Backtracking, Bit Manipulation

## Problem Statement

Given an integer array `nums` of unique elements, return all possible subsets (the power set). The solution set must not contain duplicate subsets.

## Examples

```
Input: nums = [1,2,3]
Output: [[],[1],[2],[1,2],[3],[1,3],[2,3],[1,2,3]]
```

## Constraints

- `1 <= nums.Length <= 10`; `-10 <= nums[i] <= 10`; all elements unique.

---

## Approach 1: Backtracking — O(n · 2ⁿ) time, O(n) space ✓

At each position, choose to include or exclude. Add the current state to results at every node (not just leaves).

```csharp
public static IList<IList<int>> Subsets(int[] nums)
{
    var result  = new List<IList<int>>();
    var current = new List<int>();

    void Backtrack(int start)
    {
        result.Add([..current]); // add at every step (not just leaves)
        for (int i = start; i < nums.Length; i++)
        {
            current.Add(nums[i]);
            Backtrack(i + 1);
            current.RemoveAt(current.Count - 1);
        }
    }

    Backtrack(0);
    return result;
}
```

---

## Approach 2: Bitmask — O(n · 2ⁿ) time, O(n · 2ⁿ) space

Each number from `0` to `2ⁿ - 1` represents a subset via set bits.

```csharp
public static IList<IList<int>> SubsetsBitmask(int[] nums)
{
    int n = nums.Length;
    var result = new List<IList<int>>();

    for (int mask = 0; mask < (1 << n); mask++)
    {
        var subset = new List<int>();
        for (int i = 0; i < n; i++)
            if ((mask >> i & 1) == 1) subset.Add(nums[i]);
        result.Add(subset);
    }
    return result;
}
```

---

## Complexity Summary

| Approach    | Time      | Space     |
|-------------|-----------|-----------|
| Backtracking| O(n · 2ⁿ) | O(n)      |
| Bitmask     | O(n · 2ⁿ) | O(n · 2ⁿ) |

---

## Interview Tips

- **Add `current` at every step** (not just when `start == nums.Length`) — this is the difference between Subsets and Combination Sum.
- Bitmask is elegant for small `n` (≤ 20).
- **Follow-up:** [Subsets II](https://leetcode.com/problems/subsets-ii/) — with duplicates → sort first, skip when `i > start && nums[i] == nums[i-1]`.
