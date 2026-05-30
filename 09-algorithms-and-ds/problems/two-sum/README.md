# Two Sum

**Source:** LeetCode #1
**Difficulty:** 🟢 Easy
**Topics:** Array, HashMap

## Problem Statement

Given an array of integers `nums` and an integer `target`, return the **indices** of the two numbers that add up to `target`. You may assume exactly one solution exists, and you may not use the same element twice.

## Examples

```
Input:  nums = [2, 7, 11, 15], target = 9
Output: [0, 1]   // nums[0] + nums[1] = 2 + 7 = 9

Input:  nums = [3, 2, 4], target = 6
Output: [1, 2]

Input:  nums = [3, 3], target = 6
Output: [0, 1]
```

## Constraints

- `2 <= nums.length <= 10⁴`
- `-10⁹ <= nums[i] <= 10⁹`
- `-10⁹ <= target <= 10⁹`
- Exactly one valid answer exists.

---

## Approach 1: Brute Force — O(n²) time, O(1) space

Check every pair `(i, j)` where `i < j`. Simple but slow.

```csharp
public int[] TwoSumBrute(int[] nums, int target)
{
    for (int i = 0; i < nums.Length; i++)
        for (int j = i + 1; j < nums.Length; j++)
            if (nums[i] + nums[j] == target)
                return [i, j];
    return [];
}
```

**When to mention:** Good as a starting point to show you understand the problem, then immediately improve.

---

## Approach 2: HashMap (One Pass) — O(n) time, O(n) space

For each element, compute its **complement** (`target - nums[i]`) and check if it's already in a dictionary. Store each value → index as you go.

### Key insight

You don't need a two-pass approach. A single pass works because if `a + b = target` and you process `a` first, when you hit `b` you'll find `a` in the map. If `b` comes first, you find it when you process `a`.

```csharp
public int[] TwoSum(int[] nums, int target)
{
    // value → index map built incrementally
    var seen = new Dictionary<int, int>(nums.Length);

    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (seen.TryGetValue(complement, out int j))
            return [j, i];

        // Only add AFTER checking, to avoid using same index twice
        seen[nums[i]] = i;
    }

    return []; // guaranteed not reached
}
```

> **Pitfall:** Add `nums[i]` to the map *after* looking up the complement. If you add first, a case like `nums = [3,3], target = 6` would incorrectly return `[0, 0]` (same index) instead of `[0, 1]`.

---

## Complexity Summary

| Approach       | Time   | Space  |
|----------------|--------|--------|
| Brute Force    | O(n²)  | O(1)   |
| HashMap        | O(n)   | O(n)   |

---

## Interview Tips

- **Clarify first:** Can there be duplicate values? Can elements be negative? Is there always exactly one solution?
- **Mention edge cases:** `[3, 3]` with target `6` — two equal values at different indices.
- State your approach aloud: *"I'll use a hash map to trade space for time, reducing O(n²) to O(n)."*
- Follow-up: *"What if the array is sorted?"* → Two-pointer approach, O(1) space. *"What if you need all pairs?"* → Collect results instead of returning.
- In C# prefer `Dictionary.TryGetValue` over `ContainsKey` + indexer to avoid double-hashing.
