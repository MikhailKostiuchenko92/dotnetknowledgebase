# Merge K Sorted Lists

**Source:** LeetCode #23
**Difficulty:** 🔴 Hard
**Topics:** Linked List, Heap, Divide and Conquer

## Problem Statement

You are given an array of `k` linked-lists, each sorted in ascending order. Merge all the linked-lists into one sorted linked-list and return it.

## Examples

```
Input:  lists = [[1→4→5],[1→3→4],[2→6]]
Output: 1→1→2→3→4→4→5→6

Input:  lists = []
Output: []

Input:  lists = [[]]
Output: []
```

## Constraints

- `k == lists.Length`; `0 <= k <= 10⁴`
- `0 <= lists[i].Length <= 500`
- `-10⁴ <= lists[i][j] <= 10⁴`
- Each list is sorted in ascending order.
- Total number of nodes: `[0, 10⁴]`.

---

## Approach 1: Min-Heap — O(N log k) time, O(k) space ✓ Preferred

Push the head of each list into a min-heap. Repeatedly extract the minimum, append to result, and push the next node from that list.

*N = total number of nodes, k = number of lists.*

```csharp
public static ListNode? MergeKLists(ListNode?[] lists)
{
    // Min-heap ordered by node value
    var heap = new PriorityQueue<ListNode, int>(lists.Length);

    foreach (var head in lists)
        if (head != null)
            heap.Enqueue(head, head.val);

    var dummy = new ListNode(0);
    var curr = dummy;

    while (heap.Count > 0)
    {
        var node = heap.Dequeue();
        curr.next = node;
        curr = curr.next;

        if (node.next != null)
            heap.Enqueue(node.next, node.next.val);
    }

    return dummy.next;
}
```

---

## Approach 2: Divide and Conquer — O(N log k) time, O(log k) space

Recursively merge pairs of lists like merge sort. After `log k` rounds, all lists are merged.

```csharp
public static ListNode? MergeKListsDivide(ListNode?[] lists)
{
    if (lists.Length == 0) return null;
    return DivideAndConquer(lists, 0, lists.Length - 1);
}

private static ListNode? DivideAndConquer(ListNode?[] lists, int lo, int hi)
{
    if (lo == hi) return lists[lo];
    int mid = lo + (hi - lo) / 2;
    var left  = DivideAndConquer(lists, lo, mid);
    var right = DivideAndConquer(lists, mid + 1, hi);
    return MergeTwo(left, right);
}

private static ListNode? MergeTwo(ListNode? l1, ListNode? l2)
{
    var dummy = new ListNode(0);
    var curr = dummy;
    while (l1 != null && l2 != null)
    {
        if (l1.val <= l2.val) { curr.next = l1; l1 = l1.next; }
        else                  { curr.next = l2; l2 = l2.next; }
        curr = curr.next;
    }
    curr.next = l1 ?? l2;
    return dummy.next;
}
```

---

## Approach 3: Sequential Merge — O(N · k) time, O(1) extra space

Merge lists one by one left to right. Simple but suboptimal.

---

## Complexity Summary

| Approach              | Time       | Space  |
|-----------------------|------------|--------|
| Min-Heap              | O(N log k) | O(k)   |
| Divide and Conquer    | O(N log k) | O(log k)|
| Sequential Merge      | O(N · k)   | O(1)   |

---

## Interview Tips

- Min-heap and divide-and-conquer both achieve O(N log k) — choose based on what's easier to code cleanly.
- **Explain N vs k:** *"N is total nodes, k is list count. The heap always has at most k elements, so each heap operation is O(log k)."*
- **Edge cases:** All empty lists, single list, lists of different lengths.
- Related: [Merge Two Sorted Lists](../merge-two-sorted-lists/README.md) — the fundamental building block.
- **Follow-up:** *"What if you can't hold all lists in memory?"* → External merge sort pattern — use the heap approach as-is, reading from file streams.
