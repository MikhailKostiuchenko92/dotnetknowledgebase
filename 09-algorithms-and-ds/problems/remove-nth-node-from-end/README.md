# Remove Nth Node From End of List

**Source:** LeetCode #19
**Difficulty:** 🟡 Medium
**Topics:** Linked List, Two-Pointer

## Problem Statement

Given the `head` of a linked list, remove the **n-th node from the end** of the list and return its head.

## Examples

```
Input:  head = 1→2→3→4→5, n = 2
Output: 1→2→3→5   // remove 4 (2nd from end)

Input:  head = [1], n = 1
Output: []

Input:  head = [1,2], n = 1
Output: [1]
```

## Constraints

- Number of nodes in the list: `[1, 30]`
- `0 <= Node.val <= 100`
- `1 <= n <= list length`

---

## Approach 1: Two Pass — O(n) time, O(1) space

First pass: count total length `L`. Second pass: remove node at position `L - n`.

```csharp
public static ListNode? RemoveNthFromEndTwoPass(ListNode? head, int n)
{
    int length = 0;
    for (var curr = head; curr != null; curr = curr.next) length++;

    var dummy = new ListNode(0, head);
    var prev = (ListNode)dummy;
    for (int i = 0; i < length - n; i++) prev = prev.next!;

    prev.next = prev.next!.next; // skip the target node
    return dummy.next;
}
```

---

## Approach 2: One-Pass Two-Pointer — O(n) time, O(1) space ✓ Preferred

Advance `fast` pointer `n + 1` steps ahead of `slow`. When `fast` reaches null, `slow` is right before the node to remove.

```csharp
public static ListNode? RemoveNthFromEnd(ListNode? head, int n)
{
    var dummy = new ListNode(0, head); // dummy before head
    ListNode? slow = dummy, fast = dummy;

    // Advance fast by n+1 steps (one extra so slow stops at the PREV node)
    for (int i = 0; i <= n; i++)
        fast = fast!.next;

    // Move both until fast is null
    while (fast != null)
    {
        slow = slow!.next;
        fast = fast.next;
    }

    // slow is the node before the one to remove
    slow!.next = slow.next!.next;

    return dummy.next;
}
```

### Walkthrough: `1→2→3→4→5`, n=2

```
dummy→1→2→3→4→5
fast advanced 3 steps (n+1=3): fast=3
Both advance until fast=null:
  fast=3→4→5→null (2 more steps): slow=dummy→1→2
slow.next = 4 (the 2nd-from-end), skip it:
  slow.next = slow.next.next = 5
Result: 1→2→3→5 ✓
```

---

## Complexity Summary

| Approach          | Time | Space | Passes |
|-------------------|------|-------|--------|
| Two Pass          | O(n) | O(1)  | 2      |
| One-Pass (two-ptr)| O(n) | O(1)  | 1      |

---

## Interview Tips

- **Dummy node** again — prevents special-casing removal of the head node.
- State the gap logic: *"Keep `fast` exactly `n+1` steps ahead of `slow`. When `fast` hits null, `slow` is right before the target."*
- **Edge cases:** Remove head (`n == list length`) — handled by the dummy node; list of length 1.
- **Common mistake:** Advancing `fast` by `n` instead of `n+1` — `slow` would land on the node to remove rather than its predecessor.
