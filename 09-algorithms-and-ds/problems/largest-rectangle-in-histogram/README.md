# Largest Rectangle in Histogram

**Source:** LeetCode #84
**Difficulty:** 🟡 Medium
**Topics:** Array, Monotonic Stack

## Problem Statement

Given an array of integers `heights` representing the histogram's bar height where the width of each bar is `1`, return the **area of the largest rectangle** in the histogram.

## Examples

```
Input:  heights = [2, 1, 5, 6, 2, 3]
Output: 10   // rectangle of width 2, height 5 (bars at index 2 and 3)

Input:  heights = [2, 4]
Output: 4
```

## Constraints

- `1 <= heights.Length <= 10⁵`
- `0 <= heights[i] <= 10⁴`

---

## Approach: Monotonic Stack (Increasing) — O(n) time, O(n) space ✓

Maintain a **monotonic increasing stack** of indices. When we encounter a bar shorter than the stack top, we've found the **right boundary** for rectangles centered at the stack top. The **left boundary** is the new stack top after popping.

```csharp
public static int LargestRectangleArea(int[] heights)
{
    int n = heights.Length;
    var stack = new Stack<int>(); // monotonic increasing by height
    int maxArea = 0;

    for (int i = 0; i <= n; i++)
    {
        // Use 0 as sentinel at the end to flush the stack
        int h = i == n ? 0 : heights[i];

        while (stack.Count > 0 && h < heights[stack.Peek()])
        {
            int height = heights[stack.Pop()];
            int width = stack.Count == 0
                ? i                      // extends all the way to the left
                : i - stack.Peek() - 1;  // between current and new stack top
            maxArea = Math.Max(maxArea, height * width);
        }

        stack.Push(i);
    }

    return maxArea;
}
```

### Walkthrough: `[2, 1, 5, 6, 2, 3]`

```
i=0(h=2): push 0. stack=[0]
i=1(h=1): 1<2 → pop 0: height=2, width=1 (stack empty)→area=2. push 1. stack=[1]
i=2(h=5): push 2. stack=[1,2]
i=3(h=6): push 3. stack=[1,2,3]
i=4(h=2): 2<6 → pop 3: height=6, width=4-2-1=1→area=6
           2<5 → pop 2: height=5, width=4-1-1=2→area=10 ← MAX
           2>1: stop. push 4. stack=[1,4]
i=5(h=3): push 5. stack=[1,4,5]
i=6(sentinel h=0): pop 5: height=3, width=6-4-1=1→area=3
           pop 4: height=2, width=6-1-1=4→area=8
           pop 1: height=1, width=6→area=6
Result: 10 ✓
```

---

## Complexity Summary

| Approach         | Time | Space |
|------------------|------|-------|
| Monotonic Stack  | O(n) | O(n)  |

Each bar is pushed and popped exactly once → O(n).

---

## Interview Tips

- **Sentinel value** at `i=n`: appending a `0` ensures all bars are processed and the stack is flushed at the end.
- **Width calculation:** when stack is empty after pop, width = `i` (extends from index 0 to `i-1`); otherwise `i - stack.Peek() - 1`.
- **Common mistake:** Off-by-one in width calculation — walk through the example carefully.
- **Prerequisite pattern:** [Daily Temperatures](../daily-temperatures/README.md) — monotonic decreasing. This uses monotonic *increasing*.
- **Follow-up:** *"Maximal Rectangle in Binary Matrix."* → For each row, treat the cumulative column heights as a histogram and apply this algorithm. [Maximum Rectangle in Binary Matrix](../maximum-rectangle-in-binary-matrix/README.md).
