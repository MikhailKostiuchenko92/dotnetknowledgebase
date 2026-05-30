# Invert Binary Tree

**Source:** LeetCode #226
**Difficulty:** 🟢 Easy
**Topics:** Tree, DFS, BFS

## Problem Statement

Given the `root` of a binary tree, invert the tree (mirror it), and return its root.

## Examples

```
Input:        4            Output:       4
            /   \                      /   \
           2     7                    7     2
          / \   / \                  / \   / \
         1   3 6   9                9   6 3   1
```

## Constraints

- Number of nodes: `[0, 100]`
- `-100 <= Node.val <= 100`

---

## Approach 1: DFS Recursive — O(n) time, O(h) space ✓

```csharp
public static TreeNode? InvertTree(TreeNode? root)
{
    if (root == null) return null;

    // Swap children
    (root.left, root.right) = (root.right, root.left);

    // Recursively invert subtrees
    InvertTree(root.left);
    InvertTree(root.right);

    return root;
}
```

Or even more concise:

```csharp
public static TreeNode? InvertTreeConcise(TreeNode? root)
{
    if (root == null) return null;
    root.left  = InvertTreeConcise(root.right);
    root.right = InvertTreeConcise(root.left);  // BUG: left already modified!
    return root;
}
```

> **Don't do the "concise" version above!** Assigning `root.left` first corrupts the original `root.left` reference before using it for `root.right`. Always save originals or use tuple swap.

---

## Approach 2: BFS Iterative — O(n) time, O(w) space

```csharp
public static TreeNode? InvertTreeBFS(TreeNode? root)
{
    if (root == null) return null;

    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);

    while (queue.Count > 0)
    {
        var node = queue.Dequeue();
        (node.left, node.right) = (node.right, node.left);
        if (node.left  != null) queue.Enqueue(node.left);
        if (node.right != null) queue.Enqueue(node.right);
    }

    return root;
}
```

---

## Complexity Summary

| Approach        | Time | Space |
|-----------------|------|-------|
| DFS Recursive   | O(n) | O(h)  |
| BFS Iterative   | O(n) | O(w)  |

---

## Interview Tips

- The recursive approach is the textbook answer — short and clean.
- **Use tuple swap `(a, b) = (b, a)`** — shows modern C# knowledge and avoids a temp variable.
- **Edge cases:** `null` root, single node (no children to swap), already symmetric tree.
- **Famous context:** This problem is often cited because [Max Howell was rejected by Google](https://twitter.com/mxcl/status/608682016205344768) for not solving it in an interview despite creating Homebrew — used as a commentary on whiteboard interviews.
