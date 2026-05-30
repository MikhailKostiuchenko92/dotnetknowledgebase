# Longest Consecutive Sequence

**Source:** LeetCode #128
**Difficulty:** 🟡 Medium
**Topics:** Array, HashSet

## Problem Statement

Given an unsorted array of integers `nums`, return the length of the **longest consecutive elements sequence**.

Must run in **O(n)** time.

## Examples

```
Input:  nums = [100, 4, 200, 1, 3, 2]
Output: 4   // [1, 2, 3, 4]

Input:  nums = [0, 3, 7, 2, 5, 8, 4, 6, 0, 1]
Output: 9   // [0, 1, 2, 3, 4, 5, 6, 7, 8]

Input:  nums = []
Output: 0
```

## Constraints

- `0 <= nums.Length <= 10⁵`
- `-10⁹ <= nums[i] <= 10⁹`

---

## Approach 1: Sort — O(n log n) time, O(1) space

Sort, then scan for consecutive runs (handling duplicates).

```csharp
public static int LongestConsecutiveSort(int[] nums)
{
    if (nums.Length == 0) return 0;
    Array.Sort(nums);
    int maxLen = 1, cur = 1;
    for (int i = 1; i < nums.Length; i++)
    {
        if (nums[i] == nums[i - 1]) continue; // skip duplicates
        if (nums[i] == nums[i - 1] + 1) cur++;
        else cur = 1;
        maxLen = Math.Max(maxLen, cur);
    }
    return maxLen;
}
```

Doesn't meet the O(n) requirement — mention it as a baseline.

---

## Approach 2: HashSet — O(n) time, O(n) space ✓

Add all numbers to a `HashSet`. For each number `n`, only start counting if `n - 1` is **not** in the set (i.e., `n` is a sequence start). Then count upward.

```csharp
public static int LongestConsecutive(int[] nums)
{
    var set = new HashSet<int>(nums);
    int maxLen = 0;

    foreach (int n in set)
    {
        // Only start counting from the beginning of a sequence
        if (set.Contains(n - 1)) continue;

        int cur = n;
        int len = 1;
        while (set.Contains(cur + 1)) { cur++; len++; }

        maxLen = Math.Max(maxLen, len);
    }

    return maxLen;
}
```

### Why O(n) despite the nested while?

Each number is visited as a "sequence start" at most once (the `if (set.Contains(n-1)) continue` guard), and the `while` loop increments through each element at most once across all iterations. Total work = O(n).

---

## Complexity Summary

| Approach  | Time       | Space |
|-----------|------------|-------|
| Sort      | O(n log n) | O(1)  |
| HashSet   | O(n)       | O(n)  |

---

## Interview Tips

- **Immediately acknowledge the O(n) requirement** — mention that sorting gives O(n log n) which doesn't qualify.
- **State the "sequence start" insight:** only begin counting when `n - 1` is absent from the set.
- **Common mistake:** Iterating over the original array instead of the set (duplicate values in the array would cause double-counting of sequence lengths).
- **Edge cases:** Empty array, all duplicates (e.g., `[5,5,5]` → 1), single element.
- **Follow-up:** *"Return the actual sequence, not just its length."* → Track `curStart` and reconstruct `[curStart..curStart+maxLen-1]`.
