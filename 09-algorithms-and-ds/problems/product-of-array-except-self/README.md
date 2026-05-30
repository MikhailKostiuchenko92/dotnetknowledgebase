# Product of Array Except Self

**Source:** LeetCode #238
**Difficulty:** 🟡 Medium
**Topics:** Array, Prefix Products

## Problem Statement

Given an integer array `nums`, return an array `answer` such that `answer[i]` is equal to the **product of all elements of `nums` except `nums[i]`**.

**Constraints:** Must run in O(n) time and **without using the division operator**.

## Examples

```
Input:  nums = [1, 2, 3, 4]
Output: [24, 12, 8, 6]
//  answer[0] = 2*3*4 = 24
//  answer[1] = 1*3*4 = 12
//  answer[2] = 1*2*4 = 8
//  answer[3] = 1*2*3 = 6

Input:  nums = [-1, 1, 0, -3, 3]
Output: [0, 0, 9, 0, 0]
```

## Constraints

- `2 <= nums.Length <= 10⁵`
- `-30 <= nums[i] <= 30`
- The product of any prefix or suffix fits in a 32-bit integer.

---

## Approach 1: Prefix × Suffix (Two Arrays) — O(n) time, O(n) space

Build two auxiliary arrays:
- `prefix[i]` = product of all elements to the **left** of `i`
- `suffix[i]` = product of all elements to the **right** of `i`
- `answer[i] = prefix[i] * suffix[i]`

```csharp
public static int[] ProductExceptSelfV1(int[] nums)
{
    int n = nums.Length;
    int[] prefix = new int[n]; // prefix[i] = nums[0..i-1]
    int[] suffix = new int[n]; // suffix[i] = nums[i+1..n-1]
    int[] answer = new int[n];

    prefix[0] = 1;
    for (int i = 1; i < n; i++)
        prefix[i] = prefix[i - 1] * nums[i - 1];

    suffix[n - 1] = 1;
    for (int i = n - 2; i >= 0; i--)
        suffix[i] = suffix[i + 1] * nums[i + 1];

    for (int i = 0; i < n; i++)
        answer[i] = prefix[i] * suffix[i];

    return answer;
}
```

---

## Approach 2: O(1) Extra Space (Output Array Only) — O(n) time, O(1) space*

*\*Ignoring the output array itself, which is required by the problem.*

Use the output array as the prefix product, then do a right-to-left pass maintaining a running suffix product.

```csharp
public static int[] ProductExceptSelf(int[] nums)
{
    int n = nums.Length;
    int[] answer = new int[n];

    // Pass 1: fill answer[i] with the product of all elements to the LEFT of i
    answer[0] = 1;
    for (int i = 1; i < n; i++)
        answer[i] = answer[i - 1] * nums[i - 1];

    // Pass 2: multiply each answer[i] by the running product of elements to the RIGHT
    int rightProduct = 1;
    for (int i = n - 1; i >= 0; i--)
    {
        answer[i] *= rightProduct;
        rightProduct *= nums[i]; // update for the next (leftward) position
    }

    return answer;
}
```

### Walkthrough for `[1, 2, 3, 4]`

```
After pass 1 (prefix):  [1,  1,  2,  6]
                             ↑   ↑   ↑
                        1   1*1 1*2 2*3

rightProduct trace (pass 2, right→left):
  i=3: answer[3] = 6 * 1  = 6;  rightProduct = 1*4 = 4
  i=2: answer[2] = 2 * 4  = 8;  rightProduct = 4*3 = 12
  i=1: answer[1] = 1 * 12 = 12; rightProduct = 12*2 = 24
  i=0: answer[0] = 1 * 24 = 24; rightProduct = 24*1 = 24

Result: [24, 12, 8, 6] ✓
```

---

## Handling Zeros

If `nums` contains zeros, the "division" shortcut (`totalProduct / nums[i]`) would require special-casing zeros anyway. The prefix/suffix approach handles zeros naturally without any special cases.

---

## Complexity Summary

| Approach              | Time | Extra Space   |
|-----------------------|------|---------------|
| Prefix + Suffix arrays| O(n) | O(n)          |
| Single output array   | O(n) | O(1)          |

---

## Interview Tips

- **The "no division" constraint is the whole point** — immediately acknowledge it and explain why it rules out `totalProduct / nums[i]`.
- Mention the zero-handling advantage of the prefix/suffix approach.
- Walk through the two-pass approach on a small example to show you understand it.
- **Edge case:** Array with zeros — `[0, 1, 2]` → `[2, 0, 0]`. Multiple zeros → all outputs are `0`.
- **Follow-up:** *"What if overflow is a concern?"* → Use `long` or check for overflow using `checked {}`.
