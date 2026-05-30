# Reverse a Singly Linked List

**Source:** LeetCode #206
**Difficulty:** 🟢 Easy
**Topics:** Linked List, Two-Pointer

## Problem Statement

Given the `head` of a singly linked list, reverse the list and return the reversed list's head.

## Examples

```
Input:  1 → 2 → 3 → 4 → 5 → null
Output: 5 → 4 → 3 → 2 → 1 → null

Input:  1 → 2 → null
Output: 2 → 1 → null

Input:  null
Output: null
```

## Constraints

- Number of nodes in the list: `[0, 5000]`
- `-5000 <= Node.val <= 5000`

---

## Node Definition

```csharp
public class ListNode
{
    public int val;
    public ListNode? next;
    public ListNode(int val = 0, ListNode? next = null) { this.val = val; this.next = next; }
}
```

---

## Approach 1: Iterative — O(n) time, O(1) space ✓ Preferred

Use three pointers: `prev`, `curr`, `next`. Re-point each node's `next` to its predecessor.

```csharp
public static ListNode? Reverse(ListNode? head)
{
    ListNode? prev = null;
    ListNode? curr = head;

    while (curr != null)
    {
        ListNode? next = curr.next; // save next
        curr.next = prev;           // reverse pointer
        prev = curr;                // advance prev
        curr = next;                // advance curr
    }

    return prev; // new head
}
```

### Walkthrough: `1 → 2 → 3 → null`

```
prev=null, curr=1: next=2, 1.next=null, prev=1, curr=2
prev=1,    curr=2: next=3, 2.next=1,    prev=2, curr=3
prev=2,    curr=3: next=null, 3.next=2, prev=3, curr=null
return 3 → 2 → 1 → null ✓
```

---

## Approach 2: Recursive — O(n) time, O(n) space (call stack)

```csharp
public static ListNode? ReverseRecursive(ListNode? head)
{
    if (head?.next == null) return head; // base case: empty or single node

    ListNode newHead = ReverseRecursive(head.next)!; // reverse rest of list
    head.next.next = head; // make next node point back to current
    head.next = null;       // current node's next = null (will be updated by caller)
    return newHead;
}
```

> **Recursion pitfall:** Uses O(n) stack space — can stack overflow for very long lists (`n > 5000`). Always prefer iterative in production.

---

## Complexity Summary

| Approach   | Time | Space   |
|------------|------|---------|
| Iterative  | O(n) | O(1)    |
| Recursive  | O(n) | O(n)    |

---

## Interview Tips

- **Iterative is the expected answer** — show you understand pointer manipulation without extra space.
- Draw the pointer diagram on the whiteboard/paper before coding to avoid confusion.
- **Edge cases:** `null` input (return `null`), single node (return itself).
- **Common mistake:** Losing the reference to `curr.next` before reassigning `curr.next = prev` — always save `next` first.
- **Follow-up:** *"Reverse a sublist from position `left` to `right`."* → LeetCode #92. Requires locating the boundaries first.
- **Follow-up:** *"Reverse every k nodes."* → [Reverse Nodes in k-Group](../reverse-nodes-in-k-group/README.md).
