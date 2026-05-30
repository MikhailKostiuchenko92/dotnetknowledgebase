# Course Schedule

**Source:** LeetCode #207
**Difficulty:** 🟡 Medium
**Topics:** Graph, Topological Sort, DFS, BFS (Kahn's Algorithm)

## Problem Statement

There are `numCourses` courses labeled `0` to `numCourses - 1`. You are given an array `prerequisites` where `prerequisites[i] = [ai, bi]` means you must take course `bi` before course `ai`.

Return `true` if you can finish all courses, `false` otherwise (i.e., detect a cycle in a directed graph).

## Examples

```
Input:  numCourses = 2, prerequisites = [[1,0]]   Output: true
Input:  numCourses = 2, prerequisites = [[1,0],[0,1]]   Output: false
```

## Constraints

- `1 <= numCourses <= 2000`; `0 <= prerequisites.Length <= 5000`; no self-loops or duplicate edges.

---

## Approach 1: DFS Cycle Detection — O(V + E) time, O(V + E) space

Use 3-color marking: WHITE (0) = unvisited, GRAY (1) = in current path, BLACK (2) = done.
If we reach a GRAY node, a back-edge (cycle) is found.

```csharp
public static bool CanFinish(int numCourses, int[][] prerequisites)
{
    var adj   = new List<int>[numCourses];
    for (int i = 0; i < numCourses; i++) adj[i] = [];
    foreach (var e in prerequisites) adj[e[0]].Add(e[1]);

    var color = new int[numCourses]; // 0=white, 1=gray, 2=black

    bool HasCycle(int u)
    {
        color[u] = 1; // mark in-progress
        foreach (int v in adj[u])
        {
            if (color[v] == 1) return true;  // back edge
            if (color[v] == 0 && HasCycle(v)) return true;
        }
        color[u] = 2; // fully processed
        return false;
    }

    for (int i = 0; i < numCourses; i++)
        if (color[i] == 0 && HasCycle(i)) return false;

    return true;
}
```

---

## Approach 2: Kahn's BFS (Topological Sort) — O(V + E) time, O(V + E) space

Build in-degree array. Enqueue all nodes with in-degree 0. Process BFS; decrement neighbors' in-degrees. If all nodes get processed, no cycle.

```csharp
public static bool CanFinishKahn(int numCourses, int[][] prerequisites)
{
    var adj     = new List<int>[numCourses];
    var indegree = new int[numCourses];
    for (int i = 0; i < numCourses; i++) adj[i] = [];
    foreach (var e in prerequisites) { adj[e[1]].Add(e[0]); indegree[e[0]]++; }

    var queue = new Queue<int>();
    for (int i = 0; i < numCourses; i++)
        if (indegree[i] == 0) queue.Enqueue(i);

    int processed = 0;
    while (queue.Count > 0)
    {
        int u = queue.Dequeue();
        processed++;
        foreach (int v in adj[u])
            if (--indegree[v] == 0) queue.Enqueue(v);
    }
    return processed == numCourses;
}
```

---

## Complexity Summary

| Approach        | Time      | Space     |
|-----------------|-----------|-----------|
| DFS (3-color)   | O(V + E)  | O(V + E)  |
| Kahn's BFS      | O(V + E)  | O(V + E)  |

---

## Interview Tips

- **Gray = cycle** in DFS — always distinguish *currently in the call stack* from *already visited*.
- Kahn's is often easier to reason about iteratively and naturally produces a topological order.
- **Follow-up:** *"Return the actual course order."* → See [Course Schedule II](../course-schedule-ii/README.md).
