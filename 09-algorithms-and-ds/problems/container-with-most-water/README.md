# Container With Most Water

**Source:** LeetCode #11
**Difficulty:** 🟡 Medium
**Topics:** Array, Two-Pointer, Greedy

## Problem Statement

You are given an integer array `height` of length `n`. There are `n` vertical lines drawn such that the two endpoints of the `i`-th line are `(i, 0)` and `(i, height[i])`.

Find two lines that together with the x-axis form a container that holds the most water. Return the **maximum amount of water** a container can store.

> You may not slant the container.

## Examples

```
Input:  height = [1, 8, 6, 2, 5, 4, 8, 3, 7]
Output: 49   // Lines at index 1 (h=8) and 8 (h=7): min(8,7) * (8-1) = 7 * 7 = 49

Input:  height = [1, 1]
Output: 1
```

## Constraints

- `n == height.Length`
- `2 <= n <= 10⁵`
- `0 <= height[i] <= 10⁴`

---

## Approach 1: Brute Force — O(n²) time, O(1) space

Try every pair of lines.

```csharp
public static int MaxAreaBrute(int[] height)
{
    int max = 0;
    for (int i = 0; i < height.Length; i++)
        for (int j = i + 1; j < height.Length; j++)
            max = Math.Max(max, Math.Min(height[i], height[j]) * (j - i));
    return max;
}
```

---

## Approach 2: Two-Pointer — O(n) time, O(1) space

Start with the widest container (leftmost and rightmost lines). Move the pointer with the **shorter** line inward — this is the only move that could possibly increase the area (the width decreases, so you must increase the height to compensate).

```csharp
public static int MaxArea(int[] height)
{
    int lo = 0, hi = height.Length - 1;
    int max = 0;

    while (lo < hi)
    {
        int area = Math.Min(height[lo], height[hi]) * (hi - lo);
        max = Math.Max(max, area);

        // Move the shorter wall inward — moving the taller wall can only hurt
        if (height[lo] < height[hi])
            lo++;
        else
            hi--;
    }

    return max;
}
```

### Why move the shorter pointer?

The area is bounded by `min(height[lo], height[hi]) * width`. The width shrinks by 1 each step no matter what. The only way to increase area is to find a taller line. Moving the taller line inward guarantees `min(...)` stays the same or drops — strictly suboptimal. Moving the shorter line is the only chance to improve.

> **This is a classic greedy argument.** State it explicitly in interviews.

---

## Complexity Summary

| Approach      | Time   | Space |
|---------------|--------|-------|
| Brute Force   | O(n²)  | O(1)  |
| Two-Pointer   | O(n)   | O(1)  |

---

## Interview Tips

- **Clarify:** Lines are vertical, water cannot be slanted — this means the effective height is always `min(left, right)`.
- State the greedy argument before coding: *"I'll use two pointers starting at the ends and always move the shorter one inward."*
- **Edge case:** Two elements → single pair only.
- **Common mistake:** Moving the taller pointer instead of the shorter one, or moving both.
- **Follow-up:** *"What if the container is 3D (Trapping Rain Water)?"* → [Trapping Rain Water](../trapping-rain-water/README.md) — fundamentally different problem.
- Prove correctness: at each step you discard the pair with the shorter line's current position; any skipped pair would have a smaller or equal area.
