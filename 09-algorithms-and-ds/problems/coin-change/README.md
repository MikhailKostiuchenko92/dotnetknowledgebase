# Coin Change

**Source:** LeetCode #322
**Difficulty:** 🟡 Medium
**Topics:** Array, Dynamic Programming, BFS

## Problem Statement

Given an array of coin denominations `coins` and a total amount `amount`, return the **fewest number of coins** needed to make up that amount. If impossible, return `-1`.

## Examples

```
Input: coins = [1,5,10,25], amount = 36   Output: 3   // 25+10+1
Input: coins = [2], amount = 3   Output: -1
Input: coins = [1], amount = 0   Output: 0
```

## Constraints

- `1 <= coins.Length <= 12`; `1 <= coins[i] <= 2³¹ - 1`; `0 <= amount <= 10⁴`

---

## Approach: Bottom-Up DP — O(amount × coins) time, O(amount) space ✓

`dp[i]` = fewest coins to make amount `i`. Initialize with `amount + 1` (effectively infinity).

```csharp
public static int CoinChange(int[] coins, int amount)
{
    var dp = new int[amount + 1];
    Array.Fill(dp, amount + 1); // "infinity"
    dp[0] = 0;

    for (int i = 1; i <= amount; i++)
        foreach (int coin in coins)
            if (coin <= i)
                dp[i] = Math.Min(dp[i], dp[i - coin] + 1);

    return dp[amount] > amount ? -1 : dp[amount];
}
```

### Walkthrough: `coins=[1,2,5]`, `amount=11`

```
dp[5]  = min(dp[4]+1, dp[3]+1, dp[0]+1) = 1          // 5
dp[11] = min(dp[10]+1, dp[9]+1, dp[6]+1) = 3          // 5+5+1
```

---

## Approach 2: BFS (Level = coin count) — O(amount × coins)

BFS from 0; each level adds 1 coin. First time we reach `amount` = fewest coins.

---

## Complexity Summary

| Approach  | Time                  | Space     |
|-----------|-----------------------|-----------|
| DP        | O(amount × |coins|)   | O(amount) |
| BFS       | O(amount × |coins|)   | O(amount) |

---

## Interview Tips

- Using `amount + 1` as infinity avoids `int.MaxValue + 1` overflow.
- **Unbounded knapsack pattern** — each coin can be used any number of times.
- **Follow-up:** *"How many combinations?"* → LeetCode #518 "Coin Change II" — swap loop order (outer = coins, inner = amount).
