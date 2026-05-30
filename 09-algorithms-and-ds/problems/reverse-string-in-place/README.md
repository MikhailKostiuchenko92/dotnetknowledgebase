# Reverse a String In-Place Using `Span<char>`

**Source:** Custom / Real interview
**Difficulty:** 🟢 Easy
**Topics:** Strings, Span\<T\>, Two-Pointer

## Problem Statement

Reverse a string (or character array) in-place using modern C# idioms. Demonstrate knowledge of `Span<char>` and why it is preferable to heap-allocated alternatives.

## Examples

```
Input:  "hello"
Output: "olleh"

Input:  "A man a plan a canal Panama"
Output: "amanaP lanac a nalp a nam A"

Input:  ""
Output: ""
```

## Constraints

- Input length `0 <= s.Length <= 10⁵`.
- Characters can be any Unicode code unit (ASCII letters for simplicity).

---

## Approach 1: Manual Two-Pointer on `char[]` — O(n) time, O(n) space (allocation)

Allocate a `char[]`, swap with two pointers, then convert back to string.

```csharp
public static string ReverseV1(string s)
{
    char[] chars = s.ToCharArray(); // heap allocation
    int lo = 0, hi = chars.Length - 1;
    while (lo < hi)
    {
        (chars[lo], chars[hi]) = (chars[hi], chars[lo]);
        lo++;
        hi--;
    }
    return new string(chars);
}
```

---

## Approach 2: `Span<char>` + `MemoryExtensions.Reverse()` — O(n) time, O(n) space*

`string` is immutable in .NET, so we must allocate a writable buffer. `Span<char>` allows in-place mutation without a second allocation beyond the initial copy.

```csharp
using System;

public static string ReverseSpan(string s)
{
    if (s.Length <= 1) return s;

    // Allocate writable buffer on the stack for small strings
    // or fall back to heap via new char[s.Length]
    Span<char> buffer = s.Length <= 256
        ? stackalloc char[s.Length]
        : new char[s.Length];

    s.AsSpan().CopyTo(buffer);
    buffer.Reverse(); // System.MemoryExtensions.Reverse — in-place, no LINQ
    return new string(buffer);
}
```

> **Why `Span<T>`?** It avoids creating a `string` intermediate via `ToCharArray()` and allows `stackalloc` for small inputs, keeping the operation stack-resident and GC-pressure-free.

### When is `stackalloc` safe?

`stackalloc` is safe here because the `Span<char>` does not escape the method. The C# compiler enforces this — you cannot store a `stackalloc` span in a field or return it.

---

## Approach 3: Reverse in-place on a mutable buffer (char array passed in) — O(n) time, O(1) extra space

If the interviewer asks for true in-place (no extra allocation), work with `char[]` directly:

```csharp
public static void ReverseInPlace(char[] s)
{
    int lo = 0, hi = s.Length - 1;
    while (lo < hi)
    {
        (s[lo], s[hi]) = (s[hi], s[lo]);
        lo++;
        hi--;
    }
}
```

This mirrors LeetCode #344 "Reverse String" which takes a `char[]`.

---

## Complexity Summary

| Approach                  | Time | Extra Space        |
|---------------------------|------|--------------------|
| `char[]` two-pointer      | O(n) | O(n) (char array)  |
| `Span<char>` + Reverse()  | O(n) | O(n) heap / O(n) stack |
| In-place on `char[]`      | O(n) | O(1)               |

---

## Interview Tips

- **Clarify:** Is the input a `string` (immutable) or a `char[]`? This changes the answer significantly.
- Mention that `string` is immutable in .NET — reversing truly in-place requires `char[]` or `Memory<char>`.
- Highlight `Span<T>` for modern C# interviews; it shows awareness of zero-allocation patterns.
- Edge cases to mention: empty string, single character, palindrome (result equals input), surrogate pairs (Unicode) — if the string contains emoji/surrogate pairs, reversing individual `char` values breaks them.
- `MemoryExtensions.Reverse(Span<char>)` is available since .NET Core 2.1 / .NET Standard 2.1.
