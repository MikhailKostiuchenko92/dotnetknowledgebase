# Detect a Cycle in a Linked List (Floyd's Tortoise & Hare)

**Source:** LeetCode #141
**Difficulty:** 🟢 Easy
**Topics:** Linked List, Two-Pointer, Floyd's Algorithm

## Problem Statement

Given `head`, the head of a linked list, determine if the linked list has a **cycle** in it.

There is a cycle if some node in the list can be reached again by continuously following the `next` pointer. Return `true` if there is a cycle, `false` otherwise.

## Examples

```
Input:  3 → 2 → 0 → -4 ↩ (tail connects to index 1)
Output: true

Input:  1 → 2 ↩ (tail connects to index 0)
Output: true

Input:  1 → null
Output: false
```

## Constraints

- Number of nodes: `[0, 10⁴]`
- `-10⁵ <= Node.val <= 10⁵`

---

## Approach 1: HashSet — O(n) time, O(n) space

Store visited nodes in a `HashSet`. If a node is visited twice, there's a cycle.

```csharp
public static bool HasCycleHashSet(ListNode? head)
{
    var visited = new HashSet<ListNode>();
    var curr = head;
    while (curr != null)
    {
        if (!visited.Add(curr)) return true; // Add returns false if already present
        curr = curr.next;
    }
    return false;
}
```

---

## Approach 2: Floyd's Tortoise & Hare — O(n) time, O(1) space ✓

Use two pointers: `slow` (moves 1 step) and `fast` (moves 2 steps). If there's a cycle, they will eventually meet inside it. If there's no cycle, `fast` will reach `null`.

```csharp
public static bool HasCycle(ListNode? head)
{
    ListNode? slow = head, fast = head;

    while (fast?.next != null)
    {
        slow = slow!.next;
        fast = fast.next.next;

        if (slow == fast) return true; // pointers met → cycle exists
    }

    return false; // fast reached end → no cycle
}
```

### Why do they always meet if there's a cycle?

Once both pointers are in the cycle, the distance between them changes by 1 each step (fast gains 1 step on slow per iteration). The gap shrinks from some positive value to 0 in at most `cycle_length` steps.

> **The condition `fast?.next != null`** handles both: `fast == null` (even-length no-cycle) and `fast.next == null` (odd-length no-cycle).

---

## Complexity Summary

| Approach              | Time | Space |
|-----------------------|------|-------|
| HashSet               | O(n) | O(n)  |
| Floyd's Tortoise/Hare | O(n) | O(1)  |

---

## Interview Tips

- **Floyd's algorithm is the expected answer** — O(1) space.
- Explain *why* they meet in a cycle (relative speed argument).
- **Edge cases:** `null` list, single node with no cycle, single node pointing to itself.
- **Common mistake:** Checking `slow == fast` before moving — the initial position is the same; check after advancing.
- **Follow-up:** *"Find the node where the cycle begins."* → [Find Cycle Start Node](../find-cycle-start-node/README.md) — LeetCode #142, uses a reset trick after detection.
