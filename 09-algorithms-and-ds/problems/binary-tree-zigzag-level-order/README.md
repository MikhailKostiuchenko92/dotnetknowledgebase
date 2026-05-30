# Binary Tree Zigzag Level Order Traversal

**Source:** LeetCode #103
**Difficulty:** 🟡 Medium
**Topics:** Tree, BFS, Deque

## Problem Statement

Given the `root` of a binary tree, return the **zigzag level order traversal** of its nodes' values (i.e., from left to right, then right to left for the next level, and so on).

## Examples

```
Input:  root = [3,9,20,null,null,15,7]
Output: [[3],[20,9],[15,7]]

Input:  root = [1]
Output: [[1]]
```

## Constraints

- Number of nodes: `[0, 2000]`
- `-100 <= Node.val <= 100`

---

## Approach: BFS + Alternate Insert Direction — O(n) time, O(w) space ✓

Same BFS level-order skeleton as [Level Order Traversal](../binary-tree-level-order-traversal/README.md), but use a `bool leftToRight` flag to alternate the insertion direction into the level list.

```csharp
public static IList<IList<int>> ZigzagLevelOrder(TreeNode? root)
{
    var result = new List<IList<int>>();
    if (root == null) return result;

    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    bool leftToRight = true;

    while (queue.Count > 0)
    {
        int levelSize = queue.Count;
        var level = new int[levelSize]; // use array so we can write by index

        for (int i = 0; i < levelSize; i++)
        {
            var node = queue.Dequeue();

            // Write position depends on direction
            int pos = leftToRight ? i : levelSize - 1 - i;
            level[pos] = node.val;

            if (node.left  != null) queue.Enqueue(node.left);
            if (node.right != null) queue.Enqueue(node.right);
        }

        result.Add(level);
        leftToRight = !leftToRight;
    }

    return result;
}
```

### Alternative: Use LinkedList and AddFirst/AddLast

```csharp
var level = new LinkedList<int>();
// ...
if (leftToRight) level.AddLast(node.val);
else             level.AddFirst(node.val);
// ...
result.Add(level.ToList());
```

---

## Complexity Summary

| Approach            | Time | Space |
|---------------------|------|-------|
| BFS + index/deque   | O(n) | O(w)  |

---

## Interview Tips

- Build on [Level Order Traversal](../binary-tree-level-order-traversal/README.md) — the only change is inserting in alternating direction.
- **Array-indexed approach** is cleaner than reversing the list after building it.
- **Even depth:** left→right (level 0, 2, …); **Odd depth:** right→left (level 1, 3, …).
- **Edge cases:** Same as level order — null root, single node, skewed tree.
