# Pacific Atlantic Water Flow

**Source:** LeetCode #417
**Difficulty:** 🟡 Medium
**Topics:** Array, DFS, BFS, Multi-source BFS

## Problem Statement

There is an `m × n` rectangular island with height values. Rain water flows to adjacent cells (up/down/left/right) if their height is ≤ the current cell's height. Water can flow to the **Pacific Ocean** (top/left border) or the **Atlantic Ocean** (bottom/right border).

Return a list of coordinates `[r, c]` from which water can flow to **both** oceans.

## Examples

```
Input:
heights = [[1,2,2,3,5],[3,2,3,4,4],[2,4,5,3,1],[6,7,1,4,5],[5,1,1,2,4]]
Output:  [[0,4],[1,3],[1,4],[2,2],[3,0],[3,1],[4,0]]
```

## Constraints

- `1 <= m, n <= 200`; `0 <= heights[i][j] <= 10⁵`

---

## Approach: Reverse Multi-Source BFS — O(m·n) time, O(m·n) space ✓

Instead of tracing water forward from every cell (expensive), **reverse the flow**: start BFS from ocean borders and flood uphill (cells with height ≥ current). Find cells reachable from both oceans.

```csharp
public static IList<IList<int>> PacificAtlantic(int[][] heights)
{
    int m = heights.Length, n = heights[0].Length;
    bool[,] pacific  = new bool[m, n];
    bool[,] atlantic = new bool[m, n];

    var pacQueue = new Queue<(int, int)>();
    var atlQueue = new Queue<(int, int)>();

    for (int r = 0; r < m; r++)
    {
        Enqueue(pacQueue, pacific,  r, 0);
        Enqueue(atlQueue, atlantic, r, n - 1);
    }
    for (int c = 0; c < n; c++)
    {
        Enqueue(pacQueue, pacific,  0, c);
        Enqueue(atlQueue, atlantic, m - 1, c);
    }

    Bfs(heights, pacQueue,  pacific,  m, n);
    Bfs(heights, atlQueue, atlantic, m, n);

    var result = new List<IList<int>>();
    for (int r = 0; r < m; r++)
    for (int c = 0; c < n; c++)
        if (pacific[r, c] && atlantic[r, c])
            result.Add([r, c]);

    return result;
}

private static void Enqueue(Queue<(int, int)> q, bool[,] visited, int r, int c)
{
    visited[r, c] = true;
    q.Enqueue((r, c));
}

private static void Bfs(int[][] h, Queue<(int, int)> queue, bool[,] visited, int m, int n)
{
    int[] dr = [-1, 1, 0, 0], dc = [0, 0, -1, 1];
    while (queue.Count > 0)
    {
        var (r, c) = queue.Dequeue();
        foreach (var (dr2, dc2) in Enumerable.Zip(dr, dc))
        {
            int nr = r + dr2, nc = c + dc2;
            if (nr < 0 || nr >= m || nc < 0 || nc >= n) continue;
            if (visited[nr, nc]) continue;
            if (h[nr][nc] < h[r][c]) continue; // water can't flow uphill in reverse
            visited[nr, nc] = true;
            queue.Enqueue((nr, nc));
        }
    }
}
```

---

## Complexity Summary

| Approach           | Time   | Space  |
|--------------------|--------|--------|
| Reverse multi-BFS  | O(m·n) | O(m·n) |

---

## Interview Tips

- The **reverse flooding** insight is the key: instead of going downhill from each cell, go uphill from each ocean border.
- Two separate BFS passes — then intersect the two visited sets.
- DFS works equally well; same complexity.
