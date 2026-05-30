# Combination Sum

**Source:** LeetCode #39
**Difficulty:** 🟡 Medium
**Topics:** Array, Backtracking

## Problem Statement

Given an array of **distinct** integers `candidates` and a target integer `target`, return all unique combinations where the chosen numbers sum to `target`. The same number may be chosen **unlimited** times.

## Examples

```
Input: candidates = [2,3,6,7], target = 7
Output: [[2,2,3],[7]]

Input: candidates = [2,3,5], target = 8
Output: [[2,2,2,2],[2,3,3],[3,5]]
```

## Constraints

- `1 <= candidates.Length <= 30`; `2 <= candidates[i] <= 40`; distinct; `1 <= target <= 40`.

---

## Approach: Backtracking — O(n^(T/M)) time, O(T/M) space

*T = target, M = min candidate value.*

```csharp
public static IList<IList<int>> CombinationSum(int[] candidates, int target)
{
    var result  = new List<IList<int>>();
    var current = new List<int>();

    void Backtrack(int start, int remaining)
    {
        if (remaining == 0) { result.Add([..current]); return; }
        if (remaining < 0) return;

        for (int i = start; i < candidates.Length; i++)
        {
            current.Add(candidates[i]);
            Backtrack(i, remaining - candidates[i]); // i, not i+1 (reuse allowed)
            current.RemoveAt(current.Count - 1);
        }
    }

    Array.Sort(candidates); // optional: enables early break
    Backtrack(0, target);
    return result;
}
```

### Key difference from Combination Sum II

| | Combination Sum | Combination Sum II |
|---|---|---|
| Reuse | ✅ Same number unlimited times | ❌ Each once |
| Recurse with | `i` (same index) | `i + 1` |
| Input | Distinct | May have duplicates |

---

## Complexity Summary

| Approach     | Time          | Space   |
|--------------|---------------|---------|
| Backtracking | O(n^(T/M))    | O(T/M)  |

---

## Interview Tips

- `Backtrack(i, ...)` not `Backtrack(i+1, ...)` — this allows reusing the same element.
- Sorting candidates + `if (candidates[i] > remaining) break` prunes the search tree early.
- **Related:** [Combination Sum II](../combination-sum-ii/README.md).
