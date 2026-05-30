# Diameter of Binary Tree

**Source:** LeetCode #543
**Difficulty:** 🟡 Medium
**Topics:** Tree, DFS

## Problem Statement

Given the `root` of a binary tree, return the **length of the diameter** — the length of the longest path between any two nodes. The path does not need to pass through the root. Length = number of edges.

## Examples

```
Input:  root = [1,2,3,4,5]       Output: 3
//  Longest path: [4,2,1,3] or [5,2,1,3] — 3 edges

Input:  root = [1,2]             Output: 1
```

## Constraints

- Number of nodes: `[1, 10⁴]`
- `-100 <= Node.val <= 100`

---

## Approach: DFS with Global Maximum — O(n) time, O(h) space ✓

For each node, the diameter through it = `height(left) + height(right)`. Compute heights recursively and track the maximum diameter seen.

```csharp
public static int DiameterOfBinaryTree(TreeNode? root)
{
    int maxDiameter = 0;
    Height(root, ref maxDiameter);
    return maxDiameter;
}

private static int Height(TreeNode? node, ref int maxDiameter)
{
    if (node == null) return 0;

    int leftHeight  = Height(node.left,  ref maxDiameter);
    int rightHeight = Height(node.right, ref maxDiameter);

    // Diameter through this node
    maxDiameter = Math.Max(maxDiameter, leftHeight + rightHeight);

    // Return height of this subtree
    return 1 + Math.Max(leftHeight, rightHeight);
}
```

### Key Insight

The longest path either **passes through a node** (left height + right height) or lies entirely within one subtree. By updating `maxDiameter` at every node, we capture all possibilities in a single DFS pass.

> The diameter does **not** have to pass through the root. This is a common misconception.

---

## Complexity Summary

| Approach               | Time | Space |
|------------------------|------|-------|
| DFS with global max    | O(n) | O(h)  |

---

## Interview Tips

- **State the insight:** *"The diameter through any node is leftHeight + rightHeight. I'll compute heights recursively while tracking the max."*
- Using `ref int maxDiameter` keeps the solution clean without a class-level field.
- **Common mistake:** Computing diameter only at the root — misses paths that don't pass through the root.
- **Edge cases:** Single node (diameter 0), two nodes (diameter 1), a straight line of nodes (diameter = n-1).
- **Follow-up:** *"Diameter of N-ary tree."* → Same approach — sum all children's heights at each node.
- **Related:** [Binary Tree Maximum Path Sum](../binary-tree-maximum-path-sum/README.md) — same structure, maximise sum instead of count.
