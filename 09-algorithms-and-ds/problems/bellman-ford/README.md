# Bellman-Ford Algorithm

**Source:** Classic algorithm / LeetCode #743, #787
**Difficulty:** 🔴 Hard
**Topics:** Graph, Dynamic Programming, Shortest Path

## Problem Statement

Given a directed weighted graph with `n` nodes and edges `[u, v, w]` (may include negative weights), find the shortest path from source `src` to all other nodes. Return `int.MaxValue` for unreachable nodes. Detect negative-weight cycles.

## Examples

```
n = 5, src = 0
edges = [[0,1,4],[0,2,1],[2,1,2],[1,3,1],[3,4,3]]
Output: [0, 3, 1, 4, 7]
```

## Constraints

- May have **negative edge weights**; must detect negative cycles.

---

## Approach: Bellman-Ford — O(V · E) time, O(V) space ✓

Relax all edges `V - 1` times. On the V-th pass, if any edge is still relaxable → negative cycle.

```csharp
public static int[] BellmanFord(int n, int[][] edges, int src)
{
    var dist = new long[n]; // use long to detect overflow safely
    Array.Fill(dist, long.MaxValue / 2); // half to avoid overflow on addition
    dist[src] = 0;

    // Relax V - 1 times
    for (int i = 0; i < n - 1; i++)
    {
        foreach (var e in edges)
        {
            int u = e[0], v = e[1], w = e[2];
            if (dist[u] + w < dist[v])
                dist[v] = dist[u] + w;
        }
    }

    // Detect negative cycles (V-th pass)
    foreach (var e in edges)
    {
        int u = e[0], v = e[1], w = e[2];
        if (dist[u] + w < dist[v])
            throw new InvalidOperationException("Negative cycle detected");
    }

    return dist.Select(d => d >= int.MaxValue / 2 ? int.MaxValue : (int)d).ToArray();
}
```

### Why V - 1 passes?

The shortest path in a graph with no negative cycles has at most `V - 1` edges. After `V - 1` relaxations, all shortest paths are found. The V-th relaxation can only improve a distance if there's a negative cycle.

---

## Comparison: Dijkstra vs Bellman-Ford

| Feature              | Dijkstra           | Bellman-Ford      |
|----------------------|--------------------|-------------------|
| Negative edges       | ❌ No              | ✅ Yes            |
| Negative cycles      | ❌ No (incorrect)  | ✅ Detects them   |
| Time complexity      | O((V+E) log V)     | O(V · E)          |
| Space                | O(V + E)           | O(V)              |
| Best for             | Dense graphs, no neg. | Negative weights |

---

## Complexity Summary

| Approach      | Time     | Space |
|---------------|----------|-------|
| Bellman-Ford  | O(V · E) | O(V)  |

---

## Interview Tips

- Use `long` for distances to avoid integer overflow when summing negative/large weights.
- **`long.MaxValue / 2`** as infinity — `long.MaxValue + w` would overflow.
- **LeetCode #787** ("Cheapest Flights Within K Stops") is Bellman-Ford with at most `k+1` hops — only run `k+1` relaxation passes.
