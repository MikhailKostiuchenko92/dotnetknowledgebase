# Clone Graph

**Source:** LeetCode #133
**Difficulty:** 🟡 Medium
**Topics:** Graph, DFS, BFS, HashMap

## Problem Statement

Given a reference to a node in a **connected undirected graph**, return a **deep copy** (clone) of the graph. Each node contains an integer `val` and a list of its neighbors.

```csharp
public class Node
{
    public int val;
    public IList<Node> neighbors;
}
```

## Examples

```
Input:  adjList = [[2,4],[1,3],[2,4],[1,3]]   (4 nodes)
Output: deep-copied [[2,4],[1,3],[2,4],[1,3]]

Input:  [] (empty)   Output: null
```

## Constraints

- `[0, 100]` nodes; `1 <= Node.val <= 100`; node values are unique.

---

## Approach 1: DFS + HashMap — O(n) time, O(n) space ✓

Use a `Dictionary<Node, Node>` to map original → clone, preventing infinite loops on cycles.

```csharp
public static Node? CloneGraph(Node? node)
{
    if (node is null) return null;
    var visited = new Dictionary<Node, Node>();
    return Dfs(node, visited);
}

private static Node Dfs(Node node, Dictionary<Node, Node> visited)
{
    if (visited.TryGetValue(node, out var clone)) return clone;

    clone = new Node(node.val);
    visited[node] = clone; // register BEFORE recursing (handles cycles)

    foreach (var neighbor in node.neighbors)
        clone.neighbors.Add(Dfs(neighbor, visited));

    return clone;
}
```

---

## Approach 2: BFS + HashMap — O(n) time, O(n) space

```csharp
public static Node? CloneGraphBFS(Node? node)
{
    if (node is null) return null;
    var visited = new Dictionary<Node, Node>();
    var queue   = new Queue<Node>();

    var rootClone = new Node(node.val);
    visited[node] = rootClone;
    queue.Enqueue(node);

    while (queue.Count > 0)
    {
        var curr = queue.Dequeue();
        foreach (var neighbor in curr.neighbors)
        {
            if (!visited.ContainsKey(neighbor))
            {
                visited[neighbor] = new Node(neighbor.val);
                queue.Enqueue(neighbor);
            }
            visited[curr].neighbors.Add(visited[neighbor]);
        }
    }
    return rootClone;
}
```

---

## Complexity Summary

| Approach | Time | Space |
|----------|------|-------|
| DFS      | O(n + e) | O(n) |
| BFS      | O(n + e) | O(n) |

*n = nodes, e = edges.*

---

## Interview Tips

- **Register the clone before recursing** — critical to break cycles. A common mistake is to create the clone and immediately recurse without storing it in `visited` first.
- The pattern `if (visited.TryGetValue(node, out var clone)) return clone;` memoises visited nodes.
- **Follow-up:** *"What if nodes can have arbitrary data types as values?"* → Use a generic deep-copy approach.
