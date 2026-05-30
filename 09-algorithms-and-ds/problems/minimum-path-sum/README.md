# Minimum Path Sum

**Source:** LeetCode #64
**Difficulty:** 🟡 Medium
**Topics:** Array, Dynamic Programming

## Problem Statement

Given an `m × n` grid filled with non-negative numbers, find a path from top-left to bottom-right which minimises the sum of all numbers along its path. You can only move down or right.

## Examples

```
Input:
grid = [[1,3,1],[1,5,1],[4,2,1]]
Output: 7   // 1 → 3 → 1 → 1 → 1
```

## Constraints

- `1 <= m, n <= 200`; `0 <= grid[i][j] <= 200`

---

## Approach: In-Place DP — O(m·n) time, O(1) space ✓

Modify the grid directly: `grid[r][c] += min(grid[r-1][c], grid[r][c-1])`.

```csharp
public static int MinPathSum(int[][] grid)
{
    int m = grid.Length, n = grid[0].Length;

    // Fill first row and column (only one direction to come from)
    for (int c = 1; c < n; c++) grid[0][c] += grid[0][c-1];
    for (int r = 1; r < m; r++) grid[r][0] += grid[r-1][0];

    for (int r = 1; r < m; r++)
    for (int c = 1; c < n; c++)
        grid[r][c] += Math.Min(grid[r-1][c], grid[r][c-1]);

    return grid[m-1][n-1];
}
```

---

## Complexity Summary

| Approach    | Time   | Space |
|-------------|--------|-------|
| In-place DP | O(m·n) | O(1)  |

---

## Interview Tips

- In-place modification is O(1) space. If the input must not be modified, use a 1-D rolling array O(n).
- **Related:** [Unique Paths](../unique-paths/README.md) — same structure, no costs.
- **Follow-up:** *"What if you can also move up or left?"* → Now it's a shortest path graph problem (Dijkstra/BFS with 0-1 weights).
