# Best Time to Buy and Sell Stock

**Source:** LeetCode #121
**Difficulty:** 🟡 Medium
**Topics:** Array, Sliding Window, Greedy

## Problem Statement

You are given an array `prices` where `prices[i]` is the price of a given stock on the `i`-th day.

You want to maximise your profit by choosing a **single day to buy** and a **different day in the future to sell**.

Return the **maximum profit** you can achieve. If no profit is possible, return `0`.

## Examples

```
Input:  prices = [7, 1, 5, 3, 6, 4]
Output: 5   // Buy at 1 (day 1), sell at 6 (day 4)

Input:  prices = [7, 6, 4, 3, 1]
Output: 0   // Prices only decrease; no profit possible
```

## Constraints

- `1 <= prices.Length <= 10⁵`
- `0 <= prices[i] <= 10⁴`

---

## Approach 1: Brute Force — O(n²) time, O(1) space

Try every pair `(buy, sell)` where `buy < sell`.

```csharp
public static int MaxProfitBrute(int[] prices)
{
    int maxProfit = 0;
    for (int i = 0; i < prices.Length; i++)
        for (int j = i + 1; j < prices.Length; j++)
            maxProfit = Math.Max(maxProfit, prices[j] - prices[i]);
    return maxProfit;
}
```

---

## Approach 2: Single Pass (Track Minimum) — O(n) time, O(1) space

Track the **lowest price seen so far** as the buy candidate. At each day compute the profit if you sell today.

```csharp
public static int MaxProfit(int[] prices)
{
    int minPrice = int.MaxValue;
    int maxProfit = 0;

    foreach (int price in prices)
    {
        if (price < minPrice)
            minPrice = price;            // found a better buy day
        else if (price - minPrice > maxProfit)
            maxProfit = price - minPrice; // found a better sell day
    }

    return maxProfit;
}
```

### Why this works

At every index `i`, the best profit achievable by selling on day `i` is `prices[i] - minPriceSoFar`. We never need to look backward further than the minimum encountered so far. This is a **greedy** observation — always buy at the global minimum before the current day.

> **Pitfall:** Using `int.MaxValue` as the initial `minPrice` is safe here since `prices[i] >= 0`. But be careful in problems where prices can be negative.

---

## Complexity Summary

| Approach      | Time   | Space |
|---------------|--------|-------|
| Brute Force   | O(n²)  | O(1)  |
| Single Pass   | O(n)   | O(1)  |

---

## Interview Tips

- **Clarify:** One transaction only (this problem) vs. unlimited transactions ([Best Time to Buy and Sell Stock II](../best-time-to-buy-and-sell-stock-ii/README.md)).
- State the invariant aloud: *"I'll track the minimum price seen so far and update max profit at each step."*
- **Edge cases:** single-element array (profit = 0), strictly decreasing (profit = 0).
- **Follow-up:** *"What if you can make at most 2 transactions?"* → LeetCode #123, DP with states.
- **Follow-up:** *"What if there's a transaction fee?"* → LeetCode #714, DP.
- **Follow-up:** *"What if you have to wait one day after selling before buying again (cooldown)?"* → LeetCode #309, DP.
