# Find the Starting Node of a Cycle (Floyd's Extension)

**Source:** LeetCode #142
**Difficulty:** 🟡 Medium
**Topics:** Linked List, Two-Pointer, Floyd's Algorithm

## Problem Statement

Given the `head` of a linked list, return the **node where the cycle begins**. If there is no cycle, return `null`.

## Examples

```
Input:  3→2→0→-4 (tail connects to node at index 1)
Output: Node at index 1 (value = 2)

Input:  1→2 (tail connects to node at index 0)
Output: Node at index 0 (value = 1)

Input:  1 (no cycle)
Output: null
```

## Constraints

- Number of nodes: `[0, 10⁴]`
- `-10⁵ <= Node.val <= 10⁵`

---

## Approach 1: HashSet — O(n) time, O(n) space

Return the first node visited twice.

```csharp
public static ListNode? DetectCycleHashSet(ListNode? head)
{
    var visited = new HashSet<ListNode>();
    for (var curr = head; curr != null; curr = curr.next)
        if (!visited.Add(curr)) return curr;
    return null;
}
```

---

## Approach 2: Floyd's Extended Algorithm — O(n) time, O(1) space ✓

**Phase 1:** Detect the cycle using slow/fast pointers.  
**Phase 2:** Once they meet, reset one pointer to `head`. Move both one step at a time. They'll meet at the **cycle entry point**.

```csharp
public static ListNode? DetectCycle(ListNode? head)
{
    ListNode? slow = head, fast = head;

    // Phase 1: detect meeting point inside the cycle
    while (fast?.next != null)
    {
        slow = slow!.next;
        fast = fast.next.next;
        if (slow == fast) break;
    }

    if (fast?.next == null) return null; // no cycle

    // Phase 2: find cycle entry
    slow = head;
    while (slow != fast)
    {
        slow = slow!.next;
        fast = fast!.next;
    }

    return slow; // cycle entry node
}
```

### Mathematical Proof

Let:
- `F` = distance from head to cycle entry
- `C` = cycle length
- `h` = distance from cycle entry to meeting point (inside the cycle)

When they meet: `slow` has traveled `F + h`, `fast` has traveled `F + h + C` (one full loop extra).  
Since `fast = 2 × slow`: `F + h + C = 2(F + h)` → `C - h = F`.

So after the meeting, a pointer at the meeting point and a pointer at `head`, both moving 1 step at a time, will meet exactly at the cycle entry (both travel distance `F`).

---

## Complexity Summary

| Approach          | Time | Space |
|-------------------|------|-------|
| HashSet           | O(n) | O(n)  |
| Floyd's Extension | O(n) | O(1)  |

---

## Interview Tips

- **Pre-requisite:** [Detect Cycle in Linked List](../detect-cycle-in-linked-list/README.md) — know Phase 1 cold.
- **The phase-2 trick is non-obvious** — state the math briefly: *"After detection, resetting one pointer to head and advancing both at the same speed makes them meet at the cycle entry."*
- Derive the math on paper/whiteboard if asked to prove it.
- **Edge cases:** No cycle, cycle includes the entire list (entry = head), single-node cycle (node points to itself).
