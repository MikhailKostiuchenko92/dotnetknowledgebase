# Construct Binary Tree from Preorder and Inorder Traversal

**Source:** LeetCode #105
**Difficulty:** 🟡 Medium
**Topics:** Tree, DFS, HashMap

## Problem Statement

Given two integer arrays `preorder` and `inorder` where:
- `preorder` is the preorder traversal of a binary tree.
- `inorder` is the inorder traversal of the same tree.

Construct and return the binary tree.

## Examples

```
Input:  preorder = [3,9,20,15,7], inorder = [9,3,15,20,7]
Output: [3,9,20,null,null,15,7]

Input:  preorder = [-1], inorder = [-1]
Output: [-1]
```

## Constraints

- `1 <= preorder.Length <= 3000`
- `preorder.Length == inorder.Length`
- `-3000 <= preorder[i], inorder[i] <= 3000`
- All values are **unique**.

---

## Approach: DFS with HashMap — O(n) time, O(n) space ✓

**Key insight:**
- `preorder[0]` is always the root.
- The root's position in `inorder` divides it: elements to its left → left subtree; to its right → right subtree.
- Recursively apply this to each subtree.

Pre-build a `Dictionary<value, index>` of `inorder` to find root positions in O(1).

```csharp
public static TreeNode? BuildTree(int[] preorder, int[] inorder)
{
    // Build index map for O(1) lookup of inorder positions
    var indexMap = new Dictionary<int, int>(inorder.Length);
    for (int i = 0; i < inorder.Length; i++)
        indexMap[inorder[i]] = i;

    return Build(preorder, 0, preorder.Length - 1,
                 inorder,  0, inorder.Length - 1, indexMap);
}

private static TreeNode? Build(
    int[] pre, int preStart, int preEnd,
    int[] ino, int inoStart, int inoEnd,
    Dictionary<int, int> indexMap)
{
    if (preStart > preEnd) return null;

    int rootVal = pre[preStart];
    int rootIdx = indexMap[rootVal]; // position in inorder
    int leftSize = rootIdx - inoStart;

    var root = new TreeNode(rootVal);
    root.left  = Build(pre, preStart + 1, preStart + leftSize,
                       ino, inoStart, rootIdx - 1, indexMap);
    root.right = Build(pre, preStart + leftSize + 1, preEnd,
                       ino, rootIdx + 1, inoEnd, indexMap);
    return root;
}
```

### Walkthrough: `preorder=[3,9,20,15,7]`, `inorder=[9,3,15,20,7]`

```
Root = 3 (pre[0]); rootIdx = 1 in inorder; leftSize = 1 - 0 = 1
  Left subtree:  pre[1..1]=[9],    ino[0..0]=[9]   → node(9)
  Right subtree: pre[2..4]=[20,15,7], ino[2..4]=[15,20,7]
    Root = 20; rootIdx = 3 in inorder; leftSize = 3 - 2 = 1
      Left:  pre[3..3]=[15], ino[2..2]=[15] → node(15)
      Right: pre[4..4]=[7],  ino[4..4]=[7]  → node(7)
```

---

## Complexity Summary

| Approach                | Time | Space |
|-------------------------|------|-------|
| DFS + HashMap           | O(n) | O(n)  |
| DFS without HashMap     | O(n²)| O(n)  |

---

## Interview Tips

- **Build the HashMap first** — this is the key optimisation from O(n²) to O(n).
- Carefully track the `leftSize` to correctly split preorder indices.
- **Common mistake:** Off-by-one errors in `preStart + leftSize` vs `preStart + leftSize + 1`.
- **Follow-up:** *"Construct from Postorder and Inorder."* → LeetCode #106 — same idea, but root = last element of postorder.
- **Follow-up:** *"Construct from Preorder and Postorder."* → LeetCode #889 — less common, requires different handling.
