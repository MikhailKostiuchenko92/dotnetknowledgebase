# Lowest Common Ancestor of a BST

**Source:** LeetCode #235
**Difficulty:** 🟡 Medium
**Topics:** Tree, BST, DFS

## Problem Statement

Given a BST, find the **lowest common ancestor (LCA)** of two given nodes `p` and `q`.

The LCA is the lowest node that has both `p` and `q` as descendants (a node can be a descendant of itself).

## Examples

```
Input:  BST root = [6,2,8,0,4,7,9,null,null,3,5], p=2, q=8
Output: 6   // LCA of 2 and 8 is the root 6

Input:  Same tree, p=2, q=4
Output: 2   // LCA of 2 and 4 is 2 (2 is ancestor of 4)
```

## Constraints

- Number of nodes: `[2, 10⁵]`
- `-10⁹ <= Node.val <= 10⁹`
- All node values are unique.
- `p != q`; both `p` and `q` exist in the BST.

---

## Approach 1: Iterative (Leverages BST Property) — O(h) time, O(1) space ✓

In a BST, if both `p` and `q` are less than `current`, go left. If both are greater, go right. Otherwise, `current` is the LCA (they split here).

```csharp
public static TreeNode? LowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q)
{
    TreeNode? curr = root;

    while (curr != null)
    {
        if (p.val < curr.val && q.val < curr.val)
            curr = curr.left;            // both in left subtree
        else if (p.val > curr.val && q.val > curr.val)
            curr = curr.right;           // both in right subtree
        else
            return curr;                 // split point = LCA
    }

    return null; // unreachable if p and q are guaranteed in tree
}
```

---

## Approach 2: Recursive — O(h) time, O(h) space

```csharp
public static TreeNode? LowestCommonAncestorRecursive(TreeNode root, TreeNode p, TreeNode q)
{
    if (p.val < root.val && q.val < root.val)
        return LowestCommonAncestorRecursive(root.left!, p, q);
    if (p.val > root.val && q.val > root.val)
        return LowestCommonAncestorRecursive(root.right!, p, q);
    return root; // split point
}
```

---

## Complexity Summary

| Approach   | Time | Space |
|------------|------|-------|
| Iterative  | O(h) | O(1)  |
| Recursive  | O(h) | O(h)  |

*h = height = O(log n) balanced, O(n) worst case*

---

## Interview Tips

- **Use the BST property** — this is much simpler than the general binary tree LCA problem.
- The split point insight: when `p` and `q` are on different sides (or one is the current node), you've found the LCA.
- **Distinguish from the general case:** [LCA of Binary Tree](../lowest-common-ancestor-binary-tree/README.md) doesn't have BST ordering and requires a different approach.
- **Edge case:** One of `p` or `q` is the LCA itself (e.g., `p=2, q=4` → LCA is `2`). Handled correctly because when `curr.val == p.val`, neither condition is satisfied, and we return `curr`.
