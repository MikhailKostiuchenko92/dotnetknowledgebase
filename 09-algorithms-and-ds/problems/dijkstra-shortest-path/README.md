# Dijkstra's Shortest Path

**Source:** Classic algorithm / LeetCode #743 (Network Delay Time)
**Difficulty:** 🔴 Hard
**Topics:** Graph, Priority Queue (Min-Heap), Greedy

## Problem Statement

Given a directed weighted graph with `n` nodes and edges `[u, v, w]`, find the shortest path from source `src` to all other nodes. Return an array of minimum distances; use `int.MaxValue` for unreachable nodes.

## Examples

```
n = 4, edges = [[2,1,1],[2,3,1],[3,4,1]], src = 2
Output: distances = [int.MaxValue, 1, 0, 1, 2]  // 1-indexed, dist[2]=0
```

## Constraints

- Non-negative edge weights only (Dijkstra's requirement).

---

## Approach: Priority Queue (Min-Heap) — O((V + E) log V) time, O(V + E) space ✓

Use `PriorityQueue<int, int>` (min-heap on distance). Relax edges greedily from the nearest unvisited node.

```csharp
public static int[] Dijkstra(int n, int[][] edges, int src)
{
    // Build adjacency list: adj[u] = [(v, weight)]
    var adj = new List<(int v, int w)>[n + 1];
    for (int i = 0; i <= n; i++) adj[i] = [];
    foreach (var e in edges) adj[e[0]].Add((e[1], e[2]));

    var dist = new int[n + 1];
    Array.Fill(dist, int.MaxValue);
    dist[src] = 0;

    // PriorityQueue<element, priority> — min-heap in .NET
    var pq = new PriorityQueue<int, int>();
    pq.Enqueue(src, 0);

    while (pq.Count > 0)
    {
        pq.Dequeue(out int u, out int d);
        if (d > dist[u]) continue; // stale entry

        foreach (var (v, w) in adj[u])
        {
            int newDist = dist[u] + w;
            if (newDist < dist[v])
            {
                dist[v] = newDist;
                pq.Enqueue(v, newDist);
            }
        }
    }
    return dist;
}
```

> **Important (.NET):** `PriorityQueue<TElement, TPriority>` is a **min-heap** — the element with the *lowest* priority value is dequeued first. No need to negate for shortest path. Use `pq.Dequeue(out TElement element, out TPriority priority)` to get both values simultaneously.

---

## Complexity Summary

| Approach               | Time              | Space     |
|------------------------|-------------------|-----------|
| Binary Min-Heap (PQ)   | O((V + E) log V)  | O(V + E)  |
| Fibonacci Heap         | O(E + V log V)    | O(V + E)  |

---

## Interview Tips

- **Negative edges?** → Dijkstra doesn't work. Use [Bellman-Ford](../bellman-ford/README.md) instead.
- **Lazy deletion:** We don't remove stale entries; instead, we skip them with `if (d > dist[u]) continue`.
- **Undirected graphs:** Add edges in both directions.
- LeetCode #743 "Network Delay Time" is a direct application: return `dist.Skip(1).Max()`.
