# Median from Data Stream

**Source:** LeetCode #295
**Difficulty:** 🔴 Hard
**Topics:** Heap, Design, Two-Heap

## Problem Statement

Design a data structure that supports:
- `AddNum(int num)` — add an integer number from the data stream.
- `FindMedian()` — return the median of all elements so far.

If the total number of elements is even, the median is the mean of the two middle values.

## Examples

```
MedianFinder finder = new();
finder.AddNum(1);    // stream: [1]
finder.AddNum(2);    // stream: [1, 2]
finder.FindMedian(); // → 1.5
finder.AddNum(3);    // stream: [1, 2, 3]
finder.FindMedian(); // → 2.0
```

## Constraints

- `-10⁵ <= num <= 10⁵`
- `FindMedian` will always be called after at least one `AddNum`.
- At most `5 × 10⁴` calls to `AddNum` and `FindMedian`.

---

## Approach: Two Heaps — O(log n) AddNum, O(1) FindMedian ✓

Maintain two heaps:
- **Max-heap** (`lower`): stores the smaller half of elements — top = largest of lower half.
- **Min-heap** (`upper`): stores the larger half — top = smallest of upper half.

**Invariant:**
1. `lower.Count == upper.Count` (even total) OR `lower.Count == upper.Count + 1` (odd total, extra in lower).
2. `lower.Peek() <= upper.Peek()` (all lower ≤ all upper).

```csharp
public class MedianFinder
{
    // Max-heap (negate priorities for PriorityQueue which is min-heap)
    private readonly PriorityQueue<int, int> _lower = new(); // max-heap: priority = -value
    private readonly PriorityQueue<int, int> _upper = new(); // min-heap: priority = value

    public void AddNum(int num)
    {
        // Always add to lower first
        _lower.Enqueue(num, -num); // negate for max-heap behaviour

        // Balance: ensure lower's max <= upper's min
        if (_upper.Count > 0 && -_lower.Peek() > _upper.Peek()) // Peek returns priority
        {
            // Wrong: move lower's max to upper
            // Note: PriorityQueue.Peek() returns element, not priority
            // We need to check the actual element values
        }

        // Re-balance sizes
        if (_lower.Count > _upper.Count + 1)
        {
            _lower.TryDequeue(out int el, out _);
            _upper.Enqueue(el, el);
        }
        else if (_upper.Count > _lower.Count)
        {
            _upper.TryDequeue(out int el, out _);
            _lower.Enqueue(el, -el);
        }
    }

    public double FindMedian()
    {
        if (_lower.Count > _upper.Count)
            return _lower.Peek();
        return (_lower.Peek() + (double)_upper.Peek()) / 2;
    }
}
```

### Clean implementation with cross-balance check:

```csharp
public class MedianFinder
{
    // lower: max-heap (negate values as priorities)
    private readonly PriorityQueue<int, int> _lower = new();
    // upper: min-heap
    private readonly PriorityQueue<int, int> _upper = new();

    public void AddNum(int num)
    {
        _lower.Enqueue(num, -num);

        // Ensure every element in lower <= every element in upper
        if (_upper.Count > 0)
        {
            _lower.TryDequeue(out int lMax, out _);
            _upper.TryDequeue(out int uMin, out _);
            if (lMax > uMin) // swap them
            {
                _lower.Enqueue(uMin, -uMin);
                _upper.Enqueue(lMax, lMax);
            }
            else
            {
                _lower.Enqueue(lMax, -lMax);
                _upper.Enqueue(uMin, uMin);
            }
        }

        // Re-balance sizes: lower always has equal or one more than upper
        if (_lower.Count > _upper.Count + 1)
        {
            _lower.TryDequeue(out int el, out _);
            _upper.Enqueue(el, el);
        }
        else if (_upper.Count > _lower.Count)
        {
            _upper.TryDequeue(out int el, out _);
            _lower.Enqueue(el, -el);
        }
    }

    public double FindMedian()
    {
        if (_lower.Count > _upper.Count)
            return _lower.Peek();
        return (_lower.Peek() + (double)_upper.Peek()) / 2.0;
    }
}
```

> **.NET `PriorityQueue<T,P>` is always a min-heap.** To simulate a max-heap, negate the priority: `Enqueue(value, -value)`. `Peek()` returns the **element** (not priority) — useful here.

---

## Complexity Summary

| Operation   | Time    | Space |
|-------------|---------|-------|
| AddNum      | O(log n)| O(n)  |
| FindMedian  | O(1)    | —     |

---

## Interview Tips

- **State the two-heap invariant** before coding: lower half in max-heap, upper half in min-heap, sizes differ by at most 1.
- In C#, explain the max-heap simulation by negating priorities.
- **Edge cases:** Single element (lower has 1, upper has 0 → return lower.Peek()), two elements (one each → average).
- **Follow-up:** *"What if most numbers are in the range [0, 100]?"* → Use a counting/bucket array of size 101 for O(1) insert and O(1) median lookup.
- **Follow-up:** *"What if you need the k-th percentile instead of median?"* → Maintain heaps with sizes `k%` and `(1-k)%` of total.
- Related: [Kth Largest Element](../kth-largest-element-in-array/README.md).
