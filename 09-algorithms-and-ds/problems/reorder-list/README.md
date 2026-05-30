# Reorder List

**Source:** LeetCode #143
**Difficulty:** 🟡 Medium
**Topics:** Linked List, Two-Pointer, Reverse

## Problem Statement

You are given the head of a singly linked-list: `L0 → L1 → … → Lₙ₋₁ → Lₙ`.

Reorder it to: `L0 → Lₙ → L1 → Lₙ₋₁ → L2 → Lₙ₋₂ → …`

You may not modify the values in the list's nodes. Only nodes themselves may be changed.

## Examples

```
Input:  1→2→3→4
Output: 1→4→2→3

Input:  1→2→3→4→5
Output: 1→5→2→4→3
```

## Constraints

- Number of nodes: `[1, 5 × 10⁴]`
- `1 <= Node.val <= 1000`

---

## Approach: Find Middle → Reverse Second Half → Merge — O(n) time, O(1) space ✓

Three clean steps:
1. **Find the middle** of the list (slow/fast pointer).
2. **Reverse the second half**.
3. **Merge** the two halves alternately.

```csharp
public static void ReorderList(ListNode? head)
{
    if (head?.next == null) return;

    // Step 1: Find the middle (slow ends at end-of-first-half)
    ListNode slow = head, fast = head;
    while (fast.next != null && fast.next.next != null)
    {
        slow = slow.next!;
        fast = fast.next.next;
    }

    // Step 2: Reverse the second half
    ListNode? prev = null, curr = slow.next;
    slow.next = null; // cut the list
    while (curr != null)
    {
        ListNode? next = curr.next;
        curr.next = prev;
        prev = curr;
        curr = next;
    }
    // prev is now the head of the reversed second half

    // Step 3: Merge two halves alternately
    ListNode? first = head, second = prev;
    while (second != null)
    {
        ListNode? tmp1 = first!.next;
        ListNode? tmp2 = second.next;
        first.next = second;
        second.next = tmp1;
        first = tmp1;
        second = tmp2;
    }
}
```

### Walkthrough: `1→2→3→4→5`

```
Step 1: slow=3 (middle), fast=5
Step 2: Reverse 4→5 → 5→4; cut at slow: first half=1→2→3, second=5→4
Step 3: Merge:
  1→(5→2→(4→3))
Result: 1→5→2→4→3 ✓
```

---

## Complexity Summary

| Step              | Time | Space |
|-------------------|------|-------|
| Find middle       | O(n) | O(1)  |
| Reverse           | O(n) | O(1)  |
| Merge             | O(n) | O(1)  |
| **Total**         | **O(n)** | **O(1)** |

---

## Interview Tips

- **Decompose into 3 sub-problems** — each is a standard linked list operation you can code independently.
- The middle-finding terminates with `slow` at the *end of the first half* (using `fast.next.next != null` condition).
- **Edge cases:** 1 or 2 node lists (no reorder needed or trivially handled).
- **Common mistake:** Not cutting the list at `slow.next = null` before reversing — the reverse would loop back to the first half.
- Related: [Reverse Linked List](../reverse-linked-list/README.md), [Merge Two Sorted Lists](../merge-two-sorted-lists/README.md).
