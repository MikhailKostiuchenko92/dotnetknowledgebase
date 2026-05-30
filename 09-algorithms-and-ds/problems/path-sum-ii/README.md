# Path Sum II

**Source:** LeetCode #113
**Difficulty:** 🟡 Medium
**Topics:** Tree, DFS, Backtracking

## Problem Statement

Given the `root` of a binary tree and an integer `targetSum`, return **all root-to-leaf paths** where the sum of node values equals `targetSum`. A **leaf** is a node with no children.

## Examples

```
Input:  root = [5,4,8,11,null,13,4,7,2,null,null,5,1], targetSum = 22
Output: [[5,4,11,2],[5,8,4,5]]

Input:  root = [1,2,3], targetSum = 5
Output: []

Input:  root = [1,2], targetSum = 0
Output: []
```

## Constraints

- Number of nodes: `[0, 5000]`
- `-1000 <= Node.val <= 1000`
- `-1000 <= targetSum <= 1000`

---

## Approach: DFS Backtracking — O(n²) time worst case, O(h) extra space ✓

Perform DFS, accumulating path nodes. When a leaf is reached, check if the path sum matches. Add a copy of the path to results, then backtrack (remove last node).

```csharp
public static IList<IList<int>> PathSum(TreeNode? root, int targetSum)
{
    var result = new List<IList<int>>();
    var current = new List<int>();
    Dfs(root, targetSum, current, result);
    return result;
}

private static void Dfs(TreeNode? node, int remaining, List<int> current, List<IList<int>> result)
{
    if (node == null) return;

    current.Add(node.val);
    remaining -= node.val;

    if (node.left == null && node.right == null && remaining == 0)
    {
        result.Add(new List<int>(current)); // copy — not a reference!
    }
    else
    {
        Dfs(node.left,  remaining, current, result);
        Dfs(node.right, remaining, current, result);
    }

    current.RemoveAt(current.Count - 1); // backtrack
}
```

> **Why `new List<int>(current)`?** If you add `current` directly, all result entries would share the same list instance, and backtracking would corrupt previously collected results.

### Complexity Note

O(n) for the DFS traversal, but copying paths takes O(h) each time. In the worst case (all paths are valid, like a complete tree with targetSum = path sums), total copy work is O(n · h) = O(n²).

---

## Variant: Path Sum I (Just True/False — LeetCode #112)

```csharp
public static bool HasPathSum(TreeNode? root, int targetSum)
{
    if (root == null) return false;
    if (root.left == null && root.right == null) return root.val == targetSum;
    return HasPathSum(root.left,  targetSum - root.val)
        || HasPathSum(root.right, targetSum - root.val);
}
```

---

## Interview Tips

- **Backtracking pattern:** add to path → recurse → remove from path. Clean and standard.
- **Copy the path** when adding to results — a very common mistake is to add the reference directly.
- **Leaf check:** `left == null && right == null` — not just any null descendant.
- **Edge cases:** Null root (empty result), single-node tree (return it if value equals target), negative values in the path.
- **Follow-up:** *"Path sum counting — paths that don't need to start or end at root/leaf."* → LeetCode #437 — prefix sum + HashMap approach.
