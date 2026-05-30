# Minimum Spanning Tree — Prim's & Kruskal's

**Source:** Classic algorithms / LeetCode #1584 (Min Cost to Connect All Points)
**Difficulty:** 🔴 Hard
**Topics:** Graph, Union-Find, Greedy, Priority Queue

## Problem Statement

Given a weighted undirected connected graph with `n` nodes, find the **Minimum Spanning Tree (MST)** — a subset of edges that connects all nodes with the minimum total weight, without cycles.

## Examples

```
LeetCode #1584: Given n points, cost = Manhattan distance
Input:  [[0,0],[2,2],[3,10],[5,2],[7,0]]
Output: 20
```

---

## Approach 1: Kruskal's (Union-Find) — O(E log E) time, O(V) space ✓

Sort all edges by weight. Add each edge if it doesn't create a cycle (check via Union-Find).

```csharp
public static int MinCostKruskal(int[][] points)
{
    int n = points.Length;
    // Generate all edges with Manhattan distance
    var edges = new List<(int cost, int u, int v)>();
    for (int i = 0; i < n; i++)
    for (int j = i + 1; j < n; j++)
        edges.Add((Math.Abs(points[i][0]-points[j][0]) + Math.Abs(points[i][1]-points[j][1]), i, j));

    edges.Sort((a, b) => a.cost.CompareTo(b.cost));

    var parent = Enumerable.Range(0, n).ToArray();
    int Find(int x) { while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; }

    int totalCost = 0, edgesUsed = 0;
    foreach (var (cost, u, v) in edges)
    {
        int pu = Find(u), pv = Find(v);
        if (pu == pv) continue; // same component → cycle
        parent[pu] = pv;
        totalCost += cost;
        if (++edgesUsed == n - 1) break;
    }
    return totalCost;
}
```

---

## Approach 2: Prim's (Min-Heap) — O((V + E) log V) time, O(V + E) space

Start from any node; greedily add the cheapest edge connecting the current tree to an unvisited node.

```csharp
public static int MinCostPrim(int[][] points)
{
    int n = points.Length;
    var visited = new bool[n];
    var pq = new PriorityQueue<(int cost, int node), int>();
    pq.Enqueue((0, 0), 0);
    int totalCost = 0, count = 0;

    while (pq.Count > 0 && count < n)
    {
        pq.Dequeue(out var (cost, u), out _);
        if (visited[u]) continue;
        visited[u] = true;
        totalCost += cost;
        count++;

        for (int v = 0; v < n; v++)
        {
            if (visited[v]) continue;
            int w = Math.Abs(points[u][0]-points[v][0]) + Math.Abs(points[u][1]-points[v][1]);
            pq.Enqueue((w, v), w);
        }
    }
    return totalCost;
}
```

---

## Kruskal vs Prim

| | Kruskal | Prim |
|---|---|---|
| Sort / PQ | Sort edges O(E log E) | PQ O((V+E) log V) |
| Data structure | Union-Find | Min-heap |
| Best for | Sparse graphs | Dense graphs |
| Negative weights | ✅ | ✅ |

---

## Complexity Summary

| Approach   | Time        | Space |
|------------|-------------|-------|
| Kruskal    | O(E log E)  | O(V)  |
| Prim       | O((V+E) log V) | O(V + E) |

---

## Interview Tips

- **MST is unique** when all edge weights are distinct.
- For dense graphs (E ≈ V²), Prim with an adjacency matrix runs in O(V²) — better than sorting E² edges.
- LeetCode #1584 has E = O(n²) — both approaches work, but Prim avoids generating all edges explicitly.
