# Balance a BST

**Source:** LeetCode #1382
**Difficulty:** 🟡 Medium
**Topics:** BST, DFS, Divide and Conquer

## Problem Statement

Given the `root` of a BST, return a **balanced** BST with the same node values. If there is more than one answer, return any.

A balanced BST is one where the depth of the two subtrees of every node never differs by more than one.

## Examples

```
Input:  root = [1,null,2,null,3,null,4]   (degenerate right chain)
Output: [2,1,3,null,null,null,4]
```

## Constraints

- `[1, 10⁴]` nodes; `1 <= Node.val <= 10⁵`; `tree is a valid BST.`

---

## Approach: In-Order + Sorted Array to BST — O(n) time, O(n) space ✓

1. **Flatten** the BST to a sorted list via in-order traversal.
2. **Rebuild** a height-balanced BST from the sorted list (same as [Convert Sorted Array to BST](../convert-sorted-array-to-bst/README.md)).

```csharp
public static TreeNode BalanceBST(TreeNode root)
{
    var sortedVals = new List<int>();
    InOrder(root, sortedVals);
    return Build(sortedVals, 0, sortedVals.Count - 1)!;
}

private static void InOrder(TreeNode? node, List<int> result)
{
    if (node is null) return;
    InOrder(node.left, result);
    result.Add(node.val);
    InOrder(node.right, result);
}

private static TreeNode? Build(List<int> vals, int left, int right)
{
    if (left > right) return null;
    int mid = left + (right - left) / 2;
    var node = new TreeNode(vals[mid]);
    node.left  = Build(vals, left, mid - 1);
    node.right = Build(vals, mid + 1, right);
    return node;
}
```

---

## Complexity Summary

| Phase        | Time | Space |
|--------------|------|-------|
| In-order DFS | O(n) | O(n)  |
| Build BST    | O(n) | O(log n) stack |
| **Total**    | **O(n)** | **O(n)** |

---

## Interview Tips

- Two-pass solution is clean and obvious; mention it up front, then offer to discuss a one-pass DSW (Day–Stout–Warren) algorithm if asked for O(1) extra space.
- **Follow-up:** *"Can you do it in O(1) extra space (not counting the tree itself)?"* → DSW algorithm uses tree rotations; very rarely asked.
