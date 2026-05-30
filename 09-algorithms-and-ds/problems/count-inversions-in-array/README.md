# Count Inversions in Array

**Source:** Custom / Real interview / CLRS Exercise
**Difficulty:** 🔴 Hard
**Topics:** Array, Merge Sort, Divide and Conquer

## Problem Statement

Given an array `nums`, count the number of **inversions**: pairs `(i, j)` where `i < j` and `nums[i] > nums[j]`.

An inversion measures how far the array is from being sorted. A sorted array has 0 inversions; a reverse-sorted array has the maximum `n*(n-1)/2` inversions.

## Examples

```
Input:  nums = [2, 4, 1, 3, 5]
Output: 3   // (2,1), (4,1), (4,3)

Input:  nums = [1, 2, 3, 4, 5]
Output: 0   // already sorted

Input:  nums = [5, 4, 3, 2, 1]
Output: 10  // all pairs are inversions
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-10⁹ <= nums[i] <= 10⁹`

---

## Approach 1: Brute Force — O(n²) time, O(1) space

```csharp
public static long CountInversionsBrute(int[] nums)
{
    long count = 0;
    for (int i = 0; i < nums.Length; i++)
        for (int j = i + 1; j < nums.Length; j++)
            if (nums[i] > nums[j]) count++;
    return count;
}
```

---

## Approach 2: Modified Merge Sort — O(n log n) time, O(n) space ✓

During merge sort, when merging two sorted halves, every time a right-half element is picked before a left-half element, it forms an inversion with all remaining left-half elements.

```csharp
public static long CountInversions(int[] nums)
{
    int[] temp = new int[nums.Length];
    return MergeSort(nums, temp, 0, nums.Length - 1);
}

private static long MergeSort(int[] nums, int[] temp, int lo, int hi)
{
    if (lo >= hi) return 0;

    int mid = lo + (hi - lo) / 2;
    long count = MergeSort(nums, temp, lo, mid)
               + MergeSort(nums, temp, mid + 1, hi);

    // Merge and count split inversions
    int i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi)
    {
        if (nums[i] <= nums[j])
        {
            temp[k++] = nums[i++];
        }
        else
        {
            // nums[i..mid] are all greater than nums[j] (both halves sorted)
            count += mid - i + 1;
            temp[k++] = nums[j++];
        }
    }
    while (i <= mid) temp[k++] = nums[i++];
    while (j <= hi)  temp[k++] = nums[j++];

    Array.Copy(temp, lo, nums, lo, hi - lo + 1);
    return count;
}
```

### Why does this work?

When merging two sorted halves `L` and `R`, if `R[j] < L[i]`, then `R[j]` is less than all remaining elements in `L` (since `L` is sorted). So the number of inversions involving `R[j]` with left-half elements is `mid - i + 1`.

> **Use `long` for the count** — with `n = 10⁵`, the maximum inversions = `n*(n-1)/2 ≈ 5 × 10⁹`, which overflows `int`.

---

## Complexity Summary

| Approach       | Time       | Space |
|----------------|------------|-------|
| Brute Force    | O(n²)      | O(1)  |
| Merge Sort     | O(n log n) | O(n)  |

---

## Interview Tips

- **Name the algorithm:** "Modified merge sort" — it's the canonical approach to this problem.
- Explain the counting insight: *"When I pick from the right half before exhausting the left half, each remaining left element forms an inversion with the right element."*
- **Use `long` for the count** — explicitly mention overflow prevention.
- This is a classic CLRS problem (Introduction to Algorithms, Chapter 2).
- **Alternative:** Fenwick Tree (Binary Indexed Tree) can also solve this in O(n log n) with coordinate compression.
- **Follow-up:** *"Count inversions modulo 10⁹+7."* → Add `% MOD` to the count accumulation.
