# Insert and Delete in a BST

**Source:** LeetCode #701 (Insert), #450 (Delete)
**Difficulty:** 🟡 Medium
**Topics:** BST, Recursion

## Problem Statement

**Insert:** Given the `root` of a BST and a value `val`, insert the value into the BST and return the (possibly new) root. All values are unique.

**Delete:** Given the `root` of a BST and a key, delete the node with that key from the BST and return the updated root.

## Examples

```
Insert: root = [4,2,7,1,3], val = 5  →  [4,2,7,1,3,5]
Delete: root = [5,3,6,2,4,null,7], key = 3  →  [5,4,6,2,null,null,7]
```

---

## Insert — O(h) time, O(h) space

```csharp
public static TreeNode Insert(TreeNode? root, int val)
{
    if (root is null) return new TreeNode(val);

    if (val < root.val)
        root.left  = Insert(root.left, val);
    else
        root.right = Insert(root.right, val);

    return root;
}
```

---

## Delete — O(h) time, O(h) space

Three cases:
1. Node is a **leaf** → return `null`.
2. Node has **one child** → return that child.
3. Node has **two children** → replace value with in-order successor (smallest in right subtree), then delete that successor from the right subtree.

```csharp
public static TreeNode? Delete(TreeNode? root, int key)
{
    if (root is null) return null;

    if (key < root.val)
        root.left  = Delete(root.left, key);
    else if (key > root.val)
        root.right = Delete(root.right, key);
    else
    {
        // Found: handle the 3 cases
        if (root.left  is null) return root.right;
        if (root.right is null) return root.left;

        // Two children: find in-order successor (min of right subtree)
        int successor = FindMin(root.right);
        root.val   = successor;
        root.right = Delete(root.right, successor);
    }
    return root;
}

private static int FindMin(TreeNode node)
{
    while (node.left is not null) node = node.left;
    return node.val;
}
```

---

## Complexity Summary

| Operation | Time | Space |
|-----------|------|-------|
| Insert    | O(h) | O(h)  |
| Delete    | O(h) | O(h)  |

*h = O(log n) balanced, O(n) degenerate.*

---

## Interview Tips

- **Deletion with two children** is the tricky part — choose the in-order successor (min of right) OR predecessor (max of left); both are valid.
- Always return the node from recursive calls and reassign `root.left/right`.
- **Follow-up:** *"How do self-balancing BSTs (AVL, Red-Black) maintain O(log n) height?"*
