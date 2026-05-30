# Kth Largest Element in an Array

**Source:** LeetCode #215
**Difficulty:** 🟡 Medium
**Topics:** Array, Heap, QuickSelect

## Problem Statement

Given an integer array `nums` and an integer `k`, return the `k`-th **largest** element in the array. Note that it is the `k`-th largest in **sorted order**, not the `k`-th distinct element.

## Examples

```
Input:  nums = [3, 2, 1, 5, 6, 4], k = 2
Output: 5

Input:  nums = [3, 2, 3, 1, 2, 4, 5, 5, 6], k = 4
Output: 4
```

## Constraints

- `1 <= k <= nums.Length <= 10⁵`
- `-10⁴ <= nums[i] <= 10⁴`

---

## Approach 1: Sort — O(n log n) time, O(1) space

```csharp
public static int FindKthLargestSort(int[] nums, int k)
{
    Array.Sort(nums);
    return nums[nums.Length - k];
}
```

Simple but doesn't leverage the partial-order insight.

---

## Approach 2: Min-Heap of Size k — O(n log k) time, O(k) space ✓ Practical

Maintain a min-heap of the `k` largest elements seen so far. When the heap exceeds size `k`, eject the smallest. At the end, the heap top is the k-th largest.

```csharp
public static int FindKthLargestHeap(int[] nums, int k)
{
    // PriorityQueue<T,P> is a min-heap in .NET 6+
    var minHeap = new PriorityQueue<int, int>(k + 1);

    foreach (int n in nums)
    {
        minHeap.Enqueue(n, n);
        if (minHeap.Count > k)
            minHeap.Dequeue(); // remove smallest
    }

    return minHeap.Peek();
}
```

Best when `k << n` — heap stays small.

---

## Approach 3: QuickSelect — O(n) average, O(n²) worst time, O(1) space ✓ Optimal Average

Like quicksort's partition, but only recurse into the relevant half. Average O(n), worst case O(n²) without random pivot.

```csharp
public static int FindKthLargest(int[] nums, int k)
{
    // k-th largest = (n-k)-th smallest (0-indexed)
    return QuickSelect(nums, 0, nums.Length - 1, nums.Length - k);
}

private static int QuickSelect(int[] nums, int lo, int hi, int target)
{
    if (lo == hi) return nums[lo];

    // Random pivot to avoid O(n²) worst case
    int pivotIdx = lo + Random.Shared.Next(hi - lo + 1);
    (nums[pivotIdx], nums[hi]) = (nums[hi], nums[pivotIdx]);

    int pivot = nums[hi], i = lo;
    for (int j = lo; j < hi; j++)
        if (nums[j] <= pivot)
            (nums[i], nums[j]) = (nums[j], nums[i++]);

    (nums[i], nums[hi]) = (nums[hi], nums[i]); // place pivot

    if (i == target) return nums[i];
    if (i < target)  return QuickSelect(nums, i + 1, hi, target);
    return QuickSelect(nums, lo, i - 1, target);
}
```

---

## Complexity Summary

| Approach        | Time          | Space |
|-----------------|---------------|-------|
| Sort            | O(n log n)    | O(1)  |
| Min-Heap size k | O(n log k)    | O(k)  |
| QuickSelect     | O(n) avg / O(n²) worst | O(1) |

---

## Interview Tips

- **Min-heap** is easier to implement correctly and preferred when `k` is small.
- **QuickSelect** is the optimal average solution — mention the random pivot to avoid worst case.
- Explain the equivalence: k-th largest = `(n-k)`-th smallest (zero-indexed).
- **Common mistake:** Forgetting to randomize the pivot in QuickSelect.
- **Follow-up:** *"What if the input is a stream of integers?"* → Use a min-heap of size k and insert each new element — O(log k) per insertion.
- **Follow-up:** *"Kth smallest instead of largest?"* → Change heap type (max-heap of size k) or adjust the target index.
