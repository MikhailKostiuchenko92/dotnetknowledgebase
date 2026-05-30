# Trapping Rain Water

**Source:** LeetCode #42
**Difficulty:** 🟡 Medium
**Topics:** Array, Two-Pointer, Stack

## Problem Statement

Given `n` non-negative integers representing an elevation map where the width of each bar is `1`, compute how much water it can trap after raining.

## Examples

```
Input:  height = [0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]
Output: 6

Input:  height = [4, 2, 0, 3, 2, 5]
Output: 9
```

## Constraints

- `n == height.Length`
- `1 <= n <= 2 × 10⁴`
- `0 <= height[i] <= 10⁵`

---

## Approach 1: Precomputed Max Arrays — O(n) time, O(n) space

At each index `i`, water above it = `min(maxLeft[i], maxRight[i]) - height[i]` (clamped to 0).

```csharp
public static int TrapV1(int[] height)
{
    int n = height.Length;
    if (n < 3) return 0;

    int[] maxLeft  = new int[n]; // max height from left including i
    int[] maxRight = new int[n]; // max height from right including i

    maxLeft[0] = height[0];
    for (int i = 1; i < n; i++)
        maxLeft[i] = Math.Max(maxLeft[i - 1], height[i]);

    maxRight[n - 1] = height[n - 1];
    for (int i = n - 2; i >= 0; i--)
        maxRight[i] = Math.Max(maxRight[i + 1], height[i]);

    int water = 0;
    for (int i = 0; i < n; i++)
        water += Math.Min(maxLeft[i], maxRight[i]) - height[i];

    return water;
}
```

---

## Approach 2: Two-Pointer — O(n) time, O(1) space ✓ Preferred

Use two pointers `lo` and `hi`. Maintain `leftMax` and `rightMax`. At each step, process the side with the smaller max — because the water level at that side is fully determined by the smaller wall.

```csharp
public static int Trap(int[] height)
{
    int lo = 0, hi = height.Length - 1;
    int leftMax = 0, rightMax = 0;
    int water = 0;

    while (lo < hi)
    {
        if (height[lo] < height[hi])
        {
            // Left side is the bottleneck
            if (height[lo] >= leftMax)
                leftMax = height[lo];  // update left wall
            else
                water += leftMax - height[lo]; // trapped water at lo
            lo++;
        }
        else
        {
            // Right side is the bottleneck
            if (height[hi] >= rightMax)
                rightMax = height[hi]; // update right wall
            else
                water += rightMax - height[hi]; // trapped water at hi
            hi--;
        }
    }

    return water;
}
```

### Correctness intuition

When `height[lo] < height[hi]`, we know `rightMax >= height[hi] > height[lo]`. So the water at `lo` is determined solely by `leftMax`. We don't need to know the exact right max — it's definitely ≥ `height[hi]` which is already greater than `height[lo]`.

---

## Approach 3: Monotonic Stack — O(n) time, O(n) space

Process water layer by layer using a stack of indices. When we find a bar taller than the stack top, compute the horizontal water trapped between the current bar and the bar below the top.

```csharp
public static int TrapStack(int[] height)
{
    var stack = new Stack<int>(); // stores indices
    int water = 0;

    for (int i = 0; i < height.Length; i++)
    {
        while (stack.Count > 0 && height[i] > height[stack.Peek()])
        {
            int bottom = stack.Pop();
            if (stack.Count == 0) break;

            int left = stack.Peek();
            int width = i - left - 1;
            int boundedHeight = Math.Min(height[left], height[i]) - height[bottom];
            water += width * boundedHeight;
        }
        stack.Push(i);
    }

    return water;
}
```

---

## Complexity Summary

| Approach           | Time | Space |
|--------------------|------|-------|
| Max arrays         | O(n) | O(n)  |
| Two-Pointer        | O(n) | O(1)  |
| Monotonic Stack    | O(n) | O(n)  |

---

## Interview Tips

- **Don't confuse with [Container With Most Water](../container-with-most-water/README.md)** — that problem finds the maximum area between two walls; this problem computes water trapped in valleys.
- Start with the precomputed-arrays approach to show understanding, then optimise to O(1) space with two pointers.
- **State the invariant:** *"When processing from the left, the trapped water at index `i` equals `leftMax - height[i]` if `leftMax <= rightMax`."*
- **Edge cases:** Fewer than 3 bars (no trapping possible), all bars same height (0 water), strictly increasing or decreasing (0 water).
- Walk through a small example (e.g., `[4,2,0,3,2,5]`) to verify — 3 + 4 + 2 = 9.
