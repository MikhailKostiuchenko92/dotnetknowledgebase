# Reverse Nodes in k-Group

**Source:** LeetCode #25
**Difficulty:** 🔴 Hard
**Topics:** Linked List, Recursion

## Problem Statement

Given the `head` of a linked list, reverse the nodes of the list `k` at a time, and return the modified list.

If the number of nodes is not a multiple of `k`, the remaining nodes at the end are left as-is.

You may not alter the values in the list's nodes, only the nodes themselves may be changed.

## Examples

```
Input:  head = 1→2→3→4→5, k = 2
Output: 2→1→4→3→5

Input:  head = 1→2→3→4→5, k = 3
Output: 3→2→1→4→5
```

## Constraints

- Number of nodes: `[1, 5000]`
- `0 <= Node.val <= 1000`
- `1 <= k <= number of nodes`

---

## Approach: Iterative Group-by-Group Reversal — O(n) time, O(1) space ✓

For each group of `k` nodes:
1. Check if `k` nodes remain (if not, leave as-is).
2. Reverse the `k` nodes.
3. Connect the reversed group to the previous tail and next group's head.

```csharp
public static ListNode? ReverseKGroup(ListNode? head, int k)
{
    var dummy = new ListNode(0, head);
    ListNode prevGroupTail = dummy;

    while (true)
    {
        // Find the k-th node from current position
        ListNode? kthNode = GetKthNode(prevGroupTail, k);
        if (kthNode == null) break; // fewer than k nodes remaining

        ListNode? groupHead = prevGroupTail.next;
        ListNode? nextGroupHead = kthNode.next;

        // Reverse k nodes
        ListNode? prev = nextGroupHead, curr = groupHead;
        for (int i = 0; i < k; i++)
        {
            ListNode? next = curr!.next;
            curr.next = prev;
            prev = curr;
            curr = next;
        }

        // Connect: prevGroupTail → kthNode (new group head), groupHead → nextGroup
        prevGroupTail.next = kthNode; // kthNode is now the head of reversed group
        prevGroupTail = groupHead!;   // groupHead is now the tail of reversed group
    }

    return dummy.next;
}

private static ListNode? GetKthNode(ListNode? curr, int k)
{
    while (curr != null && k > 0) { curr = curr.next; k--; }
    return curr;
}
```

### Walkthrough: `1→2→3→4→5`, k=2

```
Group 1: nodes 1→2, reversed → 2→1; dummy→2→1→(3→4→5)
Group 2: nodes 3→4, reversed → 4→3; dummy→2→1→4→3→(5)
Group 3: only 1 node, fewer than k=2 → leave as-is
Result: 2→1→4→3→5 ✓
```

---

## Recursive Approach — O(n) time, O(n/k) space

```csharp
public static ListNode? ReverseKGroupRecursive(ListNode? head, int k)
{
    var check = head;
    for (int i = 0; i < k; i++)
    {
        if (check == null) return head; // fewer than k nodes remaining
        check = check.next;
    }

    // Reverse k nodes
    ListNode? prev = null, curr = head;
    for (int i = 0; i < k; i++)
    {
        var next = curr!.next;
        curr.next = prev;
        prev = curr;
        curr = next;
    }

    // head is now the tail of this group; connect to next group
    head!.next = ReverseKGroupRecursive(curr, k);
    return prev; // prev is the new head of this group
}
```

---

## Complexity Summary

| Approach   | Time | Space |
|------------|------|-------|
| Iterative  | O(n) | O(1)  |
| Recursive  | O(n) | O(n/k)|

---

## Interview Tips

- **Break into sub-problems:** find k-th node, reverse k nodes, reconnect. Each is simple individually.
- Draw the before/after for a group of k=3 nodes to clarify pointer manipulation.
- **Edge cases:** k=1 (no change), k=n (reverse entire list), list length not divisible by k (last partial group stays).
- Related: [Reverse Linked List](../reverse-linked-list/README.md) — core building block.
