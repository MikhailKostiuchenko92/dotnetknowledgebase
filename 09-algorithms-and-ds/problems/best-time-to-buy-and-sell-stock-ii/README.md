# Best Time to Buy and Sell Stock II

**Source:** LeetCode #122
**Difficulty:** 🟡 Medium
**Topics:** Array, Greedy

## Problem Statement

You are given an integer array `prices` where `prices[i]` is the price of a stock on day `i`.

On each day you may decide to buy and/or sell the stock. You can only hold **at most one share** at a time. However, you can buy and immediately sell on the **same day**.

Return the **maximum profit** you can achieve with **unlimited transactions**.

## Examples

```
Input:  prices = [7, 1, 5, 3, 6, 4]
Output: 7   // Buy at 1, sell at 5 (+4). Buy at 3, sell at 6 (+3).

Input:  prices = [1, 2, 3, 4, 5]
Output: 4   // Buy at 1, sell at 5 (or accumulate daily diffs)

Input:  prices = [7, 6, 4, 3, 1]
Output: 0   // Prices only decrease
```

## Constraints

- `1 <= prices.Length <= 3 × 10⁴`
- `0 <= prices[i] <= 10⁴`

---

## Approach 1: Greedy — Capture Every Upslope — O(n) time, O(1) space

### Key Insight

The maximum profit equals the **sum of all positive day-to-day differences**. If `prices[i+1] > prices[i]`, you would always want to buy on day `i` and sell on day `i+1`. Buying at the valley and selling at the peak is mathematically equivalent to summing every positive slope segment.

```
prices: 1  2  3  4  5
diffs:   +1 +1 +1 +1   → total = 4  (same as buy at 1, sell at 5)
```

```csharp
public static int MaxProfit(int[] prices)
{
    int profit = 0;

    for (int i = 1; i < prices.Length; i++)
    {
        // Capture every upward move, ignore downward moves
        if (prices[i] > prices[i - 1])
            profit += prices[i] - prices[i - 1];
    }

    return profit;
}
```

---

## Approach 2: Peak-Valley — O(n) time, O(1) space

Explicitly find valleys (buy) and peaks (sell). Same result, more code.

```csharp
public static int MaxProfitPeakValley(int[] prices)
{
    int profit = 0;
    int i = 0;

    while (i < prices.Length - 1)
    {
        // Find valley
        while (i < prices.Length - 1 && prices[i] >= prices[i + 1]) i++;
        int buy = prices[i];

        // Find peak
        while (i < prices.Length - 1 && prices[i] <= prices[i + 1]) i++;
        int sell = prices[i];

        profit += sell - buy;
    }

    return profit;
}
```

Both approaches yield the same result; the greedy version is simpler.

---

## Complexity Summary

| Approach     | Time | Space |
|--------------|------|-------|
| Greedy diffs | O(n) | O(1)  |
| Peak-Valley  | O(n) | O(1)  |

---

## Interview Tips

- **Distinguish from LeetCode #121:** Here you have unlimited transactions; [single-transaction version](../best-time-to-buy-and-sell-stock/README.md) has at most one.
- State the greedy argument: *"Any rising segment contributes positively to profit, so I capture every positive difference."*
- **Edge case:** Array length 1 → no transaction possible → return 0.
- **Follow-up:** *"What if there's a transaction fee per trade?"* → LeetCode #714. The greedy still works but only capture diffs that exceed the fee.
- **Follow-up:** *"What if you can hold at most 2 shares simultaneously?"* → Requires DP.
- Mention that "buying and selling on the same day" nets zero profit so it's safely ignorable.
