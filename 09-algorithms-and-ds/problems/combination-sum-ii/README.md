# Combination Sum II

**Source:** LeetCode #40
**Difficulty:** 🟡 Medium
**Topics:** Array, Backtracking

## Problem Statement

Given a collection of candidate numbers `candidates` (may contain duplicates) and a target integer `target`, find all unique combinations where the chosen numbers sum to `target`. Each candidate may only be used **once** in a combination.

## Examples

```
Input: candidates = [10,1,2,7,6,1,5], target = 8
Output: [[1,1,6],[1,2,5],[1,7],[2,6]]

Input: candidates = [2,5,2,1,2], target = 5
Output: [[1,2,2],[5]]
```

## Constraints

- `1 <= candidates.Length <= 100`; `1 <= candidates[i] <= 50`; `1 <= target <= 30`.

---

## Approach: Backtracking + Skip Duplicates — O(2ⁿ) time, O(n) space ✓

Sort the array. At each recursion level, skip candidates equal to the previous one at the **same level** (not if it was used in a deeper call).

```csharp
public static IList<IList<int>> CombinationSum2(int[] candidates, int target)
{
    Array.Sort(candidates);
    var result  = new List<IList<int>>();
    var current = new List<int>();

    void Backtrack(int start, int remaining)
    {
        if (remaining == 0) { result.Add([..current]); return; }

        for (int i = start; i < candidates.Length; i++)
        {
            if (candidates[i] > remaining) break; // pruning

            // Skip duplicate at the same decision level
            if (i > start && candidates[i] == candidates[i-1]) continue;

            current.Add(candidates[i]);
            Backtrack(i + 1, remaining - candidates[i]); // i+1: no reuse
            current.RemoveAt(current.Count - 1);
        }
    }

    Backtrack(0, target);
    return result;
}
```

### Why `i > start` and not `i > 0`?

`i > 0` would skip a number even if it's the first choice in the current call — which is wrong. `i > start` only skips duplicates that are **additional choices at the same level**.

```
candidates = [1,1,2], target = 3
  Level 0, i=0: pick candidates[0]=1  → explore [1,...]
  Level 0, i=1: candidates[1]==candidates[0] AND i>start → SKIP  ✓ (avoids [1,2] twice)
```

---

## Complexity Summary

| Approach              | Time  | Space |
|-----------------------|-------|-------|
| Backtracking + dedup  | O(2ⁿ) | O(n)  |

---

## Interview Tips

- **Sort first** — necessary to enable the `candidates[i] == candidates[i-1]` dedup check.
- The `i > start` condition is the key dedup: only skip if you've already considered this value at the **same level**.
- **Related:** [Combination Sum](../combination-sum/README.md) (with reuse), [Subsets II](https://leetcode.com/problems/subsets-ii/).
