# Merge Two Sorted Lists

**Source:** LeetCode #21
**Difficulty:** 🟢 Easy
**Topics:** Linked List, Two-Pointer

## Problem Statement

You are given the heads of two sorted linked lists `list1` and `list2`. Merge the two lists into one **sorted** list built by splicing together the nodes of the first two lists. Return the head of the merged linked list.

## Examples

```
Input:  list1 = 1→2→4, list2 = 1→3→4
Output: 1→1→2→3→4→4

Input:  list1 = [], list2 = []
Output: []

Input:  list1 = [], list2 = [0]
Output: [0]
```

## Constraints

- Number of nodes in each list: `[0, 50]`
- `-100 <= Node.val <= 100`
- Both lists are sorted in non-decreasing order.

---

## Approach 1: Iterative with Dummy Head — O(m+n) time, O(1) space ✓ Preferred

Use a dummy head node to avoid special-casing the first element.

```csharp
public static ListNode? MergeTwoLists(ListNode? list1, ListNode? list2)
{
    var dummy = new ListNode(0); // sentinel
    var curr = dummy;

    while (list1 != null && list2 != null)
    {
        if (list1.val <= list2.val)
        {
            curr.next = list1;
            list1 = list1.next;
        }
        else
        {
            curr.next = list2;
            list2 = list2.next;
        }
        curr = curr.next;
    }

    // Attach the remaining non-empty list
    curr.next = list1 ?? list2;

    return dummy.next;
}
```

The **dummy node** pattern eliminates the need to handle an empty result list as a special case — the result always starts at `dummy.next`.

---

## Approach 2: Recursive — O(m+n) time, O(m+n) space

```csharp
public static ListNode? MergeTwoListsRecursive(ListNode? list1, ListNode? list2)
{
    if (list1 == null) return list2;
    if (list2 == null) return list1;

    if (list1.val <= list2.val)
    {
        list1.next = MergeTwoListsRecursive(list1.next, list2);
        return list1;
    }
    else
    {
        list2.next = MergeTwoListsRecursive(list1, list2.next);
        return list2;
    }
}
```

Elegant but uses O(m+n) stack space — not suitable for very long lists.

---

## Complexity Summary

| Approach   | Time   | Space    |
|------------|--------|----------|
| Iterative  | O(m+n) | O(1)     |
| Recursive  | O(m+n) | O(m+n)   |

---

## Interview Tips

- **Dummy head is the key pattern** — explain it explicitly. It simplifies all linked-list merge/build operations.
- `curr.next = list1 ?? list2` cleanly handles the "attach remaining" step.
- **Edge cases:** Both empty, one empty, lists of different lengths.
- **Follow-up:** *"Merge k sorted lists."* → [Merge K Sorted Lists](../merge-k-sorted-lists/README.md) — use a min-heap or divide & conquer.
- **Follow-up:** *"Merge without using extra nodes (in-place)."* → The iterative approach already does this — re-points `next` without allocating new nodes.
