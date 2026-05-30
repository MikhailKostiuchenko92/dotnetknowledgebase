# Convert Sorted Array to Binary Search Tree

**Source:** LeetCode #108
**Difficulty:** 🟢 Easy
**Topics:** Array, Divide and Conquer, Tree

## Problem Statement

Given an integer array `nums` sorted in ascending order, convert it to a **height-balanced** BST. A height-balanced binary tree is one where the depth of the two subtrees of every node never differs by more than one.

## Examples

```
Input:  nums = [-10,-3,0,5,9]
Output: [0,-3,9,-10,null,5]   // or [0,-10,5,null,-3,null,9]

Input:  nums = [1,3]
Output: [3,1]   // or [1,null,3]
```

## Constraints

- `1 <= nums.Length <= 10⁴`; `-10⁴ <= nums[i] <= 10⁴`; `nums` is sorted ascending with distinct values.

---

## Approach: Divide and Conquer (Middle as Root) — O(n) time, O(log n) space ✓

Always pick the **middle element** as the root of each subtree. Recurse on the left half → left subtree; right half → right subtree. This guarantees height-balanced result.

```csharp
public static TreeNode? SortedArrayToBST(int[] nums)
    => Build(nums, 0, nums.Length - 1);

private static TreeNode? Build(int[] nums, int left, int right)
{
    if (left > right) return null;

    int mid  = left + (right - left) / 2; // avoid overflow
    var node = new TreeNode(nums[mid]);
    node.left  = Build(nums, left,    mid - 1);
    node.right = Build(nums, mid + 1, right);
    return node;
}
```

### Walkthrough: `[-10,-3,0,5,9]`

```
mid=2 (0) → root
  left:  [-10,-3]  mid=0 (-10) → left child, right child (-3)
  right: [5,9]     mid=3 (5)   → left child (null), right child (9)
```

---

## Complexity Summary

| Approach              | Time | Space   |
|-----------------------|------|---------|
| Divide and Conquer    | O(n) | O(log n)|

Space is the recursion stack depth, O(log n) for balanced.

---

## Interview Tips

- `mid = left + (right - left) / 2` — safer than `(left + right) / 2` (avoids overflow even though `int` is 32-bit here).
- Result is not unique — any middle choice that keeps balance is valid.
- **Related:** [Balance a BST](../balance-a-bst/README.md) — takes an existing unbalanced BST and rebalances it.
