# Search in a Binary Search Tree

**Source:** LeetCode #700
**Difficulty:** 🟢 Easy
**Topics:** BST, DFS, Recursion

## Problem Statement

Given the `root` of a BST and an integer `val`, find the subtree rooted at the node whose value equals `val`. Return the subtree root. If no such node exists, return `null`.

## Examples

```
Input:  root = [4,2,7,1,3], val = 2
Output: [2,1,3]

Input:  root = [4,2,7,1,3], val = 5
Output: null
```

## Constraints

- `[1, 5000]` nodes; `-10⁷ <= val, Node.val <= 10⁷`; tree is a valid BST; values are unique.

---

## Approach 1: Iterative — O(h) time, O(1) space ✓

```csharp
public static TreeNode? SearchBST(TreeNode? root, int val)
{
    while (root is not null)
    {
        if      (val < root.val) root = root.left;
        else if (val > root.val) root = root.right;
        else                     return root;
    }
    return null;
}
```

## Approach 2: Recursive — O(h) time, O(h) space

```csharp
public static TreeNode? SearchBSTRec(TreeNode? root, int val) =>
    root switch
    {
        null                    => null,
        { val: var v } when val == v => root,
        { val: var v } when val < v  => SearchBSTRec(root.left, val),
        _                            => SearchBSTRec(root.right, val)
    };
```

---

## Complexity Summary

| Approach   | Time | Space |
|------------|------|-------|
| Iterative  | O(h) | O(1)  |
| Recursive  | O(h) | O(h)  |

*h = height; O(log n) for balanced, O(n) worst case.*

---

## Interview Tips

- Always prefer iterative for BST search — no stack overhead.
- `h = O(log n)` only for balanced BSTs; degenerate case is O(n).
- **Follow-up:** *"Insert a value into a BST."* → See [Insert/Delete in BST](../insert-delete-in-bst/README.md).
