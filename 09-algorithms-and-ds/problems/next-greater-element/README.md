# Next Greater Element

**Source:** LeetCode #496
**Difficulty:** 🟡 Medium
**Topics:** Array, HashMap, Monotonic Stack

## Problem Statement

The **next greater element** of some element `x` in an array is the **first element to the right** of `x` that is greater than `x`. If no such element exists, the next greater element is `-1`.

Given two distinct 0-indexed integer arrays `nums1` and `nums2`, where `nums1` is a subset of `nums2`, for each `nums1[i]` find the next greater element in `nums2`.

Return an array `answer` such that `answer[i]` is the next greater element of `nums1[i]` in `nums2`, or `-1` if it does not exist.

## Examples

```
Input:  nums1 = [4,1,2], nums2 = [1,3,4,2]
Output: [-1,3,-1]
// 4 → no greater in nums2 → -1
// 1 → next greater after 1 in nums2 is 3
// 2 → no greater in nums2 → -1

Input:  nums1 = [2,4], nums2 = [1,2,3,4]
Output: [3,-1]
```

## Constraints

- `1 <= nums1.Length <= nums2.Length <= 1000`
- All integers in `nums1` and `nums2` are unique.
- `nums1` is a subset of `nums2`.

---

## Approach: Monotonic Stack + HashMap — O(m + n) time, O(n) space ✓

**Step 1:** Precompute `nextGreater` map for all elements in `nums2` using a monotonic stack.  
**Step 2:** Look up each `nums1[i]` in the map.

```csharp
public static int[] NextGreaterElement(int[] nums1, int[] nums2)
{
    // Build next-greater map for nums2
    var nextGreater = new Dictionary<int, int>(nums2.Length);
    var stack = new Stack<int>(); // values waiting for next greater

    foreach (int n in nums2)
    {
        // n is the next greater for all stack elements smaller than n
        while (stack.Count > 0 && n > stack.Peek())
            nextGreater[stack.Pop()] = n;
        stack.Push(n);
    }

    // Remaining in stack have no next greater element
    while (stack.Count > 0)
        nextGreater[stack.Pop()] = -1;

    // Answer queries from nums1
    return nums1.Select(x => nextGreater[x]).ToArray();
}
```

---

## Variant: Next Greater Element in Circular Array (LeetCode #503)

For a circular array, iterate `2n` times using `i % n` indexing:

```csharp
public static int[] NextGreaterElements(int[] nums)
{
    int n = nums.Length;
    int[] result = new int[n];
    Array.Fill(result, -1);
    var stack = new Stack<int>(); // stores indices

    for (int i = 0; i < 2 * n; i++)
    {
        while (stack.Count > 0 && nums[i % n] > nums[stack.Peek()])
            result[stack.Pop()] = nums[i % n];
        if (i < n) stack.Push(i);
    }
    return result;
}
```

---

## Complexity Summary

| Approach              | Time     | Space |
|-----------------------|----------|-------|
| Monotonic Stack + Map | O(m + n) | O(n)  |

---

## Interview Tips

- **Monotonic stack** (decreasing): push elements; when a larger one arrives, it's the "next greater" for all smaller elements on the stack.
- **Related:** [Daily Temperatures](../daily-temperatures/README.md) — almost identical, just records distance instead of value.
- **Circular variant** — iterate `2n` rounds. The second pass resolves elements that were waiting for a wrap-around greater value.
- **Edge cases:** `nums1 == nums2` (all queried), `nums2` is strictly decreasing (all answers are -1).
