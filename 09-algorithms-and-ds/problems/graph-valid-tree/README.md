# Graph Valid Tree

**Source:** LeetCode #261 (Premium) / NeetCode
**Difficulty:** 🟡 Medium
**Topics:** Graph, Union-Find, DFS/BFS

## Problem Statement

Given `n` nodes labeled `0` to `n-1` and a list of undirected `edges`, determine if the edges make a valid tree.

A valid tree has exactly **n - 1 edges** and is **connected** (no cycles).

## Examples

```
Input:  n = 5, edges = [[0,1],[0,2],[0,3],[1,4]]   Output: true
Input:  n = 5, edges = [[0,1],[1,2],[2,3],[1,3],[1,4]]   Output: false (cycle)
```

## Constraints

- `1 <= n <= 2000`; `0 <= edges.Length <= 5000`

---

## Approach 1: Union-Find — O(n + e · α(n)) time, O(n) space ✓

A tree = connected + acyclic. With Union-Find:
- If a union finds both nodes already in the same component → cycle → return false.
- Final check: exactly `n - 1` edges were accepted.

```csharp
public static bool ValidTree(int n, int[][] edges)
{
    if (edges.Length != n - 1) return false; // quick filter

    var parent = Enumerable.Range(0, n).ToArray();
    int rank   = 0; // unused here, we use path compression only

    int Find(int x)
    {
        while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
        return x;
    }

    bool Union(int x, int y)
    {
        int px = Find(x), py = Find(y);
        if (px == py) return false; // cycle
        parent[px] = py;
        return true;
    }

    foreach (var e in edges)
        if (!Union(e[0], e[1])) return false;

    return true; // n-1 edges accepted → connected
}
```

---

## Approach 2: DFS Cycle Detection — O(n + e) time, O(n + e) space

Track `parent` to avoid treating the bidirectional edge as a back edge.

```csharp
public static bool ValidTreeDFS(int n, int[][] edges)
{
    if (edges.Length != n - 1) return false;

    var adj = new List<int>[n];
    for (int i = 0; i < n; i++) adj[i] = [];
    foreach (var e in edges) { adj[e[0]].Add(e[1]); adj[e[1]].Add(e[0]); }

    var visited = new bool[n];

    bool Dfs(int u, int parent)
    {
        visited[u] = true;
        foreach (int v in adj[u])
        {
            if (v == parent) continue; // skip the edge we came from
            if (visited[v]) return false; // cycle
            if (!Dfs(v, u)) return false;
        }
        return true;
    }

    return Dfs(0, -1) && visited.All(v => v); // connected check
}
```

---

## Complexity Summary

| Approach    | Time              | Space    |
|-------------|-------------------|----------|
| Union-Find  | O(n + e · α(n))   | O(n)     |
| DFS         | O(n + e)          | O(n + e) |

---

## Interview Tips

- Quick check: `edges.Length != n - 1` → immediately return `false` (tree must have exactly n-1 edges).
- Union-Find is the cleanest solution for this problem.
- **Undirected DFS:** track parent to avoid treating `u → v → u` as a cycle.
