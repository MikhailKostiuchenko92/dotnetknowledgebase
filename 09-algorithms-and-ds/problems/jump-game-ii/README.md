# Jump Game II

**Source:** LeetCode #45
**Difficulty:** 🟡 Medium
**Topics:** Array, Greedy, Dynamic Programming

## Problem Statement

Given an integer array `nums` where `nums[i]` is the maximum jump length from index `i`, return the **minimum number of jumps** to reach the last index. It is guaranteed you can reach the last index.

## Examples

```
Input: nums = [2,3,1,1,4]   Output: 2   // jump 1 → index 1, jump 3 → last
Input: nums = [2,3,0,1,4]   Output: 2
```

## Constraints

- `1 <= nums.Length <= 10⁴`; `0 <= nums[i] <= 1000`; guaranteed reachable.

---

## Approach: Greedy BFS — O(n) time, O(1) space ✓

Think of it as BFS levels: within the current "level" (range of indices reachable with the current number of jumps), find the farthest point reachable in the next jump. When the current level ends, take one more jump.

```csharp
public static int Jump(int[] nums)
{
    int jumps = 0, currentEnd = 0, farthest = 0;

    for (int i = 0; i < nums.Length - 1; i++) // don't need to jump FROM the last index
    {
        farthest = Math.Max(farthest, i + nums[i]);

        if (i == currentEnd) // reached end of current BFS level
        {
            jumps++;
            currentEnd = farthest;
        }
    }
    return jumps;
}
```

### Walkthrough: `[2,3,1,1,4]`

```
i=0: farthest=max(0,0+2)=2; i==currentEnd(0) → jumps=1, currentEnd=2
i=1: farthest=max(2,1+3)=4
i=2: farthest=max(4,2+1)=4; i==currentEnd(2) → jumps=2, currentEnd=4
i=3: 3 < currentEnd(4), no new jump
Result: 2 jumps
```

---

## Complexity Summary

| Approach  | Time | Space |
|-----------|------|-------|
| Greedy    | O(n) | O(1)  |

---

## Interview Tips

- The loop goes to `nums.Length - 1` — we don't need to jump from the last index.
- `currentEnd` acts as the BFS layer boundary; `farthest` tracks the maximum reach within the layer.
- **Related:** LeetCode #55 "Jump Game I" (can you reach? — simpler greedy).
