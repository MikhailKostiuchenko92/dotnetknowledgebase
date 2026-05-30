# Find Median from Data Stream (Heap-based)

**Source:** LeetCode #295
**Difficulty:** 🔴 Hard
**Topics:** Two Heaps, Design

## Problem Statement

Design a data structure that supports:
- `AddNum(num)`: Add a number to the data stream.
- `FindMedian()`: Return the median of all elements so far.

For even-length data, the median is the average of the two middle values.

## Examples

```csharp
var mf = new MedianFinder();
mf.AddNum(1); mf.AddNum(2);
mf.FindMedian(); // 1.5
mf.AddNum(3);
mf.FindMedian(); // 2.0
```

## Constraints

- `-10⁵ <= num <= 10⁵`; at most `5 × 10⁴` calls.

---

## Approach: Two Heaps (Max-Heap + Min-Heap) — O(log n) add, O(1) find ✓

Maintain two heaps:
- `lowerMax` (max-heap): stores the lower half.
- `upperMin` (min-heap): stores the upper half.

Invariant: `lowerMax.Count == upperMin.Count` or `lowerMax.Count == upperMin.Count + 1`.

> **Note:** .NET's `PriorityQueue<T, P>` is a **min-heap**. Simulate max-heap by negating priorities.

```csharp
public class MedianFinder
{
    // Max-heap for lower half: store (element, -element) so highest pops first
    private readonly PriorityQueue<int, int> _lowerMax = new();
    // Min-heap for upper half
    private readonly PriorityQueue<int, int> _upperMin = new();

    public void AddNum(int num)
    {
        // Always add to lowerMax first
        _lowerMax.Enqueue(num, -num);

        // Balance: lowerMax's max must be ≤ upperMin's min
        _upperMin.Enqueue(_lowerMax.Peek(), _lowerMax.Peek());
        _lowerMax.Dequeue();

        // Keep sizes balanced: lowerMax can have one more element
        if (_upperMin.Count > _lowerMax.Count)
        {
            int val = _upperMin.Dequeue();
            _lowerMax.Enqueue(val, -val);
        }
    }

    public double FindMedian()
    {
        if (_lowerMax.Count > _upperMin.Count) return _lowerMax.Peek();
        return (_lowerMax.Peek() + _upperMin.Peek()) / 2.0;
    }
}
```

---

## Complexity Summary

| Operation   | Time    | Space |
|-------------|---------|-------|
| AddNum      | O(log n)| O(n)  |
| FindMedian  | O(1)    | O(1)  |

---

## Interview Tips

- This is the canonical **two-heap** pattern — memorise it.
- `.NET PriorityQueue` is a min-heap — negate the priority to simulate a max-heap.
- **Follow-up:** *"What if the stream has constraints like 0–100?"* → Counting sort / BucketSort approach in O(1).
- **Related:** [Median from Data Stream](../median-from-data-stream/README.md) (Sorting & Searching section).
