# Space-Time Trade-Off Patterns

**Category:** Algorithms / Optimisation
**Difficulty:** Senior
**Tags:** `memoisation`, `tabulation`, `rolling-array`, `space-time-trade-off`

## Question
> What are common space-time trade-off patterns in algorithms? Explain memoisation, tabulation, and rolling arrays with examples.

## Short Answer
Space-time trade-offs exchange memory for speed (or vice versa). The three main DP patterns are: **memoisation** (top-down cache), **tabulation** (bottom-up DP table), and **rolling arrays** (reduce space by keeping only recent rows). The right choice depends on whether all sub-problems are needed, the recursion depth limit, and memory constraints.

## Detailed Explanation

### 1. Memoisation (Top-Down DP)

Cache recursive subproblem results. Only computes subproblems that are actually needed (lazy).

```csharp
// Fibonacci with memoisation — O(n) time, O(n) space
int FibMemo(int n, int[] memo)
{
    if (n <= 1) return n;
    if (memo[n] != 0) return memo[n];
    return memo[n] = FibMemo(n - 1, memo) + FibMemo(n - 2, memo);
}
```

**Pros:** Natural recursion, only computes needed subproblems.  
**Cons:** Recursion stack overhead, possible stack overflow for large n.

---

### 2. Tabulation (Bottom-Up DP)

Fill a table from smallest subproblems to largest. Avoids recursion entirely.

```csharp
// Fibonacci with tabulation — O(n) time, O(n) space
int FibTab(int n)
{
    if (n <= 1) return n;
    var dp = new int[n + 1];
    dp[1] = 1;
    for (int i = 2; i <= n; i++) dp[i] = dp[i-1] + dp[i-2];
    return dp[n];
}
```

**Pros:** No recursion, predictable memory, easy to optimise with rolling array.  
**Cons:** May compute unused subproblems.

---

### 3. Rolling Array (Space Optimisation)

When a DP recurrence only depends on the last k rows/values, keep only those.

```csharp
// Fibonacci — O(n) time, O(1) space
int FibRolling(int n)
{
    if (n <= 1) return n;
    int prev2 = 0, prev1 = 1;
    for (int i = 2; i <= n; i++) (prev2, prev1) = (prev1, prev1 + prev2);
    return prev1;
}

// 2-D DP → 1-D rolling (LCS)
int LCS(string a, string b)
{
    int m = a.Length, n = b.Length;
    var prev = new int[n + 1];
    for (int i = 1; i <= m; i++)
    {
        var curr = new int[n + 1];
        for (int j = 1; j <= n; j++)
            curr[j] = a[i-1] == b[j-1] ? prev[j-1] + 1 : Math.Max(prev[j], curr[j-1]);
        prev = curr;
    }
    return prev[n];
}
```

---

### Other Space-Time Trade-Off Patterns

| Pattern | Extra Space | Speedup |
|---------|------------|---------|
| Precomputed prefix sums | O(n) | O(1) range sum queries |
| Inverted index | O(n × k) | O(1) search vs O(n) scan |
| Bloom filter | O(m bits) | O(1) membership (probabilistic) |
| Precomputed hash | O(n) | O(1) equality checks |
| Bit manipulation instead of Set | O(1) vs O(n) | O(1) but limited range |

## Code Example

```csharp
// Prefix sum — classic space-time trade-off
// Precompute: O(n) time and space
// Query: O(1) instead of O(n) per range sum
int[] BuildPrefixSum(int[] nums)
{
    var prefix = new int[nums.Length + 1];
    for (int i = 0; i < nums.Length; i++)
        prefix[i + 1] = prefix[i] + nums[i];
    return prefix;
}
int RangeSum(int[] prefix, int left, int right)
    => prefix[right + 1] - prefix[left]; // O(1)
```

## Common Follow-up Questions
- When would you use memoisation over tabulation?
- Can every tabulation solution be converted to memoisation? Vice versa?
- What is a "space-efficient" suffix array? What trade-off does it make?
- What are the trade-offs of precomputing results at startup vs computing on demand?
- How does a Bloom filter trade space for time (and introduce false positives)?

## Common Mistakes / Pitfalls
- Using memoisation with `Dictionary<string, T>` for large inputs — dictionary overhead is significant.
- Forgetting to initialise the memo correctly (0 vs -1 for "not computed").
- Applying rolling array optimisation when the recurrence uses more than 2 previous rows.
- Prematurely optimising to O(1) space before confirming correctness with O(n) tabulation.

## References
- [Dynamic Programming — Microsoft Learn / C# patterns](https://learn.microsoft.com/en-us/dotnet/csharp/) (verify URL)
- [Introduction to Algorithms — Chapter 15 (DP)](https://mitpress.mit.edu/books/introduction-algorithms)
