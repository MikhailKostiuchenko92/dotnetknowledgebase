# Serialize and Deserialize Binary Tree

**Source:** LeetCode #297
**Difficulty:** 🔴 Hard
**Topics:** Tree, DFS, BFS, Design

## Problem Statement

Design an algorithm to serialize a binary tree to a string and deserialize that string back to the original tree.

There is no restriction on how to do the serialization/deserialization—just ensure `deserialize(serialize(root))` returns the original tree.

## Examples

```
Input:  root = [1,2,3,null,null,4,5]
Output: [1,2,3,null,null,4,5]   // any valid encoding round-trips correctly
```

## Constraints

- Number of nodes: `[0, 10⁴]`
- `-1000 <= Node.val <= 1000`

---

## Approach 1: BFS (Level Order) — O(n) time, O(n) space

Encode level by level using a queue; null children become `"#"`. Deserialize by rebuilding level-by-level.

```csharp
public class BfsCodec
{
    public string Serialize(TreeNode? root)
    {
        if (root is null) return "#";
        var sb = new System.Text.StringBuilder();
        var queue = new Queue<TreeNode?>();
        queue.Enqueue(root);

        while (queue.Count > 0)
        {
            var node = queue.Dequeue();
            if (node is null) { sb.Append("#,"); continue; }
            sb.Append(node.val).Append(',');
            queue.Enqueue(node.left);
            queue.Enqueue(node.right);
        }
        return sb.ToString().TrimEnd(',');
    }

    public TreeNode? Deserialize(string data)
    {
        if (data == "#") return null;
        var tokens = data.Split(',');
        var root = new TreeNode(int.Parse(tokens[0]));
        var queue = new Queue<TreeNode>();
        queue.Enqueue(root);
        int i = 1;

        while (queue.Count > 0 && i < tokens.Length)
        {
            var node = queue.Dequeue();
            if (tokens[i] != "#") { node.left = new TreeNode(int.Parse(tokens[i])); queue.Enqueue(node.left); }
            i++;
            if (i < tokens.Length && tokens[i] != "#") { node.right = new TreeNode(int.Parse(tokens[i])); queue.Enqueue(node.right); }
            i++;
        }
        return root;
    }
}
```

---

## Approach 2: Preorder DFS (Recursive) — O(n) time, O(n) space

Root-first traversal; null = `"#"`. Use a `Queue<string>` as a pointer-like stream during deserialization.

```csharp
public class DfsCodec
{
    public string Serialize(TreeNode? root)
    {
        var sb = new System.Text.StringBuilder();
        void Dfs(TreeNode? node)
        {
            if (node is null) { sb.Append("#,"); return; }
            sb.Append(node.val).Append(',');
            Dfs(node.left);
            Dfs(node.right);
        }
        Dfs(root);
        return sb.ToString().TrimEnd(',');
    }

    public TreeNode? Deserialize(string data)
    {
        var tokens = new Queue<string>(data.Split(','));
        return Rebuild(tokens);
    }

    private static TreeNode? Rebuild(Queue<string> tokens)
    {
        var token = tokens.Dequeue();
        if (token == "#") return null;
        var node = new TreeNode(int.Parse(token));
        node.left  = Rebuild(tokens);
        node.right = Rebuild(tokens);
        return node;
    }
}
```

---

## Complexity Summary

| Approach     | Time | Space |
|--------------|------|-------|
| BFS          | O(n) | O(n)  |
| Preorder DFS | O(n) | O(n)  |

---

## Interview Tips

- DFS is simpler code; BFS matches LeetCode's natural representation.
- **Null markers are essential** — without them, ambiguous when inorder-only (no unique reconstruction).
- Use comma delimiters to handle multi-digit / negative numbers safely.
- **Follow-up:** *"Serialize a BST without null markers."* → Preorder alone is sufficient to reconstruct a BST (no duplicates).
