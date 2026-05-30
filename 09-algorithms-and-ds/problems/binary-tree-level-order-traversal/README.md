# Binary Tree Level Order Traversal

**Source:** LeetCode #102
**Difficulty:** 🟡 Medium
**Topics:** Tree, BFS, Queue

## Problem Statement

Given the `root` of a binary tree, return the **level order traversal** of its nodes' values (i.e., from left to right, level by level).

## Examples

```
Input:  root = [3,9,20,null,null,15,7]
Output: [[3],[9,20],[15,7]]

Input:  root = [1]
Output: [[1]]

Input:  root = []
Output: []
```

## Constraints

- Number of nodes: `[0, 2000]`
- `-1000 <= Node.val <= 1000`

---

## Approach: BFS with Level Snapshot — O(n) time, O(w) space ✓

Use a queue. At the start of each iteration, capture the current queue size — this is the number of nodes in the current level. Process exactly that many nodes, then move to the next level.

```csharp
public static IList<IList<int>> LevelOrder(TreeNode? root)
{
    var result = new List<IList<int>>();
    if (root == null) return result;

    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);

    while (queue.Count > 0)
    {
        int levelSize = queue.Count; // snapshot current level size
        var level = new List<int>(levelSize);

        for (int i = 0; i < levelSize; i++)
        {
            var node = queue.Dequeue();
            level.Add(node.val);
            if (node.left  != null) queue.Enqueue(node.left);
            if (node.right != null) queue.Enqueue(node.right);
        }

        result.Add(level);
    }

    return result;
}
```

### Why snapshot `queue.Count`?

At the moment we start a level, the queue contains exactly the nodes of that level. Capturing the count before enqueuing children ensures we process only this level's nodes in the inner loop.

---

## DFS Approach (Alternative)

BFS is the natural fit, but you can also do it recursively with DFS by passing the depth as a parameter:

```csharp
public static IList<IList<int>> LevelOrderDFS(TreeNode? root)
{
    var result = new List<IList<int>>();
    Dfs(root, 0, result);
    return result;

    static void Dfs(TreeNode? node, int depth, List<IList<int>> res)
    {
        if (node == null) return;
        if (depth == res.Count) res.Add(new List<int>()); // new level
        res[depth].Add(node.val);
        Dfs(node.left,  depth + 1, res);
        Dfs(node.right, depth + 1, res);
    }
}
```

---

## Complexity Summary

| Approach  | Time | Space |
|-----------|------|-------|
| BFS       | O(n) | O(w)  |
| DFS       | O(n) | O(h)  |

*w = maximum width (up to n/2 for last level of complete tree)*

---

## Interview Tips

- **BFS is the canonical approach** — level order and BFS are synonymous for trees.
- The `levelSize` snapshot trick is fundamental — know it cold for all level-order variants.
- **Variations that use this exact pattern:**
  - [Zigzag Level Order](../binary-tree-zigzag-level-order/README.md) — alternate direction per level.
  - Right Side View — take last element of each level.
  - Average of Levels — average the level list.
  - Level with Most Nodes — max level size.
- **Edge cases:** Empty tree, single node, unbalanced tree.
