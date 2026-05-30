# Permutations

**Source:** LeetCode #46
**Difficulty:** 🟡 Medium
**Topics:** Array, Backtracking

## Problem Statement

Given an array `nums` of distinct integers, return all possible permutations in any order.

## Examples

```
Input: nums = [1,2,3]
Output: [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
```

## Constraints

- `1 <= nums.Length <= 6`; all integers are unique; `-10 <= nums[i] <= 10`

---

## Approach 1: Backtracking with Used Array — O(n! · n) time, O(n) space

```csharp
public static IList<IList<int>> Permute(int[] nums)
{
    var result = new List<IList<int>>();
    var current = new List<int>();
    var used    = new bool[nums.Length];

    void Backtrack()
    {
        if (current.Count == nums.Length) { result.Add([..current]); return; }
        for (int i = 0; i < nums.Length; i++)
        {
            if (used[i]) continue;
            used[i] = true;
            current.Add(nums[i]);
            Backtrack();
            current.RemoveAt(current.Count - 1);
            used[i] = false;
        }
    }

    Backtrack();
    return result;
}
```

---

## Approach 2: Swap-Based — O(n! · n) time, O(n) space (in-place)

```csharp
public static IList<IList<int>> PermuteSwap(int[] nums)
{
    var result = new List<IList<int>>();

    void Backtrack(int start)
    {
        if (start == nums.Length) { result.Add((int[])nums.Clone()); return; }
        for (int i = start; i < nums.Length; i++)
        {
            (nums[start], nums[i]) = (nums[i], nums[start]);
            Backtrack(start + 1);
            (nums[start], nums[i]) = (nums[i], nums[start]); // undo swap
        }
    }

    Backtrack(0);
    return result;
}
```

---

## Complexity Summary

| Approach          | Time      | Space |
|-------------------|-----------|-------|
| Used-array        | O(n! · n) | O(n)  |
| Swap-based        | O(n! · n) | O(n)  |

---

## Interview Tips

- **Swap-based** is O(1) extra space (no used array), operates in-place.
- Always undo the swap after recursion (the "restore" step of backtracking).
- **Follow-up:** [Permutations II](https://leetcode.com/problems/permutations-ii/) — duplicates allowed → sort first, skip duplicate choices.
