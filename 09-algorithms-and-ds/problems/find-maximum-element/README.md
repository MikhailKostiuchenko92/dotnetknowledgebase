# Find the Maximum Element in an Array

**Source:** Custom / Real interview (warm-up)
**Difficulty:** 🟢 Easy
**Topics:** Array, Linear Scan

## Problem Statement

Given an integer array `nums`, return the **maximum value** in the array. If the array is empty, throw or return a sentinel as appropriate.

## Examples

```
Input:  nums = [3, 1, 4, 1, 5, 9, 2, 6]
Output: 9

Input:  nums = [-5, -1, -3]
Output: -1

Input:  nums = [42]
Output: 42
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-10⁹ <= nums[i] <= 10⁹`

---

## Approach 1: Single Linear Scan — O(n) time, O(1) space

Track the running maximum in one pass.

```csharp
public static int FindMax(int[] nums)
{
    if (nums.Length == 0)
        throw new ArgumentException("Array must not be empty.", nameof(nums));

    int max = nums[0]; // initialise with first element, NOT int.MinValue
    for (int i = 1; i < nums.Length; i++)
        if (nums[i] > max)
            max = nums[i];
    return max;
}
```

> **Why initialise with `nums[0]` and not `int.MinValue`?**  
> Initialising with `int.MinValue` works here because the problem guarantees integers, but it's a bad habit — for floating-point or generic comparisons it can break. Prefer the first-element initialisation pattern.

---

## Approach 2: LINQ — O(n) time, O(1) space (with allocation overhead)

```csharp
public static int FindMaxLinq(int[] nums) => nums.Max(); // throws if empty
```

Convenient for production code, but allocates an enumerator. Avoid in tight loops or hot paths.

---

## Approach 3: `Span<T>` + manual loop — O(n) time, O(1) space

Demonstrates low-allocation awareness:

```csharp
public static int FindMaxSpan(ReadOnlySpan<int> nums)
{
    if (nums.IsEmpty) throw new ArgumentException("Span must not be empty.");
    int max = nums[0];
    for (int i = 1; i < nums.Length; i++)
        if (nums[i] > max) max = nums[i];
    return max;
}
```

Accepts arrays, stack-allocated spans, and slices without copying.

---

## Generic Version (C# 11+ — `INumber<T>`)

```csharp
using System.Numerics;

public static T FindMax<T>(ReadOnlySpan<T> nums) where T : INumber<T>
{
    if (nums.IsEmpty) throw new ArgumentException("Span must not be empty.");
    T max = nums[0];
    foreach (var n in nums[1..])
        if (n > max) max = n;
    return max;
}
```

Uses the generic math interface introduced in .NET 7 / C# 11.

---

## Complexity Summary

| Approach         | Time | Space |
|------------------|------|-------|
| Linear scan      | O(n) | O(1)  |
| LINQ `.Max()`    | O(n) | O(1)* |
| ReadOnlySpan     | O(n) | O(1)  |

---

## Interview Tips

- This is often a warm-up question. Nail it to set a good tone — mention the initialisation choice and empty-array handling.
- **Follow-up:** *"Find both min and max in one pass."* → Track both simultaneously: `3n/2 - 2` comparisons using pair-wise min/max instead of `2(n-1)`.
- **Follow-up:** *"What if the array is very large and stored across multiple machines?"* → Leads to a distributed max-finding / MapReduce discussion.
- **Follow-up:** *"Find the Kth largest element."* → See [Kth Largest Element in Array](../kth-largest-element-in-array/README.md).
- Always handle the empty-array case explicitly; forgetting it is the most common mistake.
