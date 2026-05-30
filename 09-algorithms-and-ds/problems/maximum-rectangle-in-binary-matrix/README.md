# Maximal Rectangle in Binary Matrix

**Source:** LeetCode #85
**Difficulty:** 🔴 Hard
**Topics:** Array, Stack, Dynamic Programming

## Problem Statement

Given a `rows × cols` binary matrix filled with `'0'`s and `'1'`s, find the largest rectangle containing only `'1'`s and return its area.

## Examples

```
Input:
[["1","0","1","0","0"],
 ["1","0","1","1","1"],
 ["1","1","1","1","1"],
 ["1","0","0","1","0"]]
Output: 6   // rows 1–2, cols 2–4
```

## Constraints

- `1 <= rows, cols <= 200`

---

## Approach: Histogram + Monotonic Stack — O(rows × cols) time, O(cols) space ✓

For each row, compute the **histogram heights** (number of consecutive '1's up to current row). Then apply [Largest Rectangle in Histogram](../largest-rectangle-in-histogram/README.md) on each row's histogram.

```csharp
public static int MaximalRectangle(char[][] matrix)
{
    int rows = matrix.Length, cols = matrix[0].Length;
    var heights = new int[cols];
    int maxArea = 0;

    foreach (var row in matrix)
    {
        // Update heights
        for (int c = 0; c < cols; c++)
            heights[c] = row[c] == '1' ? heights[c] + 1 : 0;

        maxArea = Math.Max(maxArea, LargestRectangleInHistogram(heights));
    }
    return maxArea;
}

private static int LargestRectangleInHistogram(int[] heights)
{
    var stack = new Stack<int>();
    int maxArea = 0, n = heights.Length;

    for (int i = 0; i <= n; i++)
    {
        int h = i == n ? 0 : heights[i];
        while (stack.Count > 0 && h < heights[stack.Peek()])
        {
            int height = heights[stack.Pop()];
            int width  = stack.Count == 0 ? i : i - stack.Peek() - 1;
            maxArea = Math.Max(maxArea, height * width);
        }
        stack.Push(i);
    }
    return maxArea;
}
```

---

## Complexity Summary

| Approach                      | Time           | Space   |
|-------------------------------|----------------|---------|
| Histogram + Monotonic Stack   | O(rows × cols) | O(cols) |

---

## Interview Tips

- This problem **reduces to** [Largest Rectangle in Histogram](../largest-rectangle-in-histogram/README.md) — state this reduction explicitly.
- Building up heights row-by-row is the key transformation.
- **Alternative:** DP approach with `height`, `left`, `right` arrays per row — also O(rows × cols) but harder to implement correctly.
