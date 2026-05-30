# Lowest Common Ancestor of a Binary Tree

**Source:** LeetCode #236
**Difficulty:** 🟡 Medium
**Topics:** Tree, DFS, Post-order

## Problem Statement

Given a **binary tree** (not necessarily a BST), find the **lowest common ancestor (LCA)** of two given nodes `p` and `q`. The LCA is the lowest node that has both `p` and `q` as descendants.

## Examples

```
Input:  tree = [3,5,1,6,2,0,8,null,null,7,4], p=5, q=1
Output: 3

Input:  Same tree, p=5, q=4
Output: 5   // 5 is an ancestor of 4
```

## Constraints

- Number of nodes: `[2, 10⁵]`
- `-10⁹ <= Node.val <= 10⁹`
- All node values are **unique**.
- `p` and `q` are different nodes and both exist in the tree.

---

## Approach: Post-order DFS — O(n) time, O(h) space ✓

Recursively search left and right subtrees. The LCA is:
- The current node, if it equals `p` or `q`.
- The current node, if both left and right subtrees return non-null (p and q are in different subtrees).
- The non-null child, if only one subtree contains a target.

```csharp
public static TreeNode? LowestCommonAncestor(TreeNode? root, TreeNode p, TreeNode q)
{
    if (root == null)        return null;  // base: not found
    if (root == p || root == q) return root; // found p or q

    TreeNode? left  = LowestCommonAncestor(root.left,  p, q);
    TreeNode? right = LowestCommonAncestor(root.right, p, q);

    if (left != null && right != null)
        return root;  // p and q are in different subtrees → root is LCA

    return left ?? right; // propagate the found node upward
}
```

### Why this works

- If `p` is in the left and `q` is in the right (or vice versa), both subtrees return non-null → current node is LCA.
- If both are on the same side, only one subtree returns non-null → that's the LCA (the deeper node that first encountered both).
- The first returned node is always the shallowest common ancestor.

---

## Complexity Summary

| Approach    | Time | Space |
|-------------|------|-------|
| Post-order  | O(n) | O(h)  |

---

## Interview Tips

- **Distinguish from BST LCA** ([LCA of BST](../lowest-common-ancestor-bst/README.md)) — that uses O(h) time by exploiting ordering. This general version needs O(n) because we must search everywhere.
- **The base cases matter:** returning `root` when `root == p || root == q` is the key — it means "I found one of the targets" and propagates it up.
- Walk through the case where `p` is an ancestor of `q` — `p` is returned from the left/right subtree before reaching `q`, and that's correct (LCA = `p` itself).
- **Edge cases:** `p` or `q` is root (answer = root), `p` and `q` are direct parent-child.
