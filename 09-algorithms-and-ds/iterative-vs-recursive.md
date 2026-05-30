# Iterative vs Recursive Implementations

**Category:** Algorithms / Design
**Difficulty:** Junior
**Tags:** `recursion`, `iteration`, `stack`, `tail-recursion`

## Question
> When would you prefer an iterative solution over a recursive one, and vice versa? What are the trade-offs?

## Short Answer
Recursion is often more readable and maps directly to the problem structure (trees, divide-and-conquer). Iteration is more memory-efficient (no call stack frames) and avoids stack overflow. In .NET, recursive calls consume thread stack space (default 1 MB per thread), so deep recursion (>~10k levels) can crash.

## Detailed Explanation

### How Recursion Works Internally

Each function call allocates a **stack frame** on the thread's call stack, storing local variables, return address, and parameters. Deep recursion can exhaust the limited stack space.

```
n = 100,000 recursive calls × ~100 bytes/frame ≈ 10 MB
Default .NET thread stack: 1 MB → StackOverflowException
```

### Tail Recursion

A recursive call is **tail-recursive** when it's the **last** operation in the function. The compiler/JIT can optimise it to a loop (tail-call optimisation, TCO). However, **C# / .NET JIT does not always perform TCO** reliably — don't rely on it.

```csharp
// Tail-recursive (last op is the recursive call)
static int Sum(int n, int acc = 0)
    => n == 0 ? acc : Sum(n - 1, acc + n);

// .NET JIT may NOT optimise this — convert manually if depth matters
static int SumIterative(int n)
{
    int acc = 0;
    for (; n > 0; n--) acc += n;
    return acc;
}
```

### When to Use Recursion

✅ Tree/graph traversal (DFS)  
✅ Divide-and-conquer (merge sort, quick sort)  
✅ Backtracking (depth bounded by problem size)  
✅ When the recursive structure matches the data structure  

### When to Use Iteration

✅ Linear traversal (arrays, lists)  
✅ Deep recursion that may overflow  
✅ Performance-critical code (no call stack overhead)  
✅ In production .NET code where stack depth is unknown  

### Conversion Pattern: Recursion → Iteration with Explicit Stack

```csharp
// Recursive DFS
void DfsRecursive(TreeNode? node)
{
    if (node is null) return;
    Console.WriteLine(node.val);
    DfsRecursive(node.left);
    DfsRecursive(node.right);
}

// Iterative DFS (explicit stack)
void DfsIterative(TreeNode? root)
{
    if (root is null) return;
    var stack = new Stack<TreeNode>();
    stack.Push(root);

    while (stack.Count > 0)
    {
        var node = stack.Pop();
        Console.WriteLine(node.val);
        if (node.right is not null) stack.Push(node.right);
        if (node.left  is not null) stack.Push(node.left);
    }
}
```

### Memory Comparison

| Factor | Recursive | Iterative |
|--------|-----------|-----------|
| Code readability | Often higher | Can be verbose |
| Stack usage | O(depth) call frames | O(1) or O(depth) explicit stack |
| Stack overflow risk | Yes, for deep input | No |
| TCO availability | Limited in .NET | N/A |
| Memoisation ease | Natural with top-down DP | Needs explicit table |

## Code Example

```csharp
// Fibonacci — three approaches
// 1. Naive recursion — O(2^n) time, O(n) stack space
int FibRec(int n) => n <= 1 ? n : FibRec(n-1) + FibRec(n-2);

// 2. Top-down memoisation — O(n) time, O(n) space
int FibMemo(int n, Dictionary<int,int>? cache = null)
{
    cache ??= new();
    if (n <= 1) return n;
    if (cache.TryGetValue(n, out int v)) return v;
    return cache[n] = FibMemo(n-1, cache) + FibMemo(n-2, cache);
}

// 3. Bottom-up DP — O(n) time, O(1) space (best)
int FibDP(int n)
{
    if (n <= 1) return n;
    int prev2 = 0, prev1 = 1;
    for (int i = 2; i <= n; i++) (prev2, prev1) = (prev1, prev2 + prev1);
    return prev1;
}
```

## Common Follow-up Questions
- How does the .NET call stack differ between async methods and regular recursive calls?
- What is trampolining? How does it simulate TCO?
- Can you convert any recursive algorithm to iterative? What data structure is always sufficient?
- How does memoisation differ from tabulation (bottom-up DP)?
- What is the maximum recursion depth in .NET?

## Common Mistakes / Pitfalls
- Assuming .NET performs tail-call optimisation — it doesn't consistently.
- Using recursion for `n > 10,000` levels without a guard → `StackOverflowException`.
- Forgetting the base case → infinite recursion.
- Memoising mutable state incorrectly in recursive solutions.
- Not considering that iterative code can also be O(n) space if using an explicit stack.

## References
- [Recursion vs Iteration — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/linq/recursion-and-iteration) (verify URL)
- [Tail recursion in .NET — Jon Skeet's blog](https://jonskeet.uk) (verify URL — search "tail recursion")
- [Stephen Toub — Async/Await and Recursion](https://devblogs.microsoft.com/dotnet/)
