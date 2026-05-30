# Add Two Numbers

**Source:** LeetCode #2
**Difficulty:** 🟡 Medium
**Topics:** Linked List, Math, Carry

## Problem Statement

You are given two **non-empty** linked lists representing two non-negative integers. The digits are stored in **reverse order**, and each of their nodes contains a single digit. Add the two numbers and return the sum as a linked list (also in reverse order).

## Examples

```
Input:  l1 = 2→4→3, l2 = 5→6→4
Output: 7→0→8
Explanation: 342 + 465 = 807

Input:  l1 = 0, l2 = 0
Output: 0

Input:  l1 = 9→9→9→9→9→9→9, l2 = 9→9→9→9
Output: 8→9→9→9→0→0→0→1
Explanation: 9999999 + 9999 = 10009998
```

## Constraints

- Number of nodes in each list: `[1, 100]`
- `0 <= Node.val <= 9`
- No leading zeros except for the number 0 itself.

---

## Approach: Elementary Addition with Carry — O(max(m,n)) time, O(max(m,n)+1) space ✓

Simulate digit-by-digit addition from least significant to most significant (which is front-to-back due to reversed storage). Track a `carry`.

```csharp
public static ListNode? AddTwoNumbers(ListNode? l1, ListNode? l2)
{
    var dummy = new ListNode(0);
    var curr = dummy;
    int carry = 0;

    while (l1 != null || l2 != null || carry != 0)
    {
        int sum = carry;
        if (l1 != null) { sum += l1.val; l1 = l1.next; }
        if (l2 != null) { sum += l2.val; l2 = l2.next; }

        carry = sum / 10;
        curr.next = new ListNode(sum % 10);
        curr = curr.next;
    }

    return dummy.next;
}
```

### Loop condition: `l1 != null || l2 != null || carry != 0`

The third condition `carry != 0` ensures we create an extra node for an overflow carry. Example: `9→9 + 1` = `0→0→1` — the leading `1` comes from the final carry.

### Walkthrough: `2→4→3` + `5→6→4`

```
Digit 0: 2+5=7,  carry=0 → node(7)
Digit 1: 4+6=10, carry=1 → node(0)
Digit 2: 3+4+1=8,carry=0 → node(8)
Result: 7→0→8 ✓
```

---

## Variant: Numbers stored in forward order (LeetCode #445)

If digits are in normal (most-significant-first) order:
1. Use two stacks to reverse the traversal, OR
2. Reverse both lists, add, reverse result.

```csharp
public static ListNode? AddTwoNumbersForward(ListNode? l1, ListNode? l2)
{
    var s1 = new Stack<int>();
    var s2 = new Stack<int>();
    for (var n = l1; n != null; n = n.next) s1.Push(n.val);
    for (var n = l2; n != null; n = n.next) s2.Push(n.val);

    ListNode? head = null;
    int carry = 0;
    while (s1.Count > 0 || s2.Count > 0 || carry > 0)
    {
        int sum = carry;
        if (s1.Count > 0) sum += s1.Pop();
        if (s2.Count > 0) sum += s2.Pop();
        carry = sum / 10;
        head = new ListNode(sum % 10, head); // prepend
    }
    return head;
}
```

---

## Complexity Summary

| | Time | Space |
|---|---|---|
| Reversed (LeetCode #2) | O(max(m,n)) | O(max(m,n)+1) |
| Forward (LeetCode #445) | O(m+n) | O(m+n) (stacks) |

---

## Interview Tips

- **Carry is the tricky part** — make sure the loop continues while `carry != 0`.
- Dummy head simplifies the result list construction.
- **Edge cases:** One list much longer than the other, both single digits, carry at the very end (e.g., `5 + 5 = 10` → `0→1`).
- **Follow-up:** *"What if numbers are stored in forward order?"* → LeetCode #445 — use stacks for O(n) space, or reverse the lists.
