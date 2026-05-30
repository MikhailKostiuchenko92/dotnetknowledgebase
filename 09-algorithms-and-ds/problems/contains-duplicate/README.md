# Contains Duplicate

**Source:** LeetCode #217
**Difficulty:** 🟢 Easy
**Topics:** Array, HashSet

## Problem Statement

Given an integer array `nums`, return `true` if any value appears **at least twice**, and return `false` if every element is distinct.

## Examples

```
Input:  nums = [1, 2, 3, 1]
Output: true

Input:  nums = [1, 2, 3, 4]
Output: false

Input:  nums = [1, 1, 1, 3, 3, 4, 3, 2, 4, 2]
Output: true
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-10⁹ <= nums[i] <= 10⁹`

---

## Approach 1: HashSet — O(n) time, O(n) space ✓ Preferred

```csharp
public static bool ContainsDuplicate(int[] nums)
{
    var seen = new HashSet<int>(nums.Length);
    foreach (int n in nums)
        if (!seen.Add(n)) // Add returns false if element already existed
            return true;
    return false;
}
```

`HashSet<T>.Add` returns `false` when the element already exists — cleaner than `Contains` + `Add`.

---

## Approach 2: Sort then Linear Scan — O(n log n) time, O(1) space

```csharp
public static bool ContainsDuplicateSort(int[] nums)
{
    Array.Sort(nums); // modifies input — mention this trade-off
    for (int i = 1; i < nums.Length; i++)
        if (nums[i] == nums[i - 1]) return true;
    return false;
}
```

> **Trade-off:** Saves space but mutates the input array. Always ask the interviewer if mutation is acceptable.

---

## Approach 3: LINQ one-liner

```csharp
public static bool ContainsDuplicateLinq(int[] nums) =>
    nums.Length != nums.Distinct().Count();
```

Concise but allocates an intermediate sequence. Fine for readability in production; less ideal in competitive contexts.

---

## Complexity Summary

| Approach       | Time      | Space | Mutates Input |
|----------------|-----------|-------|---------------|
| HashSet        | O(n)      | O(n)  | No            |
| Sort + scan    | O(n log n)| O(1)* | Yes           |
| LINQ Distinct  | O(n)      | O(n)  | No            |

*Ignoring the O(log n) stack space for sort recursion

---

## Interview Tips

- This is a warm-up question. Use it to demonstrate clean code and knowledge of .NET collections.
- Mention the `HashSet.Add` return-value trick — it shows familiarity with the API.
- **Follow-up:** *"What if duplicates must be within k positions of each other?"* → LeetCode #219 — maintain a sliding HashSet of size k.
- **Follow-up:** *"What if values must be within t of each other (value proximity)?"* → LeetCode #220 — requires a sorted set or bucket sort.
