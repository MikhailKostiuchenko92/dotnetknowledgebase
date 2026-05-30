# NP-Complete Problems Recognisable in Interviews

**Category:** Algorithms / Complexity Theory
**Difficulty:** Senior
**Tags:** `NP-complete`, `TSP`, `subset-sum`, `vertex-cover`, `complexity`

## Question
> What NP-complete problems might come up in a technical interview, and how do you handle them?

## Short Answer
The most common NP-complete problems in interviews are Subset Sum, Knapsack (exact variant), TSP (Travelling Salesman), Graph Colouring, and Vertex Cover. The interviewer typically wants you to: (1) recognise the problem is NP-complete, (2) solve a relaxed/approximate/small-n version, or (3) explain why an exact poly-time algorithm is unlikely.

## Detailed Explanation

### Most Recognisable NP-Complete Problems

#### 1. Subset Sum / 0-1 Knapsack
> "Can a subset of these numbers sum to T?"

**Pseudo-polynomial DP:** O(n·T). The "polynomial" is in T, not log T — still NP-hard for large T.

```csharp
bool SubsetSum(int[] nums, int target)
{
    var dp = new bool[target + 1];
    dp[0] = true;
    foreach (int n in nums)
        for (int t = target; t >= n; t--)
            dp[t] |= dp[t - n];
    return dp[target];
}
```

#### 2. Travelling Salesman Problem (TSP)
> "Find the shortest route visiting all cities exactly once."

- Exact: O(2ⁿ · n) with bitmask DP (Held-Karp).
- Approximation: Greedy nearest-neighbor or Christofides (1.5× optimal for metric TSP).

#### 3. Graph Colouring (k-coloring)
> "Can this graph be coloured with k colours such that no adjacent nodes share a colour?"

- k=2 (bipartite check): **polynomial** — BFS/DFS.
- k≥3: **NP-complete**.

```csharp
// Bipartite check (2-coloring) — polynomial
bool IsBipartite(int[][] graph)
{
    int n = graph.Length;
    var color = new int[n]; // 0=unset, 1=red, -1=blue
    for (int i = 0; i < n; i++)
    {
        if (color[i] != 0) continue;
        var queue = new Queue<int>();
        queue.Enqueue(i); color[i] = 1;
        while (queue.Count > 0)
        {
            int u = queue.Dequeue();
            foreach (int v in graph[u])
            {
                if (color[v] == 0) { color[v] = -color[u]; queue.Enqueue(v); }
                else if (color[v] == color[u]) return false;
            }
        }
    }
    return true;
}
```

#### 4. Vertex Cover
> "Find the minimum set of vertices such that every edge has at least one endpoint in the set."

- **2-approximation:** greedily pick both endpoints of any uncovered edge → ≤ 2× optimal.

#### 5. SAT / 3-SAT
Rarely asked directly, but constraint satisfaction problems in disguise appear in Sudoku solving and logic puzzles.

### How to Handle NP-Complete Problems in Interviews

1. **Recognise** — "This looks like Subset Sum / TSP, which is NP-complete."
2. **Clarify constraints** — is n small enough for exact backtracking? Is T small for DP?
3. **Offer approaches** — pseudo-polynomial DP, greedy approximation, heuristic.
4. **Implement the tractable version** — exact DP for small n, greedy for large n.

## Common Follow-up Questions
- How does Held-Karp bitmask DP solve TSP in O(2ⁿ · n)?
- What is the 2-approximation algorithm for Vertex Cover?
- When is a graph k-colorable in polynomial time?
- What is the practical difference between NP-complete and NP-hard?
- What tools (SAT solvers, ILP) can handle NP-complete problems in production?

## Common Mistakes / Pitfalls
- Attempting to invent a polynomial algorithm for an NP-complete problem — know when to stop.
- Confusing "hard in general" with "hard for specific inputs" — TSP on planar graphs has approximation schemes.
- Not mentioning that pseudo-polynomial DP (Subset Sum) is still NP-hard in general.

## References
- [Karp's 21 NP-Complete Problems — Wikipedia](https://en.wikipedia.org/wiki/Karp%27s_21_NP-complete_problems)
- [Introduction to Algorithms — Chapter 34](https://mitpress.mit.edu/books/introduction-algorithms)
