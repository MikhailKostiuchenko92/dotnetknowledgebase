# Number of Connected Components in an Undirected Graph

**Source:** LeetCode #323 (Premium) / NeetCode
**Difficulty:** 🟡 Medium
**Topics:** Graph, Union-Find, DFS/BFS

## Problem Statement

Given `n` nodes (labeled `0` to `n-1`) and a list of undirected `edges`, return the **number of connected components** in the graph.

## Examples

```
Input:  n = 5, edges = [[0,1],[1,2],[3,4]]   Output: 2
Input:  n = 5, edges = [[0,1],[1,2],[2,3],[3,4]]   Output: 1
```

## Constraints

- `1 <= n <= 2000`; `0 <= edges.Length <= 5000`

---

## Approach 1: Union-Find — O(n + e · α(n)) time, O(n) space ✓

Start with `n` components. Each successful union reduces the count by 1.

```csharp
public static int CountComponents(int n, int[][] edges)
{
    var parent = Enumerable.Range(0, n).ToArray();
    int components = n;

    int Find(int x)
    {
        while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
        return x;
    }

    foreach (var e in edges)
    {
        int px = Find(e[0]), py = Find(e[1]);
        if (px != py) { parent[px] = py; components--; }
    }
    return components;
}
```

---

## Approach 2: DFS — O(n + e) time, O(n + e) space

```csharp
public static int CountComponentsDFS(int n, int[][] edges)
{
    var adj = new List<int>[n];
    for (int i = 0; i < n; i++) adj[i] = [];
    foreach (var e in edges) { adj[e[0]].Add(e[1]); adj[e[1]].Add(e[0]); }

    var visited = new bool[n];
    int count = 0;

    void Dfs(int u) { visited[u] = true; foreach (int v in adj[u]) if (!visited[v]) Dfs(v); }

    for (int i = 0; i < n; i++)
        if (!visited[i]) { Dfs(i); count++; }

    return count;
}
```

---

## Complexity Summary

| Approach    | Time             | Space    |
|-------------|------------------|----------|
| Union-Find  | O(n + e · α(n))  | O(n)     |
| DFS         | O(n + e)         | O(n + e) |

---

## Interview Tips

- Union-Find is optimal and very compact for this problem.
- **Path compression** (`parent[x] = parent[parent[x]]`) halves the path length each call — much simpler than full path compression but nearly as fast.
- **Related:** [Graph Valid Tree](../graph-valid-tree/README.md), [Number of Islands](../number-of-islands/README.md).
