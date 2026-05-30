# Kth Smallest Element in a BST

**Source:** LeetCode #230
**Difficulty:** 🟡 Medium
**Topics:** BST, DFS, In-order Traversal

## Problem Statement

Given the `root` of a BST and an integer `k`, return the `k`th smallest value (1-indexed) of all the values of the nodes in the tree.

## Examples

```
Input:  root = [3,1,4,null,2], k = 1    Output: 1
Input:  root = [5,3,6,2,4,null,null,1], k = 3   Output: 3
```

## Constraints

- `1 <= k <= n <= 10⁴`; `-10⁴ <= Node.val <= 10⁴`

---

## Approach 1: Iterative In-Order (Morris-free) — O(h + k) time, O(h) space ✓

In-order traversal of a BST yields values in sorted ascending order. Stop as soon as the k-th value is visited.

```csharp
public static int KthSmallest(TreeNode? root, int k)
{
    var stack = new Stack<TreeNode>();
    var node = root;

    while (node is not null || stack.Count > 0)
    {
        // Go as far left as possible
        while (node is not null) { stack.Push(node); node = node.left; }

        node = stack.Pop();
        if (--k == 0) return node.val; // k-th in-order node

        node = node.right;
    }
    return -1; // k > n, shouldn't happen per constraints
}
```

## Approach 2: Recursive In-Order — O(n) time, O(n) space

```csharp
public static int KthSmallestRec(TreeNode? root, int k)
{
    int result = 0, count = 0;
    void InOrder(TreeNode? node)
    {
        if (node is null || count >= k) return;
        InOrder(node.left);
        if (++count == k) { result = node.val; return; }
        InOrder(node.right);
    }
    InOrder(root);
    return result;
}
```

---

## Complexity Summary

| Approach              | Time     | Space |
|-----------------------|----------|-------|
| Iterative in-order    | O(h + k) | O(h)  |
| Recursive in-order    | O(n)     | O(n)  |

---

## Interview Tips

- **In-order = sorted** is the key BST insight — memorise this.
- If the BST is frequently modified and you need frequent kth-smallest queries, augment each node with a `subtreeSize` field for O(log n) lookup.
- **Follow-up:** *"What if the BST is modified often?"* → Augmented BST / order-statistics tree.
