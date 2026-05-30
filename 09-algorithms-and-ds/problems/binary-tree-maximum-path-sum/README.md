# Binary Tree Maximum Path Sum

**Source:** LeetCode #124
**Difficulty:** 🔴 Hard
**Topics:** Tree, DFS, Dynamic Programming

## Problem Statement

A **path** in a binary tree is a sequence of nodes where each pair of adjacent nodes has an edge connecting them. A node can only appear in the path once. The path does not need to pass through the root.

Given the `root` of a binary tree, return the **maximum path sum** of any non-empty path.

## Examples

```
Input:  root = [1,2,3]          Output: 6   // 2 → 1 → 3
Input:  root = [-10,9,20,null,null,15,7]
Output: 42   // 15 → 20 → 7
```

## Constraints

- Number of nodes: `[1, 3 × 10⁴]`
- `-1000 <= Node.val <= 1000`

---

## Approach: Post-order DFS with Global Maximum — O(n) time, O(h) space ✓

For each node, compute the **maximum gain** it can contribute to a path going *upward* (either to the parent via left or right — not both, since that would branch).

At each node, the **diameter-like sum** through it = `node.val + max(0, leftGain) + max(0, rightGain)` — update the global max. Return only the best single-direction gain to the parent.

```csharp
public static int MaxPathSum(TreeNode? root)
{
    int maxSum = int.MinValue;
    MaxGain(root, ref maxSum);
    return maxSum;
}

private static int MaxGain(TreeNode? node, ref int maxSum)
{
    if (node == null) return 0;

    // Only use a subtree if it contributes positively
    int leftGain  = Math.Max(0, MaxGain(node.left,  ref maxSum));
    int rightGain = Math.Max(0, MaxGain(node.right, ref maxSum));

    // Max path sum through this node (can use both sides)
    maxSum = Math.Max(maxSum, node.val + leftGain + rightGain);

    // Return max gain if extending the path upward (can only go one side)
    return node.val + Math.Max(leftGain, rightGain);
}
```

### Comparison with Diameter Problem

| | [Diameter of Binary Tree](../diameter-of-binary-tree/README.md) | Binary Tree Maximum Path Sum |
|---|---|---|
| Track | Edge count | Node value sum |
| Negative subtree | Always useful (0 edges min) | Skip if negative (use `max(0, gain)`) |
| Update at each node | `left + right` | `node.val + left + right` |
| Return to parent | `1 + max(left, right)` | `node.val + max(left, right)` |

---

## Complexity Summary

| Approach              | Time | Space |
|-----------------------|------|-------|
| Post-order DFS        | O(n) | O(h)  |

---

## Interview Tips

- **`Math.Max(0, gain)`** — clipping negative gains to zero is the key insight. Including a negative subtree hurts the path sum, so we ignore it.
- Initialize `maxSum = int.MinValue` — the tree can have all negative values, so `0` is not a safe default.
- **The path can be a single node** — `maxSum` is updated with `node.val + 0 + 0` for leaf nodes.
- **Walk through** `[-3]` → maxSum = -3 (single negative node).
- **Common mistake:** Returning `node.val + leftGain + rightGain` to the parent — that would create a forked (non-path) structure.
- **Follow-up:** *"Return the actual path nodes."* → Track the path alongside the gain computation.
