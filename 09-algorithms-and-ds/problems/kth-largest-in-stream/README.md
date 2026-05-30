# Kth Largest Element in a Stream

**Source:** LeetCode #703
**Difficulty:** 🟢 Easy
**Topics:** Heap (Priority Queue), Design, Data Stream

## Problem Statement

Design a class to find the k-th largest element in a stream. Note that it is the k-th largest in sorted order, not the k-th distinct element.

```csharp
KthLargest obj = new KthLargest(3, [4, 5, 8, 2]);
obj.Add(3); // returns 4
obj.Add(5); // returns 5
obj.Add(10);// returns 5
obj.Add(9); // returns 8
obj.Add(4); // returns 8
```

## Constraints

- `1 <= k <= 10⁴`; initial nums may be empty; `-10⁴ <= val <= 10⁴`.

---

## Approach: Min-Heap of Size k — O(n log k) init, O(log k) add ✓

Maintain a min-heap of exactly `k` elements. The root (minimum) is always the k-th largest.

```csharp
public class KthLargest
{
    private readonly PriorityQueue<int, int> _minHeap = new();
    private readonly int _k;

    public KthLargest(int k, int[] nums)
    {
        _k = k;
        foreach (int n in nums) Add(n);
    }

    public int Add(int val)
    {
        _minHeap.Enqueue(val, val);
        if (_minHeap.Count > _k) _minHeap.Dequeue(); // remove smallest
        return _minHeap.Peek();
    }
}
```

---

## Complexity Summary

| Operation | Time     | Space |
|-----------|----------|-------|
| Init      | O(n log k)| O(k) |
| Add       | O(log k) | O(1)  |

---

## Interview Tips

- A min-heap of size `k` keeps the `k` largest elements; the minimum of those = the k-th largest.
- `.NET PriorityQueue<int, int>` is a min-heap — `Enqueue(val, val)` with the value as both element and priority.
- **Follow-up:** *"Find the k-th smallest?"* → Max-heap of size k; root = k-th smallest.
