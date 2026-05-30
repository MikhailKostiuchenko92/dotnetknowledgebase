# Validate Binary Search Tree

**Source:** LeetCode #98
**Difficulty:** 🟡 Medium
**Topics:** Tree, DFS, In-order Traversal

## Problem Statement

Given the `root` of a binary tree, determine if it is a **valid binary search tree (BST)**.

A valid BST:
- All nodes in the left subtree have values **strictly less than** the node's value.
- All nodes in the right subtree have values **strictly greater than** the node's value.
- Both subtrees must also be valid BSTs.

## Examples

```
Input:  root = [2,1,3]          Output: true
Input:  root = [5,1,4,null,null,3,6]  Output: false
//  Root is 5, right child is 4 (4 < 5 — violates BST property)
```

## Constraints

- Number of nodes: `[1, 10⁴]`
- `-2³¹ <= Node.val <= 2³¹ - 1`

---

## Approach 1: Range Check (DFS with Min/Max) — O(n) time, O(h) space ✓ Preferred

Pass valid range `(min, max)` through DFS. Each node must satisfy `min < node.val < max`.

```csharp
public static bool IsValidBST(TreeNode? root)
    => Validate(root, long.MinValue, long.MaxValue);

private static bool Validate(TreeNode? node, long min, long max)
{
    if (node == null) return true;
    if (node.val <= min || node.val >= max) return false;
    return Validate(node.left,  min,      node.val)
        && Validate(node.right, node.val, max);
}
```

> **Use `long` bounds** — node values can be `int.MinValue`/`int.MaxValue`, so the sentinel bounds need to be outside the `int` range.

---

## Approach 2: In-Order Traversal — O(n) time, O(h) space

In-order traversal of a BST produces a **strictly increasing** sequence. Track the previous value and check monotonicity.

```csharp
public static bool IsValidBSTInorder(TreeNode? root)
{
    long prev = long.MinValue;
    return InOrder(root, ref prev);

    static bool InOrder(TreeNode? node, ref long prev)
    {
        if (node == null) return true;
        if (!InOrder(node.left, ref prev)) return false;
        if (node.val <= prev) return false; // not strictly increasing
        prev = node.val;
        return InOrder(node.right, ref prev);
    }
}
```

---

## Approach 3: Iterative In-Order — O(n) time, O(h) space

```csharp
public static bool IsValidBSTIterative(TreeNode? root)
{
    var stack = new Stack<TreeNode>();
    long prev = long.MinValue;
    var curr = root;

    while (curr != null || stack.Count > 0)
    {
        while (curr != null) { stack.Push(curr); curr = curr.left; }
        curr = stack.Pop();
        if (curr.val <= prev) return false;
        prev = curr.val;
        curr = curr.right;
    }
    return true;
}
```

---

## Complexity Summary

| Approach         | Time | Space |
|------------------|------|-------|
| Range Check DFS  | O(n) | O(h)  |
| In-order DFS     | O(n) | O(h)  |
| In-order iterative| O(n) | O(h) |

---

## Interview Tips

- **Most common pitfall:** Checking only that `left.val < root.val < right.val` for each node without propagating constraints. Example: `[10, 5, 15, null, null, 6, 20]` — node `6` is less than `10` (root) but is in the right subtree, which is invalid.
- The range check approach directly addresses this by propagating bounds down the tree.
- **Use `long` for bounds** — can't use `int.MinValue` as a sentinel if the tree can contain it.
- **Follow-up:** *"Find the closest value to a target in a BST."* → Binary search on BST: go left if `target < node.val`, right otherwise.
