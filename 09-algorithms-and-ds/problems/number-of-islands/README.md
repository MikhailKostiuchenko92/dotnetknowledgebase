# Number of Islands

**Source:** LeetCode #200
**Difficulty:** 🟡 Medium
**Topics:** Array, DFS, BFS, Union-Find

## Problem Statement

Given an `m × n` 2D binary grid of `'1'`s (land) and `'0'`s (water), return the number of islands.

An island is surrounded by water and is formed by connecting adjacent lands horizontally or vertically.

## Examples

```
Input:
11110
11010
11000
00000
Output: 1

Input:
11000
11000
00100
00011
Output: 3
```

## Constraints

- `1 <= m, n <= 300`; `grid[i][j]` is `'0'` or `'1'`.

---

## Approach 1: DFS (Flood Fill) — O(m·n) time, O(m·n) space ✓

Visit each unvisited `'1'`, flood-fill it (mark as `'0'`) and count +1.

```csharp
public static int NumIslands(char[][] grid)
{
    int m = grid.Length, n = grid[0].Length, count = 0;

    for (int r = 0; r < m; r++)
    for (int c = 0; c < n; c++)
    {
        if (grid[r][c] == '1')
        {
            Dfs(grid, r, c, m, n);
            count++;
        }
    }
    return count;
}

private static void Dfs(char[][] grid, int r, int c, int m, int n)
{
    if (r < 0 || r >= m || c < 0 || c >= n || grid[r][c] != '1') return;
    grid[r][c] = '0'; // mark visited
    Dfs(grid, r+1, c, m, n);
    Dfs(grid, r-1, c, m, n);
    Dfs(grid, r, c+1, m, n);
    Dfs(grid, r, c-1, m, n);
}
```

---

## Approach 2: BFS — O(m·n) time, O(min(m,n)) space

Same idea with a queue; avoids deep call stacks for large grids.

```csharp
public static int NumIslandsBFS(char[][] grid)
{
    int m = grid.Length, n = grid[0].Length, count = 0;
    int[] dr = [-1, 1, 0, 0], dc = [0, 0, -1, 1];

    for (int r = 0; r < m; r++)
    for (int c = 0; c < n; c++)
    {
        if (grid[r][c] != '1') continue;
        count++;
        grid[r][c] = '0';
        var queue = new Queue<(int, int)>();
        queue.Enqueue((r, c));
        while (queue.Count > 0)
        {
            var (cr, cc) = queue.Dequeue();
            for (int d = 0; d < 4; d++)
            {
                int nr = cr + dr[d], nc = cc + dc[d];
                if (nr >= 0 && nr < m && nc >= 0 && nc < n && grid[nr][nc] == '1')
                {
                    grid[nr][nc] = '0';
                    queue.Enqueue((nr, nc));
                }
            }
        }
    }
    return count;
}
```

---

## Complexity Summary

| Approach    | Time   | Space      |
|-------------|--------|------------|
| DFS         | O(m·n) | O(m·n) stack |
| BFS         | O(m·n) | O(min(m,n)) |
| Union-Find  | O(m·n α(m·n)) | O(m·n) |

---

## Interview Tips

- Modifying the input is acceptable to mark visited; if not allowed, use a `bool[,] visited` matrix.
- DFS can overflow the stack for large grids (300×300) — mention BFS as a safer alternative.
- **Union-Find** is the third approach — good for interview bonus points and when you can't modify the grid.
- **Follow-up:** *"Number of Islands II"* (dynamic additions) → Union-Find shines there.
