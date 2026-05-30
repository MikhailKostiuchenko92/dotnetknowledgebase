# Range Sum Query - Mutable

**Source:** LeetCode #307
**Difficulty:** 🟡 Medium
**Topics:** Array, Segment Tree, Fenwick Tree (BIT), Design

## Problem Statement

Given an integer array `nums`, handle multiple queries of the following types:

1. **Update** the value of an element in `nums`.
2. **Range sum**: Calculate the sum of elements between indices `left` and `right` inclusive.

## Examples

```
NumArray obj = new([1, 3, 5]);
obj.SumRange(0, 2);   // 9
obj.Update(1, 2);     // nums = [1, 2, 5]
obj.SumRange(0, 2);   // 8
```

## Constraints

- `1 <= nums.Length <= 3 × 10⁴`; `-100 <= nums[i] <= 100`; up to `3 × 10⁴` calls.

---

## Approach 1: Fenwick Tree (BIT) — O(log n) update and query ✓

```csharp
public class NumArray
{
    private readonly int[] _bit;
    private readonly int[] _nums;
    private readonly int   _n;

    public NumArray(int[] nums)
    {
        _n    = nums.Length;
        _nums = (int[])nums.Clone();
        _bit  = new int[_n + 1];
        for (int i = 0; i < _n; i++) BitUpdate(i + 1, _nums[i]);
    }

    public void Update(int index, int val)
    {
        int delta = val - _nums[index];
        _nums[index] = val;
        BitUpdate(index + 1, delta);
    }

    public int SumRange(int left, int right)
        => BitQuery(right + 1) - BitQuery(left);

    private void BitUpdate(int i, int delta)
    {
        for (; i <= _n; i += i & -i) _bit[i] += delta;
    }

    private int BitQuery(int i)
    {
        int sum = 0;
        for (; i > 0; i -= i & -i) sum += _bit[i];
        return sum;
    }
}
```

---

## Approach 2: Segment Tree — O(log n) update and query

More code, but generalises to range-minimum, range-max, etc.

```csharp
public class NumArraySegTree
{
    private readonly int[] _tree;
    private readonly int   _n;

    public NumArraySegTree(int[] nums)
    {
        _n = nums.Length;
        _tree = new int[4 * _n];
        Build(nums, 0, 0, _n - 1);
    }

    private void Build(int[] nums, int node, int start, int end)
    {
        if (start == end) { _tree[node] = nums[start]; return; }
        int mid = (start + end) / 2;
        Build(nums, 2*node+1, start, mid);
        Build(nums, 2*node+2, mid+1, end);
        _tree[node] = _tree[2*node+1] + _tree[2*node+2];
    }

    public void Update(int index, int val) => Update(0, 0, _n-1, index, val);

    private void Update(int node, int start, int end, int idx, int val)
    {
        if (start == end) { _tree[node] = val; return; }
        int mid = (start + end) / 2;
        if (idx <= mid) Update(2*node+1, start, mid, idx, val);
        else            Update(2*node+2, mid+1, end, idx, val);
        _tree[node] = _tree[2*node+1] + _tree[2*node+2];
    }

    public int SumRange(int left, int right) => Query(0, 0, _n-1, left, right);

    private int Query(int node, int start, int end, int l, int r)
    {
        if (r < start || end < l) return 0;
        if (l <= start && end <= r) return _tree[node];
        int mid = (start + end) / 2;
        return Query(2*node+1, start, mid, l, r) + Query(2*node+2, mid+1, end, l, r);
    }
}
```

---

## Complexity Summary

| Approach       | Build   | Update   | Query    | Space |
|----------------|---------|----------|----------|-------|
| Prefix sum     | O(n)    | O(n)     | O(1)     | O(n)  |
| Fenwick Tree   | O(n log n) | O(log n) | O(log n) | O(n)  |
| Segment Tree   | O(n)    | O(log n) | O(log n) | O(n)  |

---

## Interview Tips

- **BIT is simpler** to implement; segment tree is more flexible (supports non-invertible operations like min/max).
- `i & -i` (lowest set bit trick) is the heart of the BIT — know how to explain it.
- **Follow-up:** *"Support range updates and point queries."* → Reverse the BIT roles.
