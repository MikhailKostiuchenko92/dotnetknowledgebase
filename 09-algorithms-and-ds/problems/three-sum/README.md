# 3Sum

**Source:** LeetCode #15
**Difficulty:** 🟡 Medium
**Topics:** Array, Sorting, Two-Pointer

## Problem Statement

Given an integer array `nums`, return all the triplets `[nums[i], nums[j], nums[k]]` such that `i != j`, `i != k`, `j != k`, and `nums[i] + nums[j] + nums[k] == 0`.

The solution set must **not contain duplicate triplets**.

## Examples

```
Input:  nums = [-1, 0, 1, 2, -1, -4]
Output: [[-1,-1,2],[-1,0,1]]

Input:  nums = [0, 1, 1]
Output: []

Input:  nums = [0, 0, 0]
Output: [[0,0,0]]
```

## Constraints

- `3 <= nums.Length <= 3000`
- `-10⁵ <= nums[i] <= 10⁵`

---

## Approach 1: Brute Force — O(n³) time, O(1) space

Check all triples. Too slow for `n = 3000`.

---

## Approach 2: Sort + Two-Pointer — O(n²) time, O(1) extra space ✓

Sort the array. For each element at index `i`, use two-pointer on the remainder to find pairs that sum to `-nums[i]`. Skip duplicates at each position.

```csharp
public static IList<IList<int>> ThreeSum(int[] nums)
{
    Array.Sort(nums);
    var result = new List<IList<int>>();

    for (int i = 0; i < nums.Length - 2; i++)
    {
        // Skip duplicate values for the first element
        if (i > 0 && nums[i] == nums[i - 1]) continue;

        // Early exit: smallest remaining sum > 0
        if (nums[i] > 0) break;

        int lo = i + 1, hi = nums.Length - 1;

        while (lo < hi)
        {
            int sum = nums[i] + nums[lo] + nums[hi];
            if (sum == 0)
            {
                result.Add([nums[i], nums[lo], nums[hi]]);
                // Skip duplicates for lo and hi
                while (lo < hi && nums[lo] == nums[lo + 1]) lo++;
                while (lo < hi && nums[hi] == nums[hi - 1]) hi--;
                lo++; hi--;
            }
            else if (sum < 0) lo++;
            else              hi--;
        }
    }

    return result;
}
```

### Deduplication Strategy

Sorting brings equal elements together. We skip `nums[i]` if it equals `nums[i-1]` (same first element → same triplets). After finding a valid triplet, we skip past all equal `lo` and `hi` values before moving the pointers.

---

## Complexity Summary

| Approach         | Time   | Space |
|------------------|--------|-------|
| Brute Force      | O(n³)  | O(1)  |
| Sort + two-pointer | O(n²)| O(1)  |

---

## Interview Tips

- **Sort first** — this is the key enabler for both two-pointer and deduplication.
- Articulate the deduplication logic clearly — it's the trickiest part: *"I skip duplicates at the `i` position by checking `nums[i] == nums[i-1]`, and after a match I advance both pointers past any duplicates."*
- **Early exit:** `if (nums[i] > 0) break` — once the smallest element is positive, no triple can sum to zero.
- **Edge cases:** Fewer than 3 elements, all zeros, array with many duplicates.
- **Follow-up:** *"3Sum Closest"* — LeetCode #16, track minimum `|sum - target|` instead of exact match.
- **Follow-up:** *"4Sum"* — LeetCode #18, add another outer loop and reduce to 3Sum.
