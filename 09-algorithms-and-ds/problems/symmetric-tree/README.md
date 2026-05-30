# Symmetric Tree

**Source:** LeetCode #101
**Difficulty:** 🟢 Easy
**Topics:** Tree, DFS, BFS

## Problem Statement

Given the `root` of a binary tree, check whether it is **a mirror of itself** (i.e., symmetric around its center).

## Examples

```
Input:        1          Output: true
            /   \
           2     2
          / \   / \
         3   4 4   3

Input:        1          Output: false
            /   \
           2     2
            \     \
             3     3
```

## Constraints

- Number of nodes: `[1, 1000]`
- `-100 <= Node.val <= 100`

---

## Approach 1: Recursive DFS — O(n) time, O(h) space ✓

A tree is symmetric if its left subtree is a mirror of its right subtree. Two trees are mirrors if:
1. Their roots have the same value.
2. Each tree's left subtree is a mirror of the other's right subtree.

```csharp
public static bool IsSymmetric(TreeNode? root)
    => IsMirror(root?.left, root?.right);

private static bool IsMirror(TreeNode? left, TreeNode? right)
{
    if (left == null && right == null) return true;
    if (left == null || right == null) return false;
    return left.val == right.val
        && IsMirror(left.left,  right.right)  // outer pair
        && IsMirror(left.right, right.left);  // inner pair
}
```

---

## Approach 2: Iterative BFS — O(n) time, O(w) space

Use a queue, enqueuing nodes in mirror pairs.

```csharp
public static bool IsSymmetricIterative(TreeNode? root)
{
    var queue = new Queue<TreeNode?>();
    queue.Enqueue(root?.left);
    queue.Enqueue(root?.right);

    while (queue.Count > 0)
    {
        var left  = queue.Dequeue();
        var right = queue.Dequeue();

        if (left == null && right == null) continue;
        if (left == null || right == null) return false;
        if (left.val != right.val)         return false;

        // Enqueue in mirror order
        queue.Enqueue(left.left);   queue.Enqueue(right.right);
        queue.Enqueue(left.right);  queue.Enqueue(right.left);
    }

    return true;
}
```

---

## Complexity Summary

| Approach      | Time | Space |
|---------------|------|-------|
| DFS Recursive | O(n) | O(h)  |
| BFS Iterative | O(n) | O(n)  |

---

## Interview Tips

- **The key insight:** outer pairs and inner pairs must mirror each other — state this before coding.
- **Null handling:** Both null = ok; one null = fail; neither null = check values.
- **Common mistake:** Comparing `left.left` with `right.left` instead of `right.right` (forget mirror order).
- **Edge cases:** Single-node tree (trivially symmetric), null root (handle with `?.`).
- **Related:** [Invert Binary Tree](../invert-binary-tree/README.md) — if you invert the tree and it equals the original, it's symmetric (but slower to compute).
