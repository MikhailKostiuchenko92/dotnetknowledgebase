# Course Schedule II

**Source:** LeetCode #210
**Difficulty:** 🟡 Medium
**Topics:** Graph, Topological Sort, DFS, BFS (Kahn's Algorithm)

## Problem Statement

Same as [Course Schedule](../course-schedule/README.md), but return the **ordering** of courses you should take to finish all courses. If impossible, return an empty array.

## Examples

```
Input:  numCourses = 2, prerequisites = [[1,0]]   Output: [0,1]
Input:  numCourses = 4, prerequisites = [[1,0],[2,0],[3,1],[3,2]]
Output: [0,2,1,3] or [0,1,2,3]
Input:  numCourses = 1, prerequisites = []   Output: [0]
```

## Constraints

- Same as Course Schedule.

---

## Approach 1: Kahn's BFS Topological Sort — O(V + E) ✓

```csharp
public static int[] FindOrder(int numCourses, int[][] prerequisites)
{
    var adj     = new List<int>[numCourses];
    var indegree = new int[numCourses];
    for (int i = 0; i < numCourses; i++) adj[i] = [];
    foreach (var e in prerequisites) { adj[e[1]].Add(e[0]); indegree[e[0]]++; }

    var queue = new Queue<int>();
    for (int i = 0; i < numCourses; i++)
        if (indegree[i] == 0) queue.Enqueue(i);

    var order = new List<int>(numCourses);
    while (queue.Count > 0)
    {
        int u = queue.Dequeue();
        order.Add(u);
        foreach (int v in adj[u])
            if (--indegree[v] == 0) queue.Enqueue(v);
    }
    return order.Count == numCourses ? [.. order] : [];
}
```

---

## Approach 2: DFS Post-Order (Reverse Topological) — O(V + E)

Push a node to the result list only after all its neighbors are processed. Reverse the list at the end.

```csharp
public static int[] FindOrderDFS(int numCourses, int[][] prerequisites)
{
    var adj   = new List<int>[numCourses];
    for (int i = 0; i < numCourses; i++) adj[i] = [];
    foreach (var e in prerequisites) adj[e[0]].Add(e[1]);

    var color  = new int[numCourses];
    var result = new List<int>(numCourses);
    bool hasCycle = false;

    void Dfs(int u)
    {
        if (hasCycle || color[u] == 1) { hasCycle = true; return; }
        if (color[u] == 2) return;
        color[u] = 1;
        foreach (int v in adj[u]) Dfs(v);
        color[u] = 2;
        result.Add(u); // post-order
    }

    for (int i = 0; i < numCourses; i++)
        if (color[i] == 0) Dfs(i);

    if (hasCycle) return [];
    result.Reverse();
    return [.. result];
}
```

---

## Complexity Summary

| Approach    | Time     | Space    |
|-------------|----------|----------|
| Kahn's BFS  | O(V + E) | O(V + E) |
| DFS         | O(V + E) | O(V + E) |

---

## Interview Tips

- Kahn's BFS is preferred in practice — straightforward, iterative, and produces the order directly.
- DFS produces **reverse post-order** — don't forget to `Reverse()` at the end.
- **Cycle detection** in DFS: if `color[u] == 1` when entering, it's a cycle. Return early with `hasCycle = true`.
