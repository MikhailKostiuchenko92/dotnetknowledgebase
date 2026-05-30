# Maximum Depth of Binary Tree

**Source:** LeetCode #104
**Difficulty:** 🟢 Easy
**Topics:** Tree, DFS, BFS

## Problem Statement

Given the `root` of a binary tree, return its **maximum depth** — the number of nodes along the longest path from the root down to the farthest leaf.

## Examples

```
Input:  root = [3,9,20,null,null,15,7]
Output: 3

Input:  root = [1,null,2]
Output: 2
```

## Constraints

- Number of nodes: `[0, 10⁴]`
- `-100 <= Node.val <= 100`

---

## Node Definition

```csharp
public class TreeNode
{
    public int val;
    public TreeNode? left, right;
    public TreeNode(int val = 0, TreeNode? left = null, TreeNode? right = null)
    { this.val = val; this.left = left; this.right = right; }
}
```

---

## Approach 1: DFS Recursive — O(n) time, O(h) space

```csharp
public static int MaxDepth(TreeNode? root)
{
    if (root == null) return 0;
    return 1 + Math.Max(MaxDepth(root.left), MaxDepth(root.right));
}
```

Elegant one-liner. Space is O(h) = O(log n) balanced, O(n) worst case (skewed tree).

---

## Approach 2: BFS (Level Order) — O(n) time, O(w) space

Count the number of levels using a queue. Space is O(w) where w = maximum width (O(n) worst case for a complete binary tree).

```csharp
public static int MaxDepthBFS(TreeNode? root)
{
    if (root == null) return 0;

    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    int depth = 0;

    while (queue.Count > 0)
    {
        int levelSize = queue.Count;
        depth++;

        for (int i = 0; i < levelSize; i++)
        {
            var node = queue.Dequeue();
            if (node.left  != null) queue.Enqueue(node.left);
            if (node.right != null) queue.Enqueue(node.right);
        }
    }

    return depth;
}
```

---

## Approach 3: DFS Iterative — O(n) time, O(h) space

```csharp
public static int MaxDepthDfsIterative(TreeNode? root)
{
    if (root == null) return 0;

    var stack = new Stack<(TreeNode node, int depth)>();
    stack.Push((root, 1));
    int maxDepth = 0;

    while (stack.Count > 0)
    {
        var (node, depth) = stack.Pop();
        maxDepth = Math.Max(maxDepth, depth);
        if (node.left  != null) stack.Push((node.left,  depth + 1));
        if (node.right != null) stack.Push((node.right, depth + 1));
    }

    return maxDepth;
}
```

---

## Complexity Summary

| Approach        | Time | Space |
|-----------------|------|-------|
| DFS Recursive   | O(n) | O(h)  |
| BFS             | O(n) | O(w)  |
| DFS Iterative   | O(n) | O(h)  |

---

## Interview Tips

- The recursive DFS is the expected answer — one clean line after the null check.
- **If asked for iterative:** use the BFS approach to demonstrate level-order traversal.
- **Edge cases:** `null` root (depth 0), single node (depth 1), skewed tree (depth = n).
- **Follow-up:** *"Minimum depth."* → LeetCode #111 — careful: the minimum is the shortest path to a **leaf**, not to any null.
